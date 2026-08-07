# Mini-ERP – Einkauf, Lagerhaltung und Vertrieb

[English](README.md) | [Deutsch](README.de.md) | [Українська](README.ua.md)

[![SAP ABAP Cloud](https://img.shields.io/badge/SAP-ABAP%20Cloud-0FAAFF?style=flat-square&logo=sap)](https://www.sap.com)
[![SAP RAP](https://img.shields.io/badge/Model-SAP%20RAP%20(Managed)-0073C6?style=flat-square)](https://help.sap.com)
[![Clean Core](https://img.shields.io/badge/Architecture-Clean%20Core%20Compliant-green?style=flat-square)](#6-clean-core-prinzipien)
[![Status](https://img.shields.io/badge/Status-Master%20Data%20Complete%20%7C%20Transactions%20In%20Progress-orange?style=flat-square)](#3-implementierungsstatus-und-roadmap)

**Version:** 1.0 (MVP)

---

## 1. Projektübersicht

Mini ERP ist eine Demonstrations-ERP-Anwendung, die mit dem SAP ABAP Cloud-Programmiermodell und dem SAP RESTful Application Programming Model (RAP) in der SAP BTP ABAP-Umgebung entwickelt wurde.

Das Projekt implementiert einen vereinfachten Einkaufs-, Lager- und Vertriebsprozess und folgt dabei modernen SAP-Entwicklungspraktiken, einschließlich SAP Clean-Core-Prinzipien, RAP Business Objects (RAP-Geschäftsobjekte), CDS View Entities (CDS-Query-Views), OData V4-Services und SAP Fiori Elements.

Die Anwendung dient als Portfolio-Projekt zur Demonstration einer cloudfähigen ABAP-Entwicklung, strikter Schichtentrennung und Best-Practice-Entwurfsmustern (Enterprise Design Patterns).

Detaillierte technische Architektur- und Domänenmodell-Spezifikationen finden Sie in der [Architektur & Technisches Design](docs/Architecture.de.md).

---

## 2. Technologie-Stack

- **Plattform:** SAP BTP ABAP Environment (SAP BTP ABAP-Umgebung)
- **IDE:** Eclipse ADT (ABAP Development Tools)
- **Programmiermodell:** SAP RESTful Application Programming Model (RAP)
- **Datenmodellierung:** ABAP Core Data Services / CDS View Entities (CDS-Query-Views)
- **Persistenz:** Transparent Tables (Transparente Tabellen) mit RAP Draft-Unterstützung (RAP-Entwurfsunterstützung)
- **Services:** OData V4 UI Services (OData V4 UI-Dienste)
- **UI-Framework:** SAP Fiori Elements
- **Entwicklungsstandard:** SAP Clean Core / ABAP Cloud

---

## 3. Implementierungsstatus und Roadmap

Das Projekt ist in zwei Hauptphasen unterteilt.

### Phase 1: Master Data Management (Stammdatenverwaltung) – Abgeschlossen
- **Company Code (Buchungskreis):** Rechtliche Unternehmenseinheiten (Manuelle Schlüsseleingabe).
- **Warehouse (Warehouse / Lager):** Physische Lagerorte, die an Company Codes gebunden sind (Automatisch generierter Schlüssel).
- **Business Partner (Geschäftspartner):** Kunden, Lieferanten oder kombinierte Einheiten (Automatisch generierter Schlüssel).
- **Item Group (Warengruppe):** Produktklassifizierung mit Standard-MwSt.-Zuordnung (Automatisch generierter Schlüssel).
- **Item Master (Artikelstamm):** Materielle Produkte und immaterielle Dienstleistungen (Automatisch generierter Schlüssel).
- **VAT Rate (Umsatzsteuersatz):** Steuerkonfigurations-Engine (Automatisch generierter Schlüssel).

### Phase 2: Transactional Engine & Inventory (Transaktions-Engine & Lagerhaltung) – In Arbeit
- **Purchase Orders & Goods Receipts (Bestellungen & Wareneingänge):** Beschaffungslebenszyklus mit Unterstützung für Teilwareneingänge.
- **Sales Orders & Goods Issues (Kundenaufträge & Warenausgänge):** Vertriebslebenszyklus mit strikten Bestandsprüfungen.
- **Dynamic Stock Calculation (Dynamische Bestandsberechnung):** Echtzeit-Lagerbestandsberechnung (`Bestand = Wareneingänge - Warenausgänge`), die dynamisch über CDS View Entities ohne persistente Bestandstabellen berechnet wird.

---

## 4. Wichtigste Architekturmerkmale

### Hybride Nummernkreis-Engine (`ZCL_MERP_NUM_RANGE_UTIL`)
- **Primärschlüsselzuweisung:** Standard SAP Number Range Object (NRO) API über `cl_numberrange_runtime`.
- **DB Max Fallback:** Dynamischer Open-SQL-Fallback, der sowohl aktive Tabellen als auch Entwurfstabellen (`nmax`) scannt, um Schlüsselkollisionen während paralleler Benutzer-Draft-Sitzungen zu verhindern.
- **NRO-Synchronisation:** Automatische Intervallanpassung über `cl_numbernumber_intervals` nach der Ausführung des Initial-Setups (Seed).

### Automatische Steuer- und Wertererbung (`ZCL_MERP_MD_UTIL`)
- **Hierarchische Ermittlung der MwSt.:** Der Artikel-Steuercode vererbt sich aus `Item Master` -> `Item Group Default` -> `Manual Fallback` (Manueller Rückfallwert).
- **Lösch-Vorprüfungen:** Validierung der relationalen Integrität, die das Löschen von referenzierten Master Data-Entitäten verhindert, bevor Datenbank-Trigger greifen.

### Automatisiertes Initial-Setup (`ZCL_MERP_INITIAL_SETUP`)
- Console-Runner-Klasse, die das Interface `IF_OO_ADT_CLASSRUN` implementiert.
- Füllt Testdaten (Seed Data) über alle 6 Master Data-Entitäten hinweg auf.
- Löscht während der Initialisierung sowohl aktive Tabellen als auch RAP-Draft-Tabellen.
- Synchronisiert automatisch die NRO-Sequenzstufen, um die generierten Datensätze widerzuspiegeln.

---

## 5. Service Binding & UI Preview (Service-Bindung & UI-Vorschau)

Der OData V4-Service `ZUI_MERP_O4` stellt alle Master Data-Entitäten für die Nutzung durch SAP Fiori Elements bereit.

---

## 6. Clean Core-Prinzipien

- **Strikter ABAP Cloud-Scope:** Keine Verwendung von veralteten ABAP-Anweisungen oder nicht freigegebenen SAP-Standard-APIs.
- **RAP Draft-Funktionen:** Integrierte Statusbehandlung für transaktionale, zustandslose (stateless) HTTP-Kommunikation.
- **Automatisierte Auditierung:** Einheitliche Befüllung von Audit-Feldern (`CREATED_BY`, `CREATED_AT`, `LAST_CHANGED_AT`, etc.).

---

## 7. Einrichtung und Ausführung

1. Importieren Sie das Repository über **abapGit** in Eclipse ADT in Ihre SAP BTP ABAP-Umgebung.
2. Aktivieren Sie CDS View Entities, Behavior Definitions (Verhaltensdefinitionen) und Service Bindings (Service-Bindungen) in hierarchischer Reihenfolge.
3. Öffnen Sie das Service Binding `ZUI_MERP_O4` und klicken Sie auf **Publish** (oder **Unpublish / Publish**), um den lokalen OData V4-Endpunkt zu registrieren.
4. Führen Sie die Klasse `ZCL_MERP_INITIAL_SETUP` in Eclipse ADT (`F9`) aus, um die Initialdaten zu laden und die Nummernkreise zu synchronisieren.
5. Testen Sie die Anwendungen über die Fiori Elements-Vorschau im Service-Binding-Editor.

---

## 📄 Zugehörige Dokumentation
- 📘 [Architektur & Technisches Design](docs/Architecture.de.md)
