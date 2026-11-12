# Mini ERP – Architecture & Technical Design

[⬅ Back to README.md](../README.md) | [English](Architecture.md) | [Deutsch](Architecture.de.md) | [Українська](Architecture.ua.md)

## 1. Domain Model

6 master data objects, 4 document types (each header + items) and a stock journal.

### 1.1 Master Data

| Object (table) | Key | Main fields | Read-only once used in documents |
|---|---|---|---|
| Company Code (`ZMERP_COMP_CODE`) | `1000`, manual | name, prefix (2 letters, unique), currency, country | prefix, currency |
| Warehouse (`ZMERP_WAREHOUSE`) | `WH001` | name, company code | company code |
| Business Partner (`ZMERP_BUS_PART`) | `00001` | name, customer / supplier role (at least one), tax number, address, contact | a role in use |
| Item Group (`ZMERP_ITEM_GROUP`) | `00001` | description, default VAT code | — |
| Item (`ZMERP_ITEM`) | `00001` | description, article, type (P product / S service), group, default VAT code, base unit | type, base unit |
| VAT Rate (`ZMERP_VAT_RATE`) | `V001` (shown as text) | description, percentage 0–100 | percentage |

- Every object has a "blocked" flag. Business partners are shared across companies; a warehouse belongs to exactly one company.
- The item group proposes the item's default VAT code; documents take unit and VAT from the item.
- The company currency is the stock valuation currency and the only currency allowed in documents.

### 1.2 Documents

| Document | Tables | Root view | Statuses |
|---|---|---|---|
| Purchase Order | `ZMERP_PO_HDR` / `_ITM` | `ZMERP_R_PURCHASEORDER` | New, Approved, In Delivery, Completed, Cancelled |
| Goods Receipt | `ZMERP_GR_HDR` / `_ITM` | `ZMERP_R_GOODSRECEIPT` | New, Posted, Cancelled |
| Sales Order | `ZMERP_SO_HDR` / `_ITM` | `ZMERP_R_SALESORDER` | Open, In Process, Completed, Rejected |
| Goods Issue | `ZMERP_GI_HDR` / `_ITM` | `ZMERP_R_GOODSISSUE` | New, Posted, Cancelled |

Header: number, status, document date, posting date, company, warehouse, partner, currency, responsible person, remarks, net and gross totals; plus partner reference (supplier / customer reference), PO delivery date, order reference in GR / GI.
Line: line number (10, 20, …), item, quantity, unit, price, VAT code, net / VAT / gross amount, currency; GR / GI lines reference the order line.

---

## 2. Numbering

| Object | Example | Strategy |
|---|---|---|
| Company Code | `1000` | manual |
| Warehouse | `WH001` | number range at creation (`ZNR_WHSE`) |
| Business Partner, Item Group, Item | `00001` | number range at creation (`ZNR_BP`, `ZNR_IG`, `ZNR_ITEM`) |
| VAT Rate | `V001` | number range at creation (`ZNR_VAT`) |
| Purchase Order, Goods Receipt, Sales Order, Goods Issue | `DE00000001` | company prefix + 8 digits, one range per type and company (`ZNR_PURORD`, `ZNR_GDSREC`, `ZNR_SALORD`, `ZNR_GDSISS`), assigned on first save |

- All number ranges are buffered with one number in main memory (numbers are drawn before the save phase).
- No fallback: if the number range fails, the record / document is not saved. A document is never saved without a number.
- Numbers need not be gap-free; drafts leave no gaps because they have no number.
- A new company gets intervals for all document number ranges automatically. "Clear all" resets them; the seed synchronises the master data intervals with the database.
- Central class: `ZCL_MERP_NUM_RANGE_UTIL` (bulk methods for master data codes and document numbers), using the released SAP APIs `cl_numberrange_runtime` (numbers) and `cl_numberrange_intervals` (intervals).

---

## 3. Master Data Rules

- **Delete check:** each object has a usage view (`ZMERP_I_<X>_USAGE`, active data only). Any usage blocks deletion (`precheck_delete`, RAP fail cause "dependency"); one message per using object. Mass delete is all-or-nothing.
- **Read-only fields** (table above) are locked only by usage in documents, not by other master data.
- **Partner roles:** the supplier role is locked when used in purchasing, the customer role when used in sales; an unset role can always be set.
- **Checks on input:** company prefix (unique among active companies) and VAT percentage; other mandatory fields on save.
- **SAP master data** (currency, country, unit) is checked by the value help and in the backend, because API calls bypass the value help.
- **Blocked = obsolete:** value helps hide blocked records, defaults do not propose them; existing references stay valid, so documents stay editable and postable.
- Each object has a selector class (`ZCL_MERP_MD_<X>_SEL`, with interface) through which other objects read it.

---

## 4. Documents

### 4.1 Common Behaviour
- Defaults: document date today, posting date = document date, first status. A company change clears a warehouse of another company; orders take the company currency.
- Editing only in the first status; actions only on saved documents. The company is read-only once the document has a number.
- Header checks: company, warehouse and partner exist; warehouse belongs to the company; partner has the right role; company currency; document and posting date not in the future; posting date ≥ document date.
- Lines: item → unit and VAT; quantity and price > 0; net = quantity × price; totals on every change. Duplicate items are rejected.
- Delete only in the first status or when cancelled / rejected, and only if no other document references it.
- Draft locks are standard RAP: an order draft locks the order for about 15 minutes after the last change; posting its follow-up documents fails meanwhile with "order locked".
- Shared logic: `ZCL_MERP_DOC_ITEM_LOGIC` (defaults, amounts, totals), `ZCL_MERP_DOC_ORDER_REF_LOGIC` (follow-up document against the order lines), `ZCL_MERP_DOC_VALIDATOR`, `ZCL_MERP_DOC_CALC`.

