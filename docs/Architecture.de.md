# Mini-ERP – Architektur & Technisches Design

[⬅ Zurück zu README.de.md](../README.de.md) | [English](Architecture.md) | [Deutsch](Architecture.de.md) | [Українська](Architecture.ua.md)

## 1. Domain Data Model (Domänen-Datenmodell)

Die Domänenarchitektur besteht aus 6 Master Data Business Objects (Stammdaten-Geschäftsobjekten) und 4 Transactional Document types (Transaktionsbelegtypen).

### Master Data Entities (Stammdaten-Entitäten)
- **Company Code / Buchungskreis (`ZMERP_COMP_CODE`):** Repräsentiert eine rechtliche Unternehmenseinheit, die für Geschäftstransaktionen verantwortlich ist. Definiert Firmenname, Land und Standardwährung.
- **Warehouse / Lager (`ZMERP_WAREHOUSE`):** Repräsentiert einen physischen Lagerort. Jedes Lager gehört zu genau einem Buchungskreis (Company Code).
- **Business Partner / Geschäftspartner (`ZMERP_BUS_PART`):** Repräsentiert externe Vertragspartner. Unterstützt die Rollen Kunde (Customer), Lieferant (Supplier) oder kombinierte Rollen. Wird über alle Buchungskreise (Company Codes) hinweg gemeinsam genutzt.
- **Item Group / Warengruppe (`ZMERP_ITEM_GROUP`):** Klassifiziert Artikel (Items) und enthält die Standard-MwSt.-Zuordnung für die automatische Ermittlung.
- **Item Master / Artikelstamm (`ZMERP_ITEM`):** Unterstützt physische Produkte (Products), die Lagerbewegungen auslösen, und immaterielle Dienstleistungen (Services) — nur für die kaufmännische Berechnung.
- **VAT Rate / Umsatzsteuersatz (`ZMERP_VAT_RATE`):** Definiert Steuersätze in Prozent, auf die von Warengruppen (Item Groups), Artikeln (Items) und Transaktionsbelegzeilen verwiesen wird.

---

## 2. Key Generation and Formatting Strategy (Schlüsselgenerierung und Formatierungsstrategie)

Das System verwendet standardisierte Präfixe, Formatierungen mit fester Länge und dedizierte Nummernkreisobjekte (Number Range Objects) über alle Entitäten hinweg:

| Entity (Entität) | Semantic Prefix (Semantisches Präfix) | Pattern Example (Musterbeispiel) | Key Generation Strategy (Schlüsselgenerierungsstrategie) |
|---|---|---|---|
| **Company Code** (Buchungskreis) | *Keines* | `1000` | Manual Input (Manuelle Eingabe) |
| **Warehouse** (Lager) | `WH` | `WH00001` | Early Numbering / Hybrides NRO + DB Max |
| **Business Partner** (Geschäftspartner) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max |
| **Item Group** (Warengruppe) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max |
| **Item Master** (Artikelstamm) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max |
| **VAT Rate** (Umsatzsteuersatz) | `V` | `V0001` | Early Numbering / Hybrides NRO + DB Max |

### Key Generation Logic Flow (Logikablauf der Schlüsselgenerierung)
1. Der Benutzer legt eine neue Entität an (löst RAP Early Numbering aus).
2. Das Utility versucht, die nächste Nummer aus dem SAP NRO (`cl_numberrange_runtime`) abzurufen.
3. Wenn das NRO nicht konfiguriert ist oder fehlschlägt, fragt die Fallback-Logik die Datenbank nach dem Maximalwert `MAX(code)` sowohl in den aktiven Tabellen (Active) als auch in den Entwurfstabellen (Draft) ab.
4. Die Nummer wird hochgezählt (inkrementiert) und mit führenden Nullen sowie dem vordefinierten semantischen Präfix formatiert.

---

## 3. Master Data Governance & Integrity Patterns (Stammdaten-Governance & Integritätsmuster)

Um die Datenkonsistenz zu gewährleisten, verwaiste Datensätze zu verhindern und den Lebenszyklus von Datensätzen unter ABAP Cloud zu steuern, verwendet die Stammdaten-Domäne zwei standardisierte Entwurfsmuster über alle Geschäftsobjekte hinweg:

