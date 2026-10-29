# Mini ERP – Architecture & Technical Design[cite: 8]

[⬅ Back to README.md](../README.md) | [English](Architecture.md) | [Deutsch](Architecture.de.md) | [Українська](Architecture.ua.md)[cite: 8]

## 1. Domain Data Model[cite: 8]

The domain architecture consists of 6 Master Data Business Objects and 4 Transactional Document types[cite: 8].

### Master Data Entities[cite: 8]
- **Company Code (`ZMERP_COMP_CODE`):** Represents an enterprise legal entity responsible for business transactions. Defines company name, country, and default currency[cite: 8].
- **Warehouse (`ZMERP_WAREHOUSE`):** Represents a physical storage location. Each warehouse belongs to exactly one Company Code[cite: 8].
- **Business Partner (`ZMERP_BUS_PART`):** Represents external counterparties. Supports Customer, Supplier, or combined roles. Shared across all Company Codes[cite: 8].
- **Item Group (`ZMERP_ITEM_GROUP`):** Classifies Items and contains default VAT assignment for automatic determination[cite: 8].
- **Item Master (`ZMERP_ITEM`):** Supports physical Products (triggering stock movements) and intangible Services (commercial calculation only)[cite: 8].
- **VAT Rate (`ZMERP_VAT_RATE`):** Defines tax percentages referenced by Item Groups, Items, and transaction document lines[cite: 8].

---

## 2. Key Generation and Formatting Strategy[cite: 8]

The system uses standardized prefixes, fixed-length formatting, and dedicated Number Range Objects across all entities[cite: 8]:

| Entity | Semantic Prefix | Pattern Example | Key Generation Strategy |
|---|---|---|---|
| **Company Code** | *None* | `1000` | Manual Input[cite: 8] |
| **Warehouse** | `WH` | `WH00001` | Early Numbering / Hybrid NRO + DB Max[cite: 8] |
| **Business Partner** | *None* | `00001` | Early Numbering / Hybrid NRO + DB Max[cite: 8] |
| **Item Group** | *None* | `00001` | Early Numbering / Hybrid NRO + DB Max[cite: 8] |
| **Item Master** | *None* | `00001` | Early Numbering / Hybrid NRO + DB Max[cite: 8] |
| **VAT Rate** | `V` | `V0001` | Early Numbering / Hybrid NRO + DB Max[cite: 8] |
| **Purchase Order** | *Company Prefix* | `1000000001` | Early/On-Save Numbering / Company-Scoped NRO |

### Key Generation Logic Flow[cite: 8]
1. User creates a new entity (triggers RAP Early Numbering)[cite: 8].
2. Utility attempts to fetch next number from SAP NRO (`cl_numberrange_runtime`)[cite: 8].
3. If NRO is unconfigured or fails, fallback logic queries the database for `MAX(code)` across both Active and Draft tables[cite: 8].
4. Number is incremented and formatted with leading zeros and pre-defined semantic prefix[cite: 8].

---

## 3. Master Data Governance & Integrity Patterns[cite: 8]

To enforce data consistency, prevent orphan records, and govern record lifecycle under ABAP Cloud, the Master Data domain employs two standardized design patterns across all Business Objects[cite: 8]:

### 3.1. Relational Integrity via Bulk Prechecks (`precheck_delete`)[cite: 8]
Before any Master Data entity is deleted, RAP triggers the `precheck_delete` operation in the respective Behavior Implementation class (e.g., `ZBP_MERP_R_COMPANY_CODE`)[cite: 8]. 