### 4.2 Purchase Order

| Status | Reached by |
|---|---|
| New | create |
| Approved | Release (needs a line); unpost of all receipts |
| In Delivery | action In Delivery (date dialog, proposed delivery date); partial receipt |
| Completed | everything received; action Complete (from Approved / In Delivery) |
| Cancelled | Cancel from New, Approved, In Delivery (the latter only without posted receipts) |

- Receipts are possible in Approved and In Delivery. The action **Goods Receipt** creates a goods receipt draft with the PO reference.
- Supplier reference (free text) and delivery date.

### 4.3 Goods Receipt
- Always based on a PO. Selecting the PO (or creating from it) fills the header (company, warehouse, supplier, currency, supplier reference) and one line per PO line with the open quantity.
- Changing company, warehouse or supplier away from the PO clears the PO and its lines.
- PO lines: only the quantity is editable. Manual lines may be added and are fully editable. Line action **Fill Open Quantity**; columns "Open in PO" and "Purchase Order".
- **Post** checks: status, at least one line, company currency, PO approved / in delivery, posting date ≥ PO date, PO line still exists, quantity ≤ open quantity. If the quantity equals the open quantity, the open amounts are taken (the last receipt closes the cents). Several receipts of one PO in one request are checked one after another.
- After Post: PO status updated, stock movements written. **Unpost** returns the receipt to New (only if the stock does not go negative) and recalculates the PO status. **Cancel** only from New.

### 4.4 Sales Order
Mirror of the purchase order with sales-specific differences:

| Status | Reached by |
|---|---|
| Open | create; unpost of all goods issues |
| In Process | partial goods issue |
| Completed | everything issued; action Complete from In Process |
| Rejected | action Reject from Open |

- Edit only when Open; delete when Open or Rejected and not referenced by a goods issue.
- Price entered manually; customer reference free text; at least one line to save; no delivery date, no release step.
- The action **Goods Issue** creates a goods issue draft with the SO reference. No reservation: availability is checked only when issuing.

### 4.5 Goods Issue
Mirror of the goods receipt with the sales order in the role of the PO:
- Always based on an SO; header and lines from the SO's open quantities; manual lines possible; columns "Sales Order", "Open in SO" and "In Stock" (current stock of the warehouse).
- **Post** checks as the goods receipt (SO open / in process) plus **stock availability** of every product line; then SO status and stock movements. **Unpost** needs no stock check.

---

## 5. Inventory

- **Journal** `ZMERP_STOCK_MOV`: company, warehouse, item, quantity (+ receipt / − issue), unit, value in company currency, posting date, document reference. Written only in the save phase by `ZCL_MERP_STOCK_POSTING`; a status change deletes the document's movements, posting writes new ones (no reversal documents).
- **Balances** `ZMERP_R_STOCK_BALANCE`: sum of quantity and value per company, warehouse, item and unit; no balance table.
- **Valuation:** a receipt adds its net amount (VAT is not stock value). An issue is valued at the moving average cost: quantity × value ÷ quantity of the balance, rounded to 2 decimals; issuing the whole remaining quantity takes the whole remaining value (closes at 0.00). Valuation area = company + warehouse (like the SAP plant).
- **Availability and locks** (`ZCL_MERP_STOCK_CONTROL`): every Post / Unpost first locks the order and the stock per company, warehouse and item, then reads and checks. A locked document fails with a message naming the order or the locking user. Several lines and documents of one request are checked one after another.
- Current balance, not the balance on the posting date, is used; back-dated postings are allowed.
- Only products (item type P) create stock; services do not.
- **Stock app** (`ZUI_MERP_STOCK`, read-only): Stock Balances (list + movements) and Stock Movements; filters company, warehouse, item, item group, posting date.

---

## 6. Test Data

- `ZCL_MERP_CLEAR_ALL_DATA`: deletes stock, documents, document intervals, master data and master data intervals (in this order).
- `ZCL_MERP_INITIAL_SETUP` (F9): clear all, then via RAP (EML) level by level:
  - companies 1000–3000 and blocked 4000 (EUR), VAT rates, item groups, 10 warehouses, 16 items (incl. services and one blocked), 13 partners (suppliers, customers, both, one blocked);
  - 9 purchase orders and 6 sales orders with their receipts and issues, covering every status, the last-receipt cents case, moving-average valuation and an intentionally failing issue (not enough stock).
- **Demo company 3000:** an open receipt (cents case) and the remaining moving-average stock to issue are left for live demos.

---

## 7. Conventions and Simplifications

- **Naming:** tables `ZMERP_<X>` (+ `_D` draft), root views `ZMERP_R_<X>`, projections `ZMERP_C_<X>`, helper / value help / usage views `ZMERP_I_…`, classes `ZCL_MERP_…` with interfaces `ZIF_MERP_…`, exceptions `ZCX_MERP_…`, message classes `ZMC_MERP_…`, number ranges `ZNR_…`.
- **RAP technique:** behavior definitions in strict mode 2; optimistic locking via ETag (`LocalLastChangedAt`) and total ETag for drafts (`LastChangedAt`); side effects in the projections refresh dependent fields and totals in the UI; global authorization check (allows everything).
- **Tests:** ABAP Unit test class for the company code selector.
- **Pattern:** sales documents copy their purchasing twins (sales order ← purchase order, goods issue ← goods receipt); other objects are read only through selector classes.
- **Simplifications compared to SAP:** unpost instead of reversal documents; no order line status; no reservations; one currency per company; no authorizations (everything allowed); a communication scenario only for purchasing.
