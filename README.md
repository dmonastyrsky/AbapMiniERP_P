# Mini ERP – Procurement, Inventory and Sales

[English](README.md) | [Deutsch](README.de.md) | [Українська](README.ua.md)

[![SAP ABAP Cloud](https://img.shields.io/badge/SAP-ABAP%20Cloud-0FAAFF?style=flat-square&logo=sap)](https://www.sap.com)
[![SAP RAP](https://img.shields.io/badge/Model-SAP%20RAP%20(Managed%20%2B%20Draft)-0073C6?style=flat-square)](https://help.sap.com)
[![Clean Core](https://img.shields.io/badge/Architecture-Clean%20Core%20Compliant-green?style=flat-square)](#6-clean-core-principles)
[![Status](https://img.shields.io/badge/Status-Procurement%20%7C%20Sales%20%7C%20Stock%20Implemented-brightgreen?style=flat-square)](#3-implementation-status)

**Version:** 1.0 (MVP)

---

## 1. Project Overview

Mini ERP is a demonstration ERP application built with SAP ABAP Cloud and the SAP RESTful Application Programming Model (RAP, managed with draft) on the SAP BTP ABAP Environment (trial).

It covers a simplified but complete business chain: master data → purchasing (purchase order → goods receipt) → inventory → sales (sales order → goods issue). The behaviour follows the SAP standard (purchasing, sales, inventory management) as closely as possible, in simplified form.

The project is a portfolio piece showing cloud-ready ABAP development: RAP business objects, CDS view entities, OData V4 services and SAP Fiori elements.

Details: [Architecture & Technical Design](docs/Architecture.md).

---

## 2. Technology Stack

- **Platform:** SAP BTP ABAP Environment (trial)
- **IDE:** Eclipse ADT (ABAP Development Tools)
- **Programming model:** SAP RAP, managed business objects with draft, strict mode
- **Data modelling:** CDS view entities
- **Persistence:** database tables with RAP draft tables
- **Services:** OData V4 UI services (`ZUI_MERP_O4`, `ZUI_MERP_PROCUREMENT_O4`, `ZUI_MERP_SALES_O4`, `ZUI_MERP_STOCK_O4`)
- **UI:** SAP Fiori elements
- **Development standard:** ABAP Cloud / Clean Core

---

## 3. Implementation Status

| Area | Content | Status |
|---|---|---|
| Master data | Company Code, Warehouse, Business Partner, Item Group, Item, VAT Rate | Implemented |
| Purchasing | Purchase Order, Goods Receipt | Implemented |
| Inventory | Stock journal and balances, availability check, moving average cost, stock locks, read-only stock app | Implemented |
| Sales | Sales Order, Goods Issue | Implemented |
| Test data | Clear all data and seed with documents in every status | Implemented |

**Ideas, not started:** stock transfer between warehouses (like SAP movement type 311); automatic price proposal in documents.
**Deferred:** currency conversion; closing a single order line; stock on a date / period closing.

---

## 4. Key Features

### Numbering
- Master data codes are drawn from number range objects when a record is created (`WH001`, `V001`, `00001`); the company code is entered manually.
- Document numbers run per document type and company, with the company prefix (`DE00000001`), and are assigned on the first save. Drafts have no number.
- No fallback: if the number range fails, nothing is saved (an earlier database-maximum fallback produced duplicate numbers and was removed).
- A new company automatically gets number intervals for all document types.

### Master Data Integrity
- A record used anywhere cannot be deleted; the message names every using object.
- Critical fields become read-only once a record is used in documents (e.g. company currency and prefix, warehouse company, item type and base unit, VAT percentage, a partner role in use).
- Blocking instead of deleting: blocked records are hidden in value helps and are not proposed as defaults; existing documents that reference them stay valid, editable and postable.
- SAP master data (currency, country, unit of measure) is checked in the value help and in the backend.

### Documents
- Line amounts (net, VAT, gross) and header totals are recalculated on every change; prices are net.
- Field-level validation messages disappear as soon as the field is corrected; duplicate items are rejected.
- Only the company currency is allowed until currency conversion exists; posting date may not lie in the future.

### Order → Follow-up Document
- A goods receipt / goods issue is created either from the order (action "Goods Receipt" / "Goods Issue", as SAP "create with reference") or by selecting the order in the follow-up document.
- Lines are filled from the open quantities; when the full open quantity is taken, the remaining open amounts are taken too, so the last receipt or issue closes the cents exactly.
- No over-delivery or over-issue; the order status (in delivery / in process / completed) follows the posted documents automatically.

### Inventory
- Stock movements are written in the save phase of posting; balances are calculated from the journal.
- Goods receipts add stock at their net amount; goods issues are valued at the moving average cost, as in SAP.
- A goods issue is posted only if the stock is available; unposting a goods receipt may not make the stock negative.
- Posting and unposting lock the order and the stock of its items, so parallel postings cannot overbook.
- Services create no stock movements.

### Test Data
- `ZCL_MERP_INITIAL_SETUP` (run with F9) clears all data and creates master data plus purchasing and sales documents covering every status, including rounding and moving-average cases.

---

## 5. Services & UI Preview

One OData V4 service per area:
- **Master data (`ZUI_MERP_O4`):** Company Code, Warehouse, Business Partner, Item Group, Item, VAT Rate.
- **Purchasing (`ZUI_MERP_PROCUREMENT_O4`):** Purchase Orders, Goods Receipts and their lines (plus the master data they reference). Published also via a communication scenario.
- **Sales (`ZUI_MERP_SALES_O4`):** Sales Orders, Goods Issues and their lines (plus the master data they reference).
- **Stock (`ZUI_MERP_STOCK_O4`):** read-only stock balances and stock movements.

---

## 6. Clean Core Principles

- **Strict ABAP Cloud:** released SAP APIs and objects only.
- **RAP draft:** built-in state handling for stateless HTTP communication; standard draft locking.
- **Administrative data:** `CREATED_BY`, `CREATED_AT`, `LOCAL_LAST_CHANGED_BY`, `LOCAL_LAST_CHANGED_AT`, `LAST_CHANGED_AT` are filled by the framework for all records; they also drive optimistic locking (ETag).

---

## 7. Setup & Execution

1. Import the repository into your SAP BTP ABAP Environment with **abapGit** in Eclipse ADT.
2. Activate the objects (dictionary, CDS views, behavior definitions, services).
3. Open the service bindings `ZUI_MERP_O4`, `ZUI_MERP_PROCUREMENT_O4`, `ZUI_MERP_SALES_O4`, `ZUI_MERP_STOCK_O4` and click **Publish** (or **Unpublish / Publish**).
4. Run class `ZCL_MERP_INITIAL_SETUP` in Eclipse ADT (`F9`): it clears all data and creates master data and documents. It can be run again at any time to reset the system.
5. Open the apps via the Fiori elements preview in the service binding editors. Demo company: **3000**.

---

## License
MIT, see [LICENSE](LICENSE).

---

## 📄 Related Documentation
- 📘 [Architecture & Technical Design](docs/Architecture.md)
