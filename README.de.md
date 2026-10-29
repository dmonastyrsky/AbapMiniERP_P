# Mini-ERP – Einkauf, Lagerhaltung und Vertrieb[cite: 10]

[English](README.md) | [Deutsch](README.de.md) | [Українська](README.ua.md)[cite: 10]

[![SAP ABAP Cloud](https://img.shields.io/badge/SAP-ABAP%20Cloud-0FAAFF?style=flat-square&logo=sap)](https://www.sap.com)[cite: 10]
[![SAP RAP](https://img.shields.io/badge/Model-SAP%20RAP%20(Managed)-0073C6?style=flat-square)](https://help.sap.com)[cite: 10]
[![Clean Core](https://img.shields.io/badge/Architecture-Clean%20Core%20Compliant-green?style=flat-square)](#6-clean-core-prinzipien)[cite: 10]
[![Status](https://img.shields.io/badge/Status-Phase%201%20Complete%20%7C%20Phase%202%20PO%20Implemented-brightgreen?style=flat-square)](#3-implementierungsstatus-und-roadmap)[cite: 7, 10]

**Version:** 1.0 (MVP)[cite: 10]

---

## 1. Projektübersicht[cite: 10]

Mini ERP ist eine Demonstrations-ERP-Anwendung, die mit dem SAP ABAP Cloud-Programmiermodell und dem SAP RESTful Application Programming Model (RAP) in der SAP BTP ABAP-Umgebung entwickelt wurde.[cite: 10]

Das Projekt implementiert einen vereinfachten Einkaufs-, Lager- und Vertriebsprozess und folgt dabei modernen SAP-Entwicklungspraktiken, einschließlich SAP Clean-Core-Prinzipien, RAP Business Objects, CDS View Entities, OData V4-Services und SAP Fiori Elements.[cite: 10]

Die Anwendung dient als Portfolio-Projekt zur Demonstration einer cloudfähigen ABAP-Entwicklung, strikter Schichtentrennung und Best-Practice-Entwurfsmustern.[cite: 10]

Detaillierte technische Architektur- und Domänenmodell-Spezifikationen finden Sie in der [Architektur & Technisches Design](docs/Architecture.de.md).[cite: 7, 9, 10]

---

## 2. Technologie-Stack[cite: 10]

- **Plattform:** SAP BTP ABAP Environment[cite: 10]
- **IDE:** Eclipse ADT (ABAP Development Tools)[cite: 10]
- **Programmiermodell:** SAP RESTful Application Programming Model (RAP)[cite: 10]
- **Datenmodellierung:** ABAP Core Data Services / CDS View Entities[cite: 10]
- **Persistenz:** Transparent Tables mit RAP Draft-Unterstützung[cite: 10]
- **Services:** OData V4 UI Services[cite: 10]
- **UI-Framework:** SAP Fiori Elements[cite: 10]
- **Entwicklungsstandard:** SAP Clean Core / ABAP Cloud[cite: 10]

---

## 3. Implementierungsstatus und Roadmap[cite: 10]

Das Projekt ist in zwei Hauptphasen unterteilt.[cite: 10]

### Phase 1: Stammdatenverwaltung (Master Data Management) – Abgeschlossen[cite: 10]
- **Company Code (Unternehmen):** Operative Organisationseinheiten mit Länder- und Währungseinstellungen (Manuelle Schlüsselvergabe).[cite: 10]
- **Warehouse (Lager):** Physische Lagerorte, die einem Unternehmen zugeordnet sind (Automatische Schlüsselvergabe).[cite: 10]
- **Business Partner (Geschäftspartner):** Kunden, Lieferanten oder kombinierte Partner (Automatische Schlüsselvergabe).[cite: 10]
- **Item Group (Produktgruppen):** Produktklassifizierung mit Standard-MwSt.-Satz für automatische Vererbung (Automatische Schlüsselvergabe).[cite: 10]
- **Item (Produkte):** Materielle Produkte und immaterielle Dienstleistungen (Automatische Schlüsselvergabe).[cite: 10]
- **VAT Rate (MwSt.-Sätze):** Zentrale Engine für die Konfiguration und Pflege von Steuersätzen (Automatische Schlüsselvergabe).[cite: 10]

### Phase 2: Transactional Engine & Inventory (Transaktions-Engine & Lagerhaltung) – In Arbeit[cite: 10]
- **Purchase Orders (Bestellungen) – Abgeschlossen:** Vollständiger Beschaffungsbeleg-Lebenszyklus (Neu, Genehmigt, In Lieferung, Abgeschlossen, Storniert) mit unternehmensbezogener Belegnummerierung, automatisierter Berechnung von Positionssummen und Beleggesamtsummen, Duplikatprüfung von Belegzeilen sowie interaktiven Echtzeit-Validierungen.[cite: 7, 10]
- **Goods Receipts & Sales Engine:** Teilwareneingänge, Kundenaufträge und Warenausgänge.[cite: 10]
- **Dynamic Stock Calculation (Dynamische Bestandsberechnung):** Echtzeit-Lagerbestandsberechnung (`Bestand = Wareneingänge - Warenausgänge`), die dynamisch über CDS View Entities ohne persistente Bestandstabellen berechnet wird.[cite: 10]

---

## 4. Wichtigste Architekturmerkmale[cite: 10]

### Hybride Nummernkreis-Engine (`ZCL_MERP_NUM_RANGE_UTIL`)[cite: 10]
- **Primärschlüsselzuweisung:** Standard SAP Number Range Object (NRO) API über `cl_numberrange_runtime`.[cite: 10]
- **DB Max Fallback:** Dynamischer Open-SQL-Fallback, der sowohl aktive Tabellen als auch Entwurfstabellen (`nmax`) scannt, um Schlüsselkollisionen während paralleler Benutzer-Draft-Sitzungen zu verhindern.[cite: 10]
- **NRO-Synchronisation:** Automatische Intervallanpassung über `cl_numberrange_intervals` nach der Ausführung des Initial-Setups (Seed).[cite: 10]

### Automatische Steuer- und Wertererbung (`ZCL_MERP_MD_UTIL`)[cite: 10]
- **Hierarchische Ermittlung der MwSt.:** Der Artikel-Steuercode vererbt sich aus `Item Master` -> `Item Group Default` -> `Manual Fallback`.[cite: 10]

### Relationale Integrität & Verwendungsprüfungen[cite: 10]
- **Bulk-Precheck-Muster:** Implementiert in RAP Behavior Handlern (`precheck_delete`) über alle Stammdaten-BOs hinweg, um das Löschen verwendeter Entitäten zu verhindern.[cite: 10]
- **Bulk-SQL-Optimierung:** Fragt dedizierte CDS Usage Views (`ZMERP_I_<ENTITY>_USAGE`) mit bereinigten Schlüsselsets ab, um den $N+1$-Abfrage-Overhead zu eliminieren.[cite: 10]

### Operationales Status-Management[cite: 10]
- **Soft Blocking:** Stammdatensätze verwenden ein `IsBlocked`-Flag, um die historische Datenintegrität anstelle von hartem Löschen zu wahren.[cite: 10]
- **Value Help-Filterung:** Alle operativen Value Help Views (`ZMERP_I_<ENTITY>_VH`) erzwingen `WHERE IsBlocked = ''`, um die Auswahl inaktiver Datensätze in nachgelagerten Belegen zu verhindern.[cite: 10]

### Automatisierte Berechnungen & Echtzeit-Validierung[cite: 7, 10]
- **Belegberechnungs-Engine:** Automatisierte, Echtzeit-Berechnung finanzieller Positionsbeträge bei Änderungen von Menge, Preis oder Steuersatz sowie sofortige Aggregation der Beleg-Gesamtsummen auf Kopfebene.[cite: 7, 10]
- **Interaktive Fehlerbehandlung:** Sofortiges Löschen und Hervorheben von Validierungsmeldungen direkt während der Benutzer Felder ausfüllt oder korrigiert, was eine reibungslose Benutzererfahrung gewährleistet.[cite: 7, 10]
- **Duplikatserkennung:** Automatische Erkennung und Blockierung doppelt erfasster Produkte innerhalb desselben Belegs.[cite: 7, 10]

### Automatisiertes Initial-Setup (`ZCL_MERP_INITIAL_SETUP`)[cite: 10]
- Console-Runner-Klasse, die das Interface `IF_OO_ADT_CLASSRUN` implementiert.[cite: 10]
- Füllt Testdaten über alle Stammdaten-Entitäten hinweg auf.[cite: 10]
- Löscht während der Initialisierung sowohl aktive Tabellen als auch RAP-Draft-Tabellen.[cite: 10]
- Synchronisiert automatisch die NRO-Sequenzstufen, um die generierten Datensätze widerzuspiegeln.[cite: 10]

---

## 5. Service Binding & UI Preview[cite: 10]

Der OData V4-Service `ZUI_MERP_O4` stellt alle Stammdaten-Entitäten für die Nutzung durch SAP Fiori Elements bereit.[cite: 10]

---

## 6. Clean Core-Prinzipien[cite: 10]

- **Strikter ABAP Cloud-Scope:** Keine Verwendung von veralteten ABAP-Anweisungen oder nicht freigegebenen SAP-Standard-APIs.[cite: 10]
- **RAP Draft-Funktionen:** Integrierte Statusbehandlung für transaktionale, zustandslose HTTP-Kommunikation.[cite: 10]
- **Automatisierte Auditierung:** Einheitliche Befüllung von Audit-Feldern (`CREATED_BY`, `CREATED_AT`, `LAST_CHANGED_AT`, etc.).[cite: 10]

---

## 7. Einrichtung und Ausführung[cite: 10]

1. Importieren Sie das Repository über **abapGit** in Eclipse ADT in Ihre SAP BTP ABAP-Umgebung.[cite: 10]
2. Aktivieren Sie CDS View Entities, Behavior Definitions und Service Bindings in hierarchischer Reihenfolge.[cite: 10]
3. Öffnen Sie das Service Binding `ZUI_MERP_O4` und klicken Sie auf **Publish** (oder **Unpublish / Publish**), um den lokalen OData V4-Endpunkt zu registrieren.[cite: 10]
4. Führen Sie die Klasse `ZCL_MERP_INITIAL_SETUP` in Eclipse ADT (`F9`) aus, um die Initialdaten zu laden und die Nummernkreise zu synchronisieren.[cite: 10]
5. Testen Sie die Anwendungen über die Fiori Elements-Vorschau im Service-Binding-Editor.[cite: 10]

---

## 📄 Zugehörige Dokumentation[cite: 10]
- 📘 [Architektur & Technisches Design](docs/Architecture.de.md)[cite: 7, 10]