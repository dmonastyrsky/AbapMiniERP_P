# Mini-ERP – Architektur & Technisches Design

[⬅ Zurück zu README.de.md](../README.de.md) | [English](Architecture.md) | [Deutsch](Architecture.de.md) | [Українська](Architecture.ua.md)

## 1. Domain Data Model (Domänen-Datenmodell)

Die Domänenarchitektur ist für 6 Master Data Business Objects und 4 Transactional Document types ausgelegt.

### Master Data Entities (Stammdaten-Entitäten — Umgesetzt)
- **Company Code / Buchungskreis (`ZMERP_COMP_CODE`):** Repräsentiert eine rechtliche Unternehmenseinheit, die für Geschäftstransaktionen verantwortlich ist. Definiert Firmenname, Land und Standardwährung.
- **Warehouse / Lager (`ZMERP_WAREHOUSE`):** Repräsentiert einen physischen Lagerort. Jedes Lager gehört zu genau einem Buchungskreis.
- **Business Partner / Geschäftspartner (`ZMERP_BUS_PART`):** Repräsentiert externe Vertragspartner. Unterstützt Kunde, Lieferant oder kombinierte Rollen. Wird über alle Buchungskreise hinweg gemeinsam genutzt.
- **Item Group / Warengruppe (`ZMERP_ITEM_GROUP`):** Klassifiziert Artikel und enthält die Standard-MwSt.-Zuordnung für die automatische Ermittlung.
- **Item Master / Artikelstamm (`ZMERP_ITEM`):** Unterstützt physische Produkte (Lagerbewegungen) und immaterielle Dienstleistungen (nur kaufmännische Berechnung).
- **VAT Rate / Umsatzsteuersatz (`ZMERP_VAT_RATE`):** Definiert Steuersätze in Prozent, auf die von Warengruppen, Artikeln und Transaktionsbelegzeilen verwiesen wird.

---

## 2. Key Generation and Formatting Strategy (Schlüsselgenerierung und Formatierungsstrategie)

Das System verwendet standardisierte Präfixe, Formatierungen mit fester Länge und dedizierte Nummernkreisobjekte über alle Entitäten hinweg:

| Entity (Entität) | Semantic Prefix (Semantisches Präfix) | Pattern Example (Musterbeispiel) | Key Generation Strategy (Schlüsselgenerierungsstrategie) | Status |
|---|---|---|---|---|
| **Company Code** (Buchungskreis) | *Keines* | `1000` | Manual Input (Manuelle Eingabe) | Umgesetzt |
| **Warehouse** (Lager) | `WH` | `WH00001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **Business Partner** (Geschäftspartner) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **Item Group** (Warengruppe) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **Item Master** (Artikelstamm) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **VAT Rate** (Umsatzsteuersatz) | `V` | `V0001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **Purchase Order** (Bestellung) | *Unternehmenspräfix* | `1000000001` | Early-/On-Save-Nummerierung / Unternehmensbezogenes NRO | Umgesetzt |

---

## 3. Master Data Governance & Integrity Patterns (Stammdaten-Governance & Integritätsmuster)

Um die Datenkonsistenz zu gewährleisten, verwaiste Datensätze zu verhindern und den Lebenszyklus von Datensätzen unter ABAP Cloud zu steuern, verwendet die Stammdaten-Domäne zwei standardisierte Entwurfsmuster:

### 3.1. Relationale Integrität über Bulk-Vorprüfungen (`precheck_delete`)
Bevor eine Stammdaten-Entität gelöscht wird, löst RAP die Operation `precheck_delete` in der entsprechenden Verhaltensimplementierungsklasse aus.

Um Leistungsengpässe beim Löschen mehrerer Datensätze zu vermeiden, verwendet die Prüfung ein Massenabfragemuster:
- **Schlüssel-Deduplizierung:** Zielschlüssel aus der RAP-Tabelle `keys` werden gesammelt und dedupliziert (`DELETE ADJACENT DUPLICATES`).
- **Massen-SQL-Abhängigkeitsscan:** Eine einzelne `SELECT DISTINCT`-Abfrage wird gegen eine dedizierte CDS Usage View unter Verwendung eines internen Tabellen-JOINs (`INNER JOIN @lt_keys`) ausgeführt.
- **In-Memory-Abgleich:** Identifizierte Abhängigkeiten werden über eine binäre Suche (`LOOP AT ... WHERE`) im Speicher zugeordnet.
- **RAP Fail & Meldungsrückgabe:** Wenn Abhängigkeiten bestehen, wird der Datensatz mit `%fail-cause = if_abap_behv=>cause-dependency` markiert und eine benutzerfreundliche Fehlermeldung an die UI zurückgegeben.

