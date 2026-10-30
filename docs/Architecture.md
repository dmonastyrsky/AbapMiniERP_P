# Mini ERP – Architecture & Technical Design

[⬅ Back to README.md](../README.md) | [English](Architecture.md) | [Deutsch](Architecture.de.md) | [Українська](Architecture.ua.md)

## 1. Domain Data Model

The domain architecture is designed to support 6 Master Data Business Objects and 4 Transactional Document types.

### Master Data Entities (Implemented)
- **Company Code (`ZMERP_COMP_CODE`):** Represents an enterprise legal entity responsible for business transactions. Defines company name, country, and default currency.
- **Warehouse (`ZMERP_WAREHOUSE`):** Represents a physical storage location. Each warehouse belongs to exactly one Company Code.
- **Business Partner (`ZMERP_BUS_PART`):** Represents external counterparties. Supports Customer, Supplier, or combined roles. Shared across all Company Codes.
- **Item Group (`ZMERP_ITEM_GROUP`):** Classifies Items and contains default VAT assignment for automatic determination.
- **Item Master (`ZMERP_ITEM`):** Supports physical Products (triggering stock movements) and intangible Services (commercial calculation only).
- **VAT Rate (`ZMERP_VAT_RATE`):** Defines tax percentages referenced by Item Groups, Items, and transaction document lines.

---

## 2. Key Generation and Formatting Strategy

The system uses standardized prefixes, fixed-length formatting, and dedicated Number Range Objects across all entities:

| Entity | Semantic Prefix | Pattern Example | Key Generation Strategy | Status |
|---|---|---|---|---|
| **Company Code** | *None* | `1000` | Manual Input | Implemented |
| **Warehouse** | `WH` | `WH00001` | Early Numbering / Hybrid NRO + DB Max | Implemented |
| **Business Partner** | *None* | `00001` | Early Numbering / Hybrid NRO + DB Max | Implemented |
| **Item Group** | *None* | `00001` | Early Numbering / Hybrid NRO + DB Max | Implemented |
| **Item Master** | *None* | `00001` | Early Numbering / Hybrid NRO + DB Max | Implemented |
| **VAT Rate** | `V` | `V0001` | Early Numbering / Hybrid NRO + DB Max | Implemented |
| **Purchase Order** | *Company Prefix* | `1000000001` | Early/On-Save Numbering / Company-Scoped NRO | Implemented |

---

## 3. Master Data Governance & Integrity Patterns

To enforce data consistency, prevent orphan records, and govern record lifecycle under ABAP Cloud, the Master Data domain employs two standardized design patterns across all Business Objects:

### 3.1. Relational Integrity via Bulk Prechecks (`precheck_delete`)
Before any Master Data entity is deleted, RAP triggers the `precheck_delete` operation in the respective Behavior Implementation class (e.g., `ZBP_MERP_R_COMPANY_CODE`). 

To avoid performance bottlenecks during multi-record deletions, the check uses a bulk query pattern:
- **Key Deduplication:** Target keys from the RAP `keys` table are collected and deduplicated (`DELETE ADJACENT DUPLICATES`).
- **Bulk SQL Dependency Scan:** A single `SELECT DISTINCT` query is executed against a dedicated CDS Usage View (e.g., `ZMERP_I_COMPANY_CODE_USAGE`) using an internal table JOIN (`INNER JOIN @lt_keys`).
- **In-Memory Matching:** Identified dependencies are mapped back to individual records in memory via binary search (`LOOP AT ... WHERE`).
- **RAP Fail & Message Reporting:** If dependencies exist, the record is flagged with `%fail-cause = if_abap_behv=>cause-dependency`, and a user-friendly error message (`ZCM_MERP_MESSAGES`) is returned to the UI, preventing deletion.

### 3.2. Soft Blocking and Value Help Governance
To deactivate Master Data entities without breaking historical transactional records, all 6 entities implement an `IsBlocked` (`ZMERP_IS_BLOCKED`) field:
- **Data Preservation:** Blocked entities remain in the database for auditability and reporting.
- **Selection Prevention:** All dedicated Value Help CDS View Entities enforce an explicit condition `WHERE IsBlocked = ''`. This ensures blocked Master Data records cannot be selected in new transactional documents.

---

## 4. Transactional Document Architecture

The transactional document scope is structured across procurement and sales chains:

### Procurement (Procurement Chain)
- **Purchase Order (`ZMERP_R_PURCHASEORDER`) — Implemented:** Header to Line Items composition structure handling procurement order creation and approval lifecycle.
- **Goods Receipt — Planned:** Future document type for capturing physical receipts against Purchase Orders.

### Sales (Sales Chain)
- **Sales Order — Planned:** Future document type for managing customer sales orders.
- **Goods Issue — Planned:** Future document type for capturing physical outbound stock deliveries.

### 4.1. Purchase Order Functional Architecture (Implemented)

#### Company-Scoped Sequential Numbering
- **Context-Aware NRO Allocation:** Document numbers (`DocumentNumber`) are generated on save using Number Range Objects scoped to the specific `CompanyCode`, incorporating the company prefix for unique enterprise identification.

#### Document Calculation Engine (`ZCL_MERP_DOC_CALC`)
- **Item-Level Calculations:** Modifying `Quantity`, `Price`, or `VatCode` triggers automated recalculations of item line financial amounts (`NetAmount`, `VatAmount`, `GrossAmount`) based on active tax percentages.
- **Header Totals Aggregation:** Item-level changes immediately roll up to recalculate document-level totals (`TotalNetAmount`, `TotalGrossAmount`) across active and draft transactional instances.

#### Validation & Message Handling
- **Real-Time UI Error Clearing:** State-area-based handlers clear individual field validation messages immediately upon correction.
- **Duplicate Line Item Validation:** In-memory context evaluation prevents duplicate `ItemCode` entries across separate lines within the same document.
- **Cross-Entity & Date Rules:** Enforces organizational consistency (warehouse alignment with company code, supplier role checks) and chronological date rules.

### 4.2. Purchase Order Status Lifecycle
- **New (`N`):** Editable draft or newly saved document.
- **Approved (`A`):** Released document via `releaseDocument` action (requires at least 1 line item).
- **In Delivery (`P`) / Completed (`C`):** Logistical execution lifecycle states (to be updated by Goods Receipts).
- **Cancelled (`X`):** Terminated document via `cancelDocument` action; excluded from downstream processing.

---

## 5. Dynamic Inventory Calculation Concept (Design Target)

Lagerbestände (Inventory balances) will be calculated dynamically in real time from posted movement documents once the full transactional suite is complete:

`Current Stock = Sum(Posted Goods Receipts) - Sum(Posted Goods Issues)`

*Note: This concept is planned for implementation alongside the Goods Receipt and Goods Issue modules in subsequent releases.*