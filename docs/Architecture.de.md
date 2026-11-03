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
| **Warehouse** (Lager) | `WH` | `WH001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **Business Partner** (Geschäftspartner) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **Item Group** (Warengruppe) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **Item Master** (Artikelstamm) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **VAT Rate** (Umsatzsteuersatz) | `V` | `V001` | Early Numbering / Hybrides NRO + DB Max | Umgesetzt |
| **Purchase Order** (Bestellung) | *Unternehmenspräfix* | `DE00000001` | On-Save Numbering (Late) / Unternehmensbezogenes NRO | Umgesetzt |
| **Goods Receipt** (Wareneingang) | *Unternehmenspräfix* | `DE00000001` | On-Save Numbering (Late) / Unternehmensbezogenes NRO | Umgesetzt |

---

## 3. Master Data Governance & Integrity Patterns (Stammdaten-Governance & Integritätsmuster)

Um die Datenkonsistenz zu gewährleisten, verwaiste Datensätze zu verhindern und den Lebenszyklus von Datensätzen unter ABAP Cloud zu steuern, verwendet die Stammdaten-Domäne zwei standardisierte Entwurfsmuster:

### 3.1. Relationale Integrität über Bulk-Vorprüfungen (`precheck_delete`)
Bevor eine Stammdaten-Entität gelöscht wird, löst RAP die Operation `precheck_delete` in der entsprechenden Verhaltensimplementierungsklasse aus (z. B. `ZBP_MERP_R_COMPANY_CODE`).

Um Leistungsengpässe beim Löschen mehrerer Datensätze zu vermeiden, verwendet die Prüfung ein Massenabfragemuster:
- **Schlüssel-Deduplizierung:** Zielschlüssel aus der RAP-Tabelle `keys` werden gesammelt und dedupliziert (`DELETE ADJACENT DUPLICATES`).
- **Massen-SQL-Abhängigkeitsscan:** Eine einzelne `SELECT DISTINCT`-Abfrage wird gegen eine dedizierte CDS Usage View (z. B. `ZMERP_I_COMPANY_CODE_USAGE`) unter Verwendung eines internen Tabellen-JOINs (`INNER JOIN @lt_keys`) ausgeführt.
- **In-Memory-Abgleich:** Identifizierte Abhängigkeiten werden über eine binäre Suche (`LOOP AT ... WHERE`) im Speicher zugeordnet.
- **RAP Fail & Meldungsrückgabe:** Wenn Abhängigkeiten bestehen, wird der Datensatz mit `%fail-cause = if_abap_behv=>cause-dependency` markiert und eine benutzerfreundliche Fehlermeldung (`ZCM_MERP_MESSAGES`) an die UI zurückgegeben.

### 3.2. Soft Blocking und Value Help-Governance
Um Stammdaten-Entitäten zu deaktivieren, ohne historische Transaktionsdaten zu beschädigen, implementieren alle 6 Entitäten ein `IsBlocked`-Feld (`ZMERP_IS_BLOCKED`):
- **Datenerhaltung:** Blockierte Entitäten verbleiben zur Überprüfbarkeit und Berichterstattung in der Datenbank.
- **Auswahlsperre:** Alle dedizierten Value Help CDS View Entities erzwingen die explizite Bedingung `WHERE IsBlocked = ''`, um die Auswahl inaktiver Datensätze in neuen Belegen zu verhindern.

---

## 4. Transactional Document Architecture (Transaktionsbeleg-Architektur)

Der Bereich der Transaktionsbelege gliedert sich in Beschaffungs- und Vertriebsketten:

### Procurement (Beschaffungskette)
- **Purchase Order (`ZMERP_R_PURCHASEORDER`) — Umgesetzt:** Kompositionsstruktur von Kopf zu Positionen zur Erstellung und Genehmigung von Bestellungen.
- **Goods Receipt (`ZMERP_R_GOODSRECEIPT`) — Umgesetzt:** Belegtyp zur Erfassung physischer Wareneingänge zu Bestellungen, zur Aktualisierung des Bestellfortschritts und zur Auslösung von Lagerbewegungen.

### Sales (Vertriebskette)
- **Sales Order (Kundenauftrag) — Geplant:** Künftiger Belegtyp zur Verwaltung von Kundenaufträgen.
- **Goods Issue (Warenausgang) — Geplant:** Künftiger Belegtyp zur Erfassung physischer Warenausgangslieferungen.

### 4.1. Purchase Order Funktionale Architektur (Umgesetzt)

#### Unternehmensbezogene sequentielle Nummerierung (Late Numbering on Save)
- **Kontextsensitive NRO-Zuweisung:** Belegnummern (`DocumentNumber`) werden strikt beim ersten Speichern (`assignDocumentNumber`) über Nummernkreisobjekte generiert, die auf den spezifischen Buchungskreis (`CompanyCode`) zugeschnitten sind, wobei das Firmenpräfix für eine eindeutige Unternehmensidentifikation integriert wird (z. B. `DE00000001`). Entwürfe besitzen keine permanente Belegnummer.

#### Belegberechnungs-Engine (`ZCL_MERP_DOC_CALC`)
- **Positionsspezifische Berechnungen:** Das Ändern von Menge (`Quantity`), Preis (`Price`) oder Steuersatz (`VatCode`) löst automatisierte Neuberechnungen der finanziellen Positionsbeträge (`NetAmount`, `VatAmount`, `GrossAmount`) basierend auf aktiven Steuersätzen aus.
- **Kopf-Aggregation (Header Totals Aggregation):** Positionsänderungen fließen sofort in die automatisierte Aggregation der Beleg-Gesamtsummen (`TotalNetAmount`, `TotalGrossAmount`) über aktive und Entwurfs-Instanzen hinweg ein.

#### Validierung & Meldungsverarbeitung
- **Echtzeit-UI-Fehlerbereinigung:** Zustandsbereichsbasierte Handler löschen feldspezifische Validierungsmeldungen sofort nach deren Korrektur.
- **Duplikatvalidierung für Belegzeilen:** Die In-Memory-Kontextauswertung verhindert doppelte `ItemCode`-Einträge in separaten Zeilen desselben Belegs.
- **Übergreifende & Datumsregeln:** Erzwingt organisatorische Konsistenz (Lagerzuordnung zum Buchungskreis, Lieferantenrollenprüfung) und chronologische Datumsregeln.

### 4.2. Purchase Order Status Lifecycle
- **New / Neu (`N`):** Bearbeitbarer Entwurf oder neu gespeicherter Beleg.
- **Approved / Genehmigt (`A`):** Freigegebener Beleg über die Aktion `releaseDocument` (erfordert mindestens 1 Belegzeile).
- **In Delivery / In Lieferung (`P`):** Lieferung gestartet oder teilweise eingetroffen.
- **Completed / Abgeschlossen (`C`):** Abgeschlossener Beleg (alle Mengen eingetroffen).
- **Cancelled / Storniert (`X`):** Beendeter Beleg über die Aktion `cancelDocument`; von nachgelagerten Berechnungen ausgeschlossen.

### 4.3. Goods Receipt Funktionale Architektur (Umgesetzt)

#### Bestellreferenz & Positionsableitung
- **Auswahl & Übernahme:** Das Auswählen einer Bestellung leitet automatisch Kopfdaten (Buchungskreis, Lager, Partner, Währung) ab und befüllt Belegpositionen basierend auf offenen Mengen (`ZMERP_I_PO_PROGRESS`).
- **Flexible Erfassung:** Unterstützt sowohl Referenz-Bestellpositionen (mit Mengenanpassungen und automatischer Betragsberechnung) als auch manuelle Zusatzpositionen.

#### Bestandsbuchung & Zusätzliches Speichern (`with additional save`)
- **Schreibung von Lagerbewegungen:** Das Buchen eines Wareneingangs (Aktion `Post`) führt Journalbuchungen für Bestandsbewegungen (`ZMERP_STOCK_MOV`) über die Persistenz des zusätzlichen Speicherungs-Schritts aus.
- **Status- & Fortschrittsintegration:** Aktualisiert automatisch den Wareneingangsstatus der angeforderten Bestellung (über die Aktion `setReceiptStatus`) und berechnet die offenen Artikelmengen neu.
- **Stornierung & Rückbuchung:** Unterstützt `Unpost` (setzt den Beleg auf „Neu“ zurück und macht Lagerbewegungen mit Schutz vor negativen Beständen rückgängig) sowie die Aktion `Cancel`.

### 4.4. Goods Receipt Status Lifecycle (Wareneingangs-Lebenszyklus — Umgesetzt)
- **New / Neu (`N`):** Bearbeitbarer Beleg vor der Bestandsbuchung. Beeinflusst keine Bestandssalden.
- **Posted / Gebucht (`P`):** Ausgeführter Wareneingangsbeleg über die Aktion `Post`. Schreibt Bestandsbewegungen nach `ZMERP_STOCK_MOV`, aktualisiert den Status der referenzierten Bestellung und sperrt Kopf/Positionen vor direkter Bearbeitung.
- **Cancelled / Storniert (`X`):** Beendeter Beleg über die Aktion `Cancel` (nur aus dem Status `N` zulässig). Gebuchte Belege müssen vor der Stornierung erst rückgebucht (`Unpost`) werden.

---

## 5. Inventory & Stock Management Architecture (Bestandsführung — Umgesetzt)

Bestandssalden und Bewertungen werden dynamisch über ein Bewegungsjournal und Aggregations-Views verwaltet:

### Stock Movement Journal (`ZMERP_STOCK_MOV`)
- Erfasst eingehende Bewegungen für gebuchte Produktpositionen mit Buchungskreis, Lager, Artikel, Menge, Einheiten, Bewertung in Buchungskreiswährung und Buchungsdatum.
- Schließt immaterielle Dienstleistungen aus (Artikeltyp `S`).

### Stock Balances (`ZMERP_R_STOCK_BALANCE`)
- **Echtzeit-Aggregation:** Aggregiert Mengen und Bewertungsbeträge aus allen gebuchten Bewegungen pro Buchungskreis, Lager, Artikel und Einheit.
- **OData UI-Bereitstellung:** Über das schreibgeschützte OData V4 Service Binding `ZUI_MERP_STOCK_O4` für Saldenlisten und Detaillisten der Bewegungshistorie bereitgestellt.