# Mini-ERP – Einkauf, Lagerhaltung und Vertrieb

[English](README.md) | [Deutsch](README.de.md) | [Українська](README.ua.md)

[![SAP ABAP Cloud](https://img.shields.io/badge/SAP-ABAP%20Cloud-0FAAFF?style=flat-square&logo=sap)](https://www.sap.com)
[![SAP RAP](https://img.shields.io/badge/Model-SAP%20RAP%20(Managed)-0073C6?style=flat-square)](https://help.sap.com)
[![Clean Core](https://img.shields.io/badge/Architecture-Clean%20Core%20Compliant-green?style=flat-square)](#6-clean-core-prinzipien)
[![Status](https://img.shields.io/badge/Status-Phase%201%20Complete%20%7C%20Phase%202%20PO%20Implemented-brightgreen?style=flat-square)](#3-implementierungsstatus-und-roadmap)

**Version:** 1.0 (MVP)

---

## 1. Projektübersicht

Mini ERP ist eine Demonstrations-ERP-Anwendung, die mit dem SAP ABAP Cloud-Programmiermodell und dem SAP RESTful Application Programming Model (RAP) in der SAP BTP ABAP-Umgebung entwickelt wurde.

Das Projekt implementiert einen vereinfachten Einkaufs-, Lager- und Vertriebsprozess und folgt dabei modernen SAP-Entwicklungspraktiken, einschließlich SAP Clean-Core-Prinzipien, RAP Business Objects, CDS View Entities, OData V4-Services und SAP Fiori Elements.

Die Anwendung dient als Portfolio-Projekt zur Demonstration einer cloudfähigen ABAP-Entwicklung, strikter Schichtentrennung und Best-Practice-Entwurfsmustern.

Detaillierte technische Architektur- und Domänenmodell-Spezifikationen finden Sie in der [Architektur & Technisches Design](docs/Architecture.de.md).

---

## 2. Technologie-Stack

- **Plattform:** SAP BTP ABAP Environment
- **IDE:** Eclipse ADT (ABAP Development Tools)
- **Programmiermodell:** SAP RESTful Application Programming Model (RAP)
- **Datenmodellierung:** ABAP Core Data Services / CDS View Entities
- **Persistenz:** Transparent Tables mit RAP Draft-Unterstützung
- **Services:** OData V4 UI Services
- **UI-Framework:** SAP Fiori Elements
- **Entwicklungsstandard:** SAP Clean Core / ABAP Cloud

---

## 3. Implementierungsstatus und Roadmap

Das Projekt ist in zwei Hauptphasen unterteilt.

### Phase 1: Stammdatenverwaltung (Master Data Management) – Abgeschlossen
- **Company Code (Unternehmen):** Operative Organisationseinheiten mit Länder- und Währungseinstellungen (Manuelle Schlüsselvergabe).
- **Warehouse (Lager):** Physische Lagerorte, die einem Unternehmen zugeordnet sind (Automatische Schlüsselvergabe).
- **Business Partner (Geschäftspartner):** Kunden, Lieferanten oder kombinierte Partner (Automatische Schlüsselvergabe).
- **Item Group (Produktgruppen):** Produktklassifizierung mit Standard-MwSt.-Satz für automatische Vererbung (Automatische Schlüsselvergabe).
- **Item (Produkte):** Materielle Produkte und immaterielle Dienstleistungen (Automatische Schlüsselvergabe).
- **VAT Rate (MwSt.-Sätze):** Zentrale Engine für die Konfiguration und Pflege von Steuersätzen (Automatische Schlüsselvergabe).

### Phase 2: Transactional Engine & Inventory (Transaktions-Engine & Lagerhaltung) – In Arbeit
- **Purchase Orders (Bestellungen) – Abgeschlossen:** Vollständiger Beschaffungsbeleg-Lebenszyklus (Neu, Genehmigt, In Lieferung, Abgeschlossen, Storniert) mit unternehmensbezogener Belegnummerierung, automatisierter Berechnung von Positionssummen und Beleggesamtsummen, Duplikatprüfung von Belegzeilen sowie interaktiven Echtzeit-Validierungen.
- **Goods Receipts & Sales Engine:** Teilwareneingänge, Kundenaufträge und Warenausgänge.
- **Dynamic Stock Calculation (Dynamische Bestandsberechnung):** Echtzeit-Lagerbestandsberechnung (`Bestand = Wareneingänge - Warenausgänge`), die dynamisch über CDS View Entities ohne persistente Bestandstabellen berechnet wird.

---

## 4. Wichtigste Architekturmerkmale

### Hybride Nummernkreis-Engine (`ZCL_MERP_NUM_RANGE_UTIL`)
- **Primärschlüsselzuweisung:** Standard SAP Number Range Object (NRO) API über `cl_numberrange_runtime`.
- **DB Max Fallback:** Dynamischer Open-SQL-Fallback, der sowohl aktive Tabellen als auch Entwurfstabellen (`nmax`) scannt, um Schlüsselkollisionen während paralleler Benutzer-Draft-Sitzungen zu verhindern.
- **NRO-Synchronisation:** Automatische Intervallanpassung über `cl_numberrange_intervals` nach der Ausführung des Initial-Setups (Seed).

### Automatische Steuer- und Wertererbung (`ZCL_MERP_MD_UTIL`)
- **Hierarchische Ermittlung der MwSt.:** Der Artikel-Steuercode vererbt sich aus `Item Master` -> `Item Group Default` -> `Manual Fallback`.

### Relationale Integrität & Verwendungsprüfungen
- **Bulk-Precheck-Muster:** Implementiert in RAP Behavior Handlern (`precheck_delete`) über alle Stammdaten-BOs hinweg, um das Löschen verwendeter Entitäten zu verhindern.
- **Bulk-SQL-Optimierung:** Fragt dedizierte CDS Usage Views (`ZMERP_I_<ENTITY>_USAGE`) mit bereinigten Schlüsselsets ab, um den $N+1$-Abfrage-Overhead zu eliminieren.

### Operationales Status-Management
- **Soft Blocking:** Stammdatensätze verwenden ein `IsBlocked`-Flag, um die historische Datenintegrität anstelle von hartem Löschen zu wahren.
- **Value Help-Filterung:** Alle operativen Value Help Views (`ZMERP_I_<ENTITY>_VH`) erzwingen `WHERE IsBlocked = ''`, um die Auswahl inaktiver Datensätze in nachgelagerten Belegen zu verhindern.

### Automatisierte Berechnungen & Echtzeit-Validierung
- **Belegberechnungs-Engine:** Automatisierte, Echtzeit-Berechnung finanzieller Positionsbeträge bei Änderungen von Menge, Preis oder Steuersatz sowie sofortige Aggregation der Beleg-Gesamtsummen auf Kopfebene.
- **Interaktive Fehlerbehandlung:** Sofortiges Löschen und Hervorheben von Validierungsmeldungen direkt während der Benutzer Felder ausfüllt oder korrigiert, was eine reibungslose Benutzererfahrung gewährleistet.
- **Duplikatserkennung:** Automatische Erkennung und Blockierung doppelt erfasster Produkte innerhalb desselben Belegs.

### Automatisiertes Initial-Setup (`ZCL_MERP_INITIAL_SETUP`)
- Console-Runner-Klasse, die das Interface `IF_OO_ADT_CLASSRUN` implementiert.
- Füllt Testdaten über alle Stammdaten-Entitäten hinweg auf.
- Löscht während der Initialisierung sowohl aktive Tabellen als auch RAP-Draft-Tabellen.
- Synchronisiert automatisch die NRO-Sequenzstufen, um die generierten Datensätze widerzuspiegeln.

---

## 5. Service Binding & UI Preview

Der OData V4-Service `ZUI_MERP_O4` stellt alle Stammdaten-Entitäten für die Nutzung durch SAP Fiori Elements bereit.

---

## 6. Clean Core-Prinzipien

- **Strikter ABAP Cloud-Scope:** Keine Verwendung von veralteten ABAP-Anweisungen oder nicht freigegebenen SAP-Standard-APIs.
- **RAP Draft-Funktionen:** Integrierte Statusbehandlung für transaktionale, zustandslose HTTP-Kommunikation.
- **Automatisierte Auditierung:** Einheitliche Befüllung von Audit-Feldern (`CREATED_BY`, `CREATED_AT`, `LAST_CHANGED_AT`, etc.).

---

## 7. Einrichtung und Ausführung

1. Importieren Sie das Repository über **abapGit** in Eclipse ADT in Ihre SAP BTP ABAP-Umgebung.
2. Aktivieren Sie CDS View Entities, Behavior Definitions und Service Bindings in hierarchischer Reihenfolge.
3. Öffnen Sie das Service Binding `ZUI_MERP_O4` und klicken Sie auf **Publish** (oder **Unpublish / Publish**), um den lokalen OData V4-Endpunkt zu registrieren.
4. Führen Sie die Klasse `ZCL_MERP_INITIAL_SETUP` in Eclipse ADT (`F9`) aus, um die Initialdaten zu laden und die Nummernkreise zu synchronisieren.
5. Testen Sie die Anwendungen über die Fiori Elements-Vorschau im Service-Binding-Editor.

---

## 📄 Zugehörige Dokumentation
- 📘 [Architektur & Technisches Design](docs/Architecture.de.md)