### 3.2. Soft Blocking und Value Help-Governance
Um Stammdaten-Entitäten zu deaktivieren, ohne historische Transaktionsdaten zu beschädigen, implementieren alle 6 Entitäten ein `IsBlocked`-Feld:
- **Datenerhaltung:** Blockierte Entitäten verbleiben zur Überprüfbarkeit und Berichterstattung in der Datenbank.
- **Auswahlsperre:** Alle dedizierten Value Help CDS View Entities erzwingen die explizite Bedingung `WHERE IsBlocked = ''`, um die Auswahl inaktiver Datensätze in neuen Belegen zu verhindern.

---

## 4. Transactional Document Architecture (Transaktionsbeleg-Architektur)

Der Bereich der Transaktionsbelege gliedert sich in Beschaffungs- und Vertriebsketten:

### Procurement (Beschaffungskette)
- **Purchase Order (`ZMERP_R_PURCHASEORDER`) — Umgesetzt:** Kompositionsstruktur von Kopf zu Positionen zur Erstellung und Genehmigung von Bestellungen.
- **Goods Receipt (Wareneingang) — Geplant:** Künftiger Belegtyp zur Erfassung physischer Wareneingänge zu Bestellungen.

### Sales (Vertriebskette)
- **Sales Order (Kundenauftrag) — Geplant:** Künftiger Belegtyp zur Verwaltung von Kundenaufträgen.
- **Goods Issue (Warenausgang) — Geplant:** Künftiger Belegtyp zur Erfassung physischer Warenausgangslieferungen.

### 4.1. Purchase Order Funktionale Architektur (Umgesetzt)

#### Unternehmensbezogene sequentielle Nummerierung (Company-Scoped Numbering)
- **Kontextsensitive NRO-Zuweisung:** Belegnummern (`DocumentNumber`) werden beim Speichern über Nummernkreisobjekte generiert, die auf den spezifischen Buchungskreis (`CompanyCode`) zugeschnitten sind, wobei das Firmenpräfix für eine eindeutige Unternehmensidentifikation integriert wird.

#### Belegberechnungs-Engine (`ZCL_MERP_DOC_CALC`)
- **Positionsspezifische Berechnungen:** Das Ändern von Menge (`Quantity`), Preis (`Price`) oder Steuersatz (`VatCode`) löst automatisierte Neuberechnungen der finanziellen Positionsbeträge (`NetAmount`, `VatAmount`, `GrossAmount`) basierend auf aktiven Steuersätzen aus.
- **Kopf-Aggregation (Header Totals Aggregation):** Positionsänderungen fließen sofort in die automatisierte Aggregation der Beleg-Gesamtsummen (`TotalNetAmount`, `TotalGrossAmount`) über aktive und Entwurfs-Instanzen hinweg ein.

#### Validierung & Meldungsverarbeitung
- **Echtzeit-UI-Fehlerbereinigung:** Zustandsbereichsbasierte Handler löschen feldspezifische Validierungsmeldungen sofort nach deren Korrektur.
- **Duplikatvalidierung für Belegzeilen:** Die In-Memory-Kontextauswertung verhindert doppelte `ItemCode`-Einträge in separaten Zeilen desselben Belegs.
- **Übergreifende & Datumsregeln:** Erzwingt organisatorische Konsistency (Lagerzuordnung zum Buchungskreis, Lieferantenrollenprüfung) und chronologische Datumsregeln.

### 4.2. Purchase Order Status Lifecycle
- **New / Neu (`N`):** Bearbeitbarer Entwurf oder neu gespeicherter Beleg.
- **Approved / Genehmigt (`A`):** Freigegebener Beleg über die Aktion `releaseDocument` (erfordert mindestens 1 Belegzeile).
- **In Delivery / In Lieferung (`P`) / Completed / Abgeschlossen (`C`):** Logistische Ausführungsphasen (werden künftig durch Wareneingänge aktualisiert).
- **Cancelled / Storniert (`X`):** Beendeter Beleg über die Aktion `cancelDocument`; von nachgelagerten Berechnungen ausgeschlossen.

---

## 5. Dynamic Inventory Calculation Concept (Konzept der dynamischen Bestandsberechnung — Zielbild)

Lagerbestände werden in Echtzeit dynamisch aus gebuchten Lagerbewegungsbelegen berechnet, sobald die vollständige Transaktionssuite umgesetzt ist:

`Aktueller Bestand = Summe(Gebuchte Wareneingänge) - Summe(Gebuchte Warenausgänge)`

*Hinweis: Dieses Konzept ist für die Implementierung zusammen mit den Modulen Wareneingang (Goods Receipt) und Warenausgang (Goods Issue) in folgenden Phasen geplant.*