# Mini ERP – Architecture & Technical Design

[⬅ Back to README.md](../README.md) | [English](Architecture.md) | [Deutsch](Architecture.de.md) | [Українська](Architecture.ua.md)

## 1. Domain Data Model

The domain architecture consists of 6 Master Data Business Objects and 4 Transactional Document types.

### Master Data Entities
- **Company Code (`ZMERP_COMP_CODE`):** Represents an enterprise legal entity responsible for business transactions. Defines company name, country, and default currency.
- **Warehouse (`ZMERP_WAREHOUSE`):** Represents a physical storage location. Each warehouse belongs to exactly one Company Code.
- **Business Partner (`ZMERP_BUS_PART`):** Represents external counterparties. Supports Customer, Supplier, or combined roles. Shared across all Company Codes.
- **Item Group (`ZMERP_ITEM_GROUP`):** Classifies Items and contains default VAT assignment for automatic determination.
- **Item Master (`ZMERP_ITEM`):** Supports physical Products (triggering stock movements) and intangible Services (commercial calculation only).
- **VAT Rate (`ZMERP_VAT_RATE`):** Defines tax percentages referenced by Item Groups, Items, and transaction document lines.

---

## 2. Key Generation and Formatting Strategy

The system uses standardized prefixes, fixed-length formatting, and dedicated Number Range Objects across all entities:

| Entity | Semantic Prefix | Pattern Example | Key Generation Strategy |
|---|---|---|---|
| **Company Code** | *None* | `1000` | Manual Input |
| **Warehouse** | `WH` | `WH00001` | Early Numbering / Hybrid NRO + DB Max |
| **Business Partner** | *None* | `00001` | Early Numbering / Hybrid NRO + DB Max |
| **Item Group** | *None* | `00001` | Early Numbering / Hybrid NRO + DB Max |
| **Item Master** | *None* | `00001` | Early Numbering / Hybrid NRO + DB Max |
| **VAT Rate** | `V` | `V0001` | Early Numbering / Hybrid NRO + DB Max |

### Key Generation Logic Flow
1. User creates a new entity (triggers RAP Early Numbering).
2. Utility attempts to fetch next number from SAP NRO (`cl_numberrange_runtime`).
3. If NRO is unconfigured or fails, fallback logic queries the database for `MAX(code)` across both Active and Draft tables.
4. Number is incremented and formatted with leading zeros and pre-defined semantic prefix.

---

## 3. Master Data Governance & Integrity Patterns

To enforce data consistency, prevent orphan records, and govern record lifecycle under ABAP Cloud, the Master Data domain employs two standardized design patterns across all Business Objects:

### 3.1. Relational Integrity via Bulk Prechecks (`precheck_delete`)
Before any Master Data entity is deleted, RAP triggers the `precheck_delete` operation in the respective Behavior Implementation class (e.g., `ZBP_MERP_R_COMPANY_CODE`). 

To avoid performance bottlenecks during multi-record deletions, the check uses a bulk query pattern:
- **Key Deduplication:** Target keys from the RAP `keys` table are collected and deduplicated (`DELETE ADJACENT DUPLICATES`).
- **Bulk SQL Dependency Scan:** A single `SELECT DISTINCT` query is executed against a dedicated CDS Usage View (e.g., `ZMERP_I_COMPANY_CODE_USAGE`) using an internal table JOIN (`INNER JOIN @lt_keys`).
- **In-Memory Matching:** Identified dependencies are mapped back to individual records in memory via binary search (`LOOP AT ... WHERE`).
- **RAP Fail & Message Reporting:** If dependencies exist, the record is flagged with `%fail-cause = if_abap_behv=>cause-dependency`, and a user-friendly error message (`ZCM_MERP_MESSAGES`) is returned to the UI, preventing the deletion.

### 3.2. Soft Blocking and Value Help Governance
To deactivate Master Data entities without breaking historical transactional records, all 6 entities implement an `IsBlocked` (`ZMERP_IS_BLOCKED`) field:
- **Data Preservation:** Blocked entities remain in the database for auditability and reporting.
- **Selection Prevention:** All dedicated Value Help CDS View Entities (e.g., `ZMERP_I_COMPANY_CODE_VH`, `ZMERP_I_VAT_RATE_VH`) enforce an explicit condition `WHERE IsBlocked = ''`. This ensures blocked Master Data records cannot be selected in new transactional documents (PO, SO, Inventory Movements).

---

## 4. Transactional Document Architecture (Phase 2 Design)

Transactional documents follow a Header (1) to Line Items (N) composition structure:
- **Procurement Chain:** Purchase Order -> Goods Receipt
- **Sales Chain:** Sales Order -> Goods Issue

### Document Status Lifecycle
- **Open:** Active draft or open document, editable.
- **Posted:** Read-only. Affects inventory calculations and acts as source for follow-up documents.
- **Cancelled:** Read-only. Excluded from inventory calculations.

---

## 5. Dynamic Inventory Calculation Concept

Inventory balances are not statically stored in persistent tables. Current stock levels are calculated dynamically in real time from posted inventory movement documents:

`Current Stock = Sum(Posted Goods Receipts) - Sum(Posted Goods Issues)`

### Rules:
- Tracked per Company Code + Warehouse + Item.
- Excludes items where Item Type = Service (`S`).
- Insufficient stock errors are enforced during the transition of Goods Issue documents to Posted status via RAP Validations on Save.