### 3.1. Relationale Integrität über Bulk-Vorprüfungen (`precheck_delete`)
Bevor eine Stammdaten-Entität gelöscht wird, löst RAP die Operation `precheck_delete` in der entsprechenden Verhaltensimplementierungsklasse (z. B. `ZBP_MERP_R_COMPANY_CODE`) aus.

Um Leistungsengpässe beim Löschen mehrerer Datensätze zu vermeiden, verwendet die Prüfung ein Massenabfragemuster (Bulk Query Pattern):
- **Schlüssel-Deduplizierung:** Zielschlüssel aus der RAP-Tabelle `keys` werden gesammelt und dedupliziert (`DELETE ADJACENT DUPLICATES`).
- **Massen-SQL-Abhängigkeitsscan:** Eine einzelne `SELECT DISTINCT`-Abfrage wird gegen eine dedizierte CDS Usage View (z. B. `ZMERP_I_COMPANY_CODE_USAGE`) unter Verwendung eines internen Tabellen-JOINs (`INNER JOIN @lt_keys`) ausgeführt.
- **In-Memory-Abgleich:** Identifizierte Abhängigkeiten werden über eine binäre Suche (`LOOP AT ... WHERE`) im Speicher den einzelnen Datensätzen zugeordnet.
- **RAP Fail & Meldungsrückgabe:** Wenn Abhängigkeiten bestehen, wird der Datensatz mit `%fail-cause = if_abap_behv=>cause-dependency` markiert und eine benutzerfreundliche Fehlermeldung (`ZCM_MERP_MESSAGES`) an die UI zurückgegeben, was das Löschen verhindert.

### 3.2. Soft Blocking und Value Help-Governance
Um Stammdaten-Entitäten zu deaktivieren, ohne historische Transaktionsdaten zu beschädigen, implementieren alle 6 Entitäten ein `IsBlocked`-Feld (`ZMERP_IS_BLOCKED`):
- **Datenerhaltung:** Blockierte Entitäten verbleiben zur Überprüfbarkeit und Berichterstattung in der Datenbank.
- **Auswahlsperre:** Alle dedizierten Value Help CDS View Entities (z. B. `ZMERP_I_COMPANY_CODE_VH`, `ZMERP_I_VAT_RATE_VH`) erzwingen die explizite Bedingung `WHERE IsBlocked = ''`. Dies stellt sicher, dass blockierte Stammdatensätze nicht in neuen Transaktionsbelegen (Bestellungen, Kundenaufträge, Lagerbewegungen) ausgewählt werden können.

---

## 4. Transactional Document Architecture (Transaktionsbeleg-Architektur — Design Phase 2)

Transaktionsbelege folgen einer Kompositionsstruktur von Kopf (1) zu Positionen (N) (Header to Line Items):
- **Procurement Chain (Beschaffungskette):** Purchase Order (Bestellung) -> Goods Receipt (Wareneingang)
- **Sales Chain (Vertriebskette):** Sales Order (Kundenauftrag) -> Goods Issue (Warenausgang)

### Document Status Lifecycle (Belegstatus-Lebenszyklus)
- **Open (Offen):** Aktiver Entwurf oder offener Beleg, bearbeitbar.
- **Posted (Gebucht):** Schreibgeschützt (Read-only). Beeinflusst die Bestandsberechnungen und dient als Quelle für Folgebelege.
- **Cancelled (Storniert):** Schreibgeschützt (Read-only). Von den Bestandsberechnungen ausgeschlossen.

---

## 5. Dynamic Inventory Calculation Concept (Konzept der dynamischen Bestandsberechnung)

Lagerbestände werden nicht statisch in persistenten Tabellen gespeichert. Die aktuellen Bestände werden in Echtzeit dynamisch aus den gebuchten Lagerbewegungsbelegen berechnet:

`Aktueller Bestand = Summe(Gebuchte Wareneingänge) - Summe(Gebuchte Warenausgänge)`

### Rules (Regeln):
- Die Nachverfolgung erfolgt pro Buchungskreis (Company Code) + Lager (Warehouse) + Artikel (Item).
- Schließt Artikel aus, bei denen der Artikeltyp (Item Type) = Dienstleistung (`S` / Service) ist.
- Fehler wegen unzureichenden Bestands werden während des Übergangs von Warenausgangsbelegen (Goods Issue) in den Status Gebucht (Posted) über RAP-Validierungen beim Speichern (Validations on Save) erzwungen.