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

## 3. Transactional Document Architecture (Phase 2 Design)

Transactional documents follow a Header (1) to Line Items (N) composition structure:
- **Procurement Chain:** Purchase Order -> Goods Receipt
- **Sales Chain:** Sales Order -> Goods Issue

### Document Status Lifecycle
- **Open:** Active draft or open document, editable.
- **Posted:** Read-only. Affects inventory calculations and acts as source for follow-up documents.
- **Cancelled:** Read-only. Excluded from inventory calculations.

---

## 4. Dynamic Inventory Calculation Concept

Inventory balances are not statically stored in persistent tables. Current stock levels are calculated dynamically in real time from posted inventory movement documents:

`Current Stock = Sum(Posted Goods Receipts) - Sum(Posted Goods Issues)`

### Rules:
- Tracked per Company Code + Warehouse + Item.
- Excludes items where Item Type = Service (`S`).
- Insufficient stock errors are enforced during the transition of Goods Issue documents to Posted status via RAP Validations on Save.
