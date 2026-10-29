# Mini ERP – Procurement, Inventory and Sales[cite: 7]

[English](README.md) | [Deutsch](README.de.md) | [Українська](README.ua.md)[cite: 7]

[![SAP ABAP Cloud](https://img.shields.io/badge/SAP-ABAP%20Cloud-0FAAFF?style=flat-square&logo=sap)](https://www.sap.com)[cite: 7]
[![SAP RAP](https://img.shields.io/badge/Model-SAP%20RAP%20(Managed)-0073C6?style=flat-square)](https://help.sap.com)[cite: 7]
[![Clean Core](https://img.shields.io/badge/Architecture-Clean%20Core%20Compliant-green?style=flat-square)](#6-clean-core-principles)[cite: 7]
[![Status](https://img.shields.io/badge/Status-Phase%201%20Complete%20%7C%20Phase%202%20PO%20Implemented-brightgreen?style=flat-square)](#3-implementation-status--roadmap)[cite: 7]

**Version:** 1.0 (MVP)[cite: 7]

---

## 1. Project Overview[cite: 7]

Mini ERP is a demonstration ERP application developed using the SAP ABAP Cloud programming model and the SAP RESTful Application Programming Model (RAP) on SAP BTP ABAP Environment[cite: 7].

The project implements a simplified procurement, inventory, and sales process while following modern SAP development practices, including SAP Clean Core principles, RAP Business Objects, CDS View Entities, OData V4 services, and SAP Fiori Elements[cite: 7].

The application serves as a portfolio project demonstrating cloud-ready ABAP development, strict layer separation, and enterprise design patterns[cite: 7].

Detailed technical architecture and domain model specifications are available in the [Architecture & Technical Design Documentation](docs/Architecture.md)[cite: 7].

---

## 2. Technology Stack[cite: 7]

- **Platform:** SAP BTP ABAP Environment[cite: 7]
- **IDE:** Eclipse ADT (ABAP Development Tools)[cite: 7]
- **Programming Model:** SAP RESTful Application Programming Model (RAP)[cite: 7]
- **Data Modeling:** ABAP Core Data Services (CDS View Entities)[cite: 7]
- **Persistence:** Transparent Tables with RAP Draft Support[cite: 7]
- **Services:** OData V4 UI Services[cite: 7]
- **UI Framework:** SAP Fiori Elements[cite: 7]
- **Development Standard:** SAP Clean Core / ABAP Cloud[cite: 7]

---

## 3. Implementation Status & Roadmap[cite: 7]

The project is structured into two main phases[cite: 7].

### Phase 1: Master Data Management (Completed)[cite: 7]
- **Company Code:** Operational organizations with country and currency configuration (Manual Keying)[cite: 7].
- **Warehouse:** Storage locations assigned to a specific Company Code (Auto-generated Key)[cite: 7].
- **Business Partner:** Customers, suppliers, or entities combining both roles (Auto-generated Key)[cite: 7].
- **Item Group:** Product classifications with default tax configurations (Auto-generated Key)[cite: 7].
- **Item:** Tangible products and intangible services (Auto-generated Key)[cite: 7].
- **VAT Rate:** Central engine for tax percentage maintenance (Auto-generated Key)[cite: 7].

### Phase 2: Transactional Engine & Inventory (In Progress)[cite: 7]
- **Purchase Orders (Completed):** Full procurement document lifecycle (New, Approved, In Delivery, Completed, Cancelled) featuring company-scoped document numbering, automated calculations of item amounts and document totals, duplicate line item checks, and real-time interactive validations.
- **Goods Receipts & Sales Engine:** Partial receipts, Sales Orders, and Goods Issues[cite: 7].
- **Dynamic Stock Calculation:** Real-time inventory calculation (`Stock = Receipts - Issues`) calculated dynamically via CDS View Entities without persistent stock tables[cite: 7].

---

## 4. Key Architectural Features[cite: 7]

### Hybrid Number Range Engine (`ZCL_MERP_NUM_RANGE_UTIL`)[cite: 7]
- **Primary Key Allocation:** Standard SAP Number Range Object (NRO) API via `cl_numberrange_runtime`[cite: 7].
- **DB Max Fallback:** Dynamic OSQL fallback scanning both Active and Draft tables (`nmax`) to prevent key collisions during parallel user draft sessions[cite: 7].
- **NRO Synchronization:** Automated interval leveling via `cl_numberrange_intervals` after seed execution[cite: 7].

### Automated Tax & Value Inheritance (`ZCL_MERP_MD_UTIL`)[cite: 7]
- **Hierarchical VAT Determination:** Item VAT Code inherits from `Item Master` -> `Item Group Default` -> `Manual Fallback`[cite: 7].

### Relational Integrity & Usage Prechecks[cite: 7]
- **Bulk Precheck Pattern:** Implemented in RAP Behavior Handlers (`precheck_delete`) across all Master Data BOs to prevent deletion of in-use entities[cite: 7].
- **Bulk SQL Optimization:** Queries dedicated CDS Usage Views (`ZMERP_I_<ENTITY>_USAGE`) with deduplicated key sets to eliminate $N+1$ query overhead[cite: 7].

### Operational Status Governance[cite: 7]
- **Soft Blocking:** Master Data records use an `IsBlocked` flag to preserve historical data integrity instead of hard deletion[cite: 7].
- **Value Help Filtering:** All operational Value Help Views (`ZMERP_I_<ENTITY>_VH`) enforce `WHERE IsBlocked = ''` to prevent selection of inactive records in downstream documents[cite: 7].

### Automated Calculations & Real-Time Validation
- **Document Calculation Engine:** Automated, real-time calculation of item-level financial amounts upon quantity, price, or tax rate changes, alongside instant aggregation of total document amounts at the header level.
- **Interactive Error Handling:** Instant clearing and highlighting of validation messages directly as the user fills out or corrects fields, ensuring a smooth user experience.
- **Duplicate Prevention:** Automatic detection and blocking of duplicate product entries within the same document.

### Automated Initial Setup (`ZCL_MERP_INITIAL_SETUP`)[cite: 7]
- Console runner implementing `IF_OO_ADT_CLASSRUN`[cite: 7].
- Populates seed data across all Master Data entities[cite: 7].
- Clears both Active and RAP Draft tables during initialization[cite: 7].
- Automatically syncs NRO sequence levels to reflect seeded records[cite: 7].

---

## 5. Service Binding & UI Preview[cite: 7]

The OData V4 service `ZUI_MERP_O4` exposes all Master Data entities for SAP Fiori Elements consumption[cite: 7].

---

## 6. Clean Core Principles[cite: 7]

- **Strict ABAP Cloud Scope:** Zero usage of deprecated ABAP statements or unreleased SAP standard APIs[cite: 7].
- **RAP Draft Capabilities:** Built-in state handling for transactional stateless HTTP communication[cite: 7].
- **Automated Auditing:** Unified population of audit fields (`CREATED_BY`, `CREATED_AT`, `LAST_CHANGED_AT`, etc.)[cite: 7].

---

## 7. Setup & Execution[cite: 7]

1. Import the repository into your SAP BTP ABAP Environment using **abapGit** in Eclipse ADT[cite: 7].
2. Activate CDS View Entities, Behavior Definitions, and Service Bindings in hierarchical order[cite: 7].
3. Open Service Binding `ZUI_MERP_O4` and click **Publish** (or **Unpublish / Publish**) to register the local OData V4 endpoint[cite: 7].
4. Run class `ZCL_MERP_INITIAL_SETUP` in Eclipse ADT (`F9`) to populate seed data and synchronize Number Ranges[cite: 7].
5. Preview applications via Fiori Elements Preview in the Service Binding editor[cite: 7].

---

## 📄 Related Documentation[cite: 7]
- 📘 [Architecture & Technical Design Specifications](docs/Architecture.md)[cite: 7]