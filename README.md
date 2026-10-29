# Mini ERP – Procurement, Inventory and Sales

[English](README.md) | [Deutsch](README.de.md) | [Українська](README.ua.md)

[![SAP ABAP Cloud](https://img.shields.io/badge/SAP-ABAP%20Cloud-0FAAFF?style=flat-square&logo=sap)](https://www.sap.com)
[![SAP RAP](https://img.shields.io/badge/Model-SAP%20RAP%20(Managed)-0073C6?style=flat-square)](https://help.sap.com)
[![Clean Core](https://img.shields.io/badge/Architecture-Clean%20Core%20Compliant-green?style=flat-square)](#6-clean-core-principles)
[![Status](https://img.shields.io/badge/Status-Master%20Data%20Complete%20%7C%20Transactions%20In%20Progress-orange?style=flat-square)](#3-implementation-status--roadmap)

**Version:** 1.0 (MVP)

---

## 1. Project Overview

Mini ERP is a demonstration ERP application developed using the SAP ABAP Cloud programming model and the SAP RESTful Application Programming Model (RAP) on SAP BTP ABAP Environment.

The project implements a simplified procurement, inventory, and sales process while following modern SAP development practices, including SAP Clean Core principles, RAP Business Objects, CDS View Entities, OData V4 services, and SAP Fiori Elements.

The application serves as a portfolio project demonstrating cloud-ready ABAP development, strict layer separation, and enterprise design patterns.

Detailed technical architecture and domain model specifications are available in the [Architecture & Technical Design Documentation](docs/Architecture.md).

---

## 2. Technology Stack

- **Platform:** SAP BTP ABAP Environment
- **IDE:** Eclipse ADT (ABAP Development Tools)
- **Programming Model:** SAP RESTful Application Programming Model (RAP)
- **Data Modeling:** ABAP Core Data Services (CDS View Entities)
- **Persistence:** Transparent Tables with RAP Draft Support
- **Services:** OData V4 UI Services
- **UI Framework:** SAP Fiori Elements
- **Development Standard:** SAP Clean Core / ABAP Cloud

---

## 3. Implementation Status & Roadmap

The project is structured into two main phases.

### Phase 1: Master Data Management (Completed)
- **Company Code:** Operational organizations with country and currency configuration (Manual Keying).
- **Warehouse:** Storage locations assigned to a specific Company Code (Auto-generated Key).
- **Business Partner:** Customers, suppliers, or entities combining both roles (Auto-generated Key).
- **Item Group:** Product classifications with default tax configurations (Auto-generated Key).
- **Item:** Tangible products and intangible services (Auto-generated Key).
- **VAT Rate:** Central engine for tax percentage maintenance (Auto-generated Key).

### Phase 2: Transactional Engine & Inventory (In Progress)
- **Purchase Orders & Goods Receipts:** Procurement lifecycle with partial receipts support.
- **Sales Orders & Goods Issues:** Sales lifecycle with strict stock checks.
- **Dynamic Stock Calculation:** Real-time inventory calculation (`Stock = Receipts - Issues`) calculated dynamically via CDS View Entities without persistent stock tables.

---

## 4. Key Architectural Features

### Hybrid Number Range Engine (`ZCL_MERP_NUM_RANGE_UTIL`)
- **Primary Key Allocation:** Standard SAP Number Range Object (NRO) API via `cl_numberrange_runtime`.
- **DB Max Fallback:** Dynamic OSQL fallback scanning both Active and Draft tables (`nmax`) to prevent key collisions during parallel user draft sessions.
- **NRO Synchronization:** Automated interval leveling via `cl_numberrange_intervals` after seed execution.

### Automated Tax & Value Inheritance (`ZCL_MERP_MD_UTIL`)
- **Hierarchical VAT Determination:** Item VAT Code inherits from `Item Master` -> `Item Group Default` -> `Manual Fallback`.

### Relational Integrity & Usage Prechecks
- **Bulk Precheck Pattern:** Implemented in RAP Behavior Handlers (`precheck_delete`) across all 6 Master Data BOs to prevent deletion of in-use entities.
- **Bulk SQL Optimization:** Queries dedicated CDS Usage Views (`ZMERP_I_<ENTITY>_USAGE`) with deduplicated key sets to eliminate $N+1$ query overhead.

### Operational Status Governance
- **Soft Blocking:** Master Data records use an `IsBlocked` flag to preserve historical data integrity instead of hard deletion.
- **Value Help Filtering:** All operational Value Help Views (`ZMERP_I_<ENTITY>_VH`) enforce `WHERE IsBlocked = ''` to prevent selection of inactive records in downstream documents.

### Automated Initial Setup (`ZCL_MERP_INITIAL_SETUP`)
- Console runner implementing `IF_OO_ADT_CLASSRUN`.
- Populates seed data across all 6 Master Data entities.
- Clears both Active and RAP Draft tables during initialization.
- Automatically syncs NRO sequence levels to reflect seeded records.

---

## 5. Service Binding & UI Preview

The OData V4 service `ZUI_MERP_O4` exposes all Master Data entities for SAP Fiori Elements consumption.

---

## 6. Clean Core Principles

- **Strict ABAP Cloud Scope:** Zero usage of deprecated ABAP statements or unreleased SAP standard APIs.
- **RAP Draft Capabilities:** Built-in state handling for transactional stateless HTTP communication.
- **Automated Auditing:** Unified population of audit fields (`CREATED_BY`, `CREATED_AT`, `LAST_CHANGED_AT`, etc.).

---

## 7. Setup & Execution

1. Import the repository into your SAP BTP ABAP Environment using **abapGit** in Eclipse ADT.
2. Activate CDS View Entities, Behavior Definitions, and Service Bindings in hierarchical order.
3. Open Service Binding `ZUI_MERP_O4` and click **Publish** (or **Unpublish / Publish**) to register the local OData V4 endpoint.
4. Run class `ZCL_MERP_INITIAL_SETUP` in Eclipse ADT (`F9`) to populate seed data and synchronize Number Ranges.
5. Preview applications via Fiori Elements Preview in the Service Binding editor.

---

## 📄 Related Documentation
- 📘 [Architecture & Technical Design Specifications](docs/Architecture.md)