To avoid performance bottlenecks during multi-record deletions, the check uses a bulk query pattern[cite: 8]:
- **Key Deduplication:** Target keys from the RAP `keys` table are collected and deduplicated (`DELETE ADJACENT DUPLICATES`)[cite: 8].
- **Bulk SQL Dependency Scan:** A single `SELECT DISTINCT` query is executed against a dedicated CDS Usage View (e.g., `ZMERP_I_COMPANY_CODE_USAGE`) using an internal table JOIN (`INNER JOIN @lt_keys`)[cite: 8].
- **In-Memory Matching:** Identified dependencies are mapped back to individual records in memory via binary search (`LOOP AT ... WHERE`)[cite: 8].
- **RAP Fail & Message Reporting:** If dependencies exist, the record is flagged with `%fail-cause = if_abap_behv=>cause-dependency`, and a user-friendly error message (`ZCM_MERP_MESSAGES`) is returned to the UI, preventing the deletion[cite: 8].

### 3.2. Soft Blocking and Value Help Governance[cite: 8]
To deactivate Master Data entities without breaking historical transactional records, all 6 entities implement an `IsBlocked` (`ZMERP_IS_BLOCKED`) field[cite: 8]:
- **Data Preservation:** Blocked entities remain in the database for auditability and reporting[cite: 8].
- **Selection Prevention:** All dedicated Value Help CDS View Entities (e.g., `ZMERP_I_COMPANY_CODE_VH`, `ZMERP_I_VAT_RATE_VH`) enforce an explicit condition `WHERE IsBlocked = ''`[cite: 8]. This ensures blocked Master Data records cannot be selected in new transactional documents (PO, SO, Inventory Movements)[cite: 8].

---

## 4. Transactional Document Architecture (Phase 2)[cite: 8]

Transactional documents follow a Header (1) to Line Items (N) composition structure[cite: 8]:
- **Procurement Chain:** Purchase Order (`ZMERP_R_PURCHASEORDER`) -> Goods Receipt[cite: 8]
- **Sales Chain:** Sales Order -> Goods Issue[cite: 8]

### 4.1. Purchase Order Functional Architecture

#### Company-Scoped Sequential Numbering
- **Context-Aware NRO Allocation:** Document numbers (`DocumentNumber`) are generated on save using Number Range Objects scoped to the specific `CompanyCode`, incorporating the company prefix for unique enterprise identification.

#### Document Calculation Engine (`ZCL_MERP_DOC_CALC`)
- **Item-Level Calculations:** Modifying `Quantity`, `Price`, or `VatCode` triggers automated recalculations of item financial amounts (`NetAmount`, `VatAmount`, `GrossAmount`) based on active tax percentages.
- **Header Totals Aggregation:** Item-level changes immediately roll up to recalculate document-level totals (`TotalNetAmount`, `TotalGrossAmount`) across active and draft transactional instances.

#### Validation & Message Handling
- **Real-Time UI Error Clearing:** State-area-based handlers clear individual field validation messages immediately upon correction.
- **Duplicate Line Item Validation:** In-memory context evaluation prevents duplicate `ItemCode` entries across separate lines within the same document.
- **Cross-Entity & Date Rules:** Enforces organizational consistency (warehouse alignment with company code, supplier role checks) and chronological date rules.

### 4.2. Document Status Lifecycle[cite: 8]
- **New (`N`):** Editable draft or newly saved document[cite: 8].
- **Approved (`A`):** Released document via `releaseDocument` action (requires at least 1 line item)[cite: 8].
- **In Delivery (`P`) / Completed (`C`):** Logistics execution lifecycle states[cite: 8].
- **Cancelled (`X`):** Terminated document via `cancelDocument` action; excluded from downstream calculations[cite: 8].

---

## 5. Dynamic Inventory Calculation Concept[cite: 8]

Inventory balances are not statically stored in persistent tables. Current stock levels are calculated dynamically in real time from posted inventory movement documents[cite: 8]:

`Current Stock = Sum(Posted Goods Receipts) - Sum(Posted Goods Issues)`[cite: 8]

### Rules[cite: 8]:
- Tracked per Company Code + Warehouse + Item[cite: 8].
- Excludes items where Item Type = Service (`S`)[cite: 8].
- Insufficient stock errors are enforced during the transition of Goods Issue documents to Posted status via RAP Validations on Save[cite: 8].