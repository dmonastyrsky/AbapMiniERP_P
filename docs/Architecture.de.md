# Mini-ERP – Architektur & Technisches Design[cite: 9]

[⬅ Zurück zu README.de.md](../README.de.md) | [English](Architecture.md) | [Deutsch](Architecture.de.md) | [Українська](Architecture.ua.md)[cite: 9]

## 1. Domain Data Model (Domänen-Datenmodell)[cite: 9]

Die Domänenarchitektur besteht aus 6 Master Data Business Objects und 4 Transactional Document types.[cite: 9]

### Master Data Entities (Stammdaten-Entitäten)[cite: 9]
- **Company Code / Buchungskreis (`ZMERP_COMP_CODE`):** Repräsentiert eine rechtliche Unternehmenseinheit, die für Geschäftstransaktionen verantwortlich ist. Definiert Firmenname, Land und Standardwährung.[cite: 9]
- **Warehouse / Lager (`ZMERP_WAREHOUSE`):** Repräsentiert einen physischen Lagerort. Jedes Lager gehört zu genau einem Buchungskreis.[cite: 9]
- **Business Partner / Geschäftspartner (`ZMERP_BUS_PART`):** Repräsentiert externe Vertragspartner. Unterstützt Kunde, Lieferant oder kombinierte Rollen. Wird über alle Buchungskreise hinweg gemeinsam genutzt.[cite: 9]
- **Item Group / Warengruppe (`ZMERP_ITEM_GROUP`):** Klassifiziert Artikel und enthält die Standard-MwSt.-Zuordnung für die automatische Ermittlung.[cite: 9]
- **Item Master / Artikelstamm (`ZMERP_ITEM`):** Unterstützt physische Produkte (Lagerbewegungen) und immaterielle Dienstleistungen (nur kaufmännische Berechnung).[cite: 9]
- **VAT Rate / Umsatzsteuersatz (`ZMERP_VAT_RATE`):** Definiert Steuersätze in Prozent, auf die von Warengruppen, Artikeln und Transaktionsbelegzeilen verwiesen wird.[cite: 9]

---

## 2. Key Generation and Formatting Strategy (Schlüsselgenerierung und Formatierungsstrategie)[cite: 9]

Das System verwendet standardisierte Präfixe, Formatierungen mit fester Länge und dedizierte Nummernkreisobjekte über alle Entitäten hinweg:[cite: 9]

| Entity (Entität) | Semantic Prefix (Semantisches Präfix) | Pattern Example (Musterbeispiel) | Key Generation Strategy (Schlüsselgenerierungsstrategie) |
|---|---|---|---|
| **Company Code** (Buchungskreis) | *Keines* | `1000` | Manual Input (Manuelle Eingabe)[cite: 9] |
| **Warehouse** (Lager) | `WH` | `WH00001` | Early Numbering / Hybrides NRO + DB Max[cite: 9] |
| **Business Partner** (Geschäftspartner) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max[cite: 9] |
| **Item Group** (Warengruppe) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max[cite: 9] |
| **Item Master** (Artikelstamm) | *Keines* | `00001` | Early Numbering / Hybrides NRO + DB Max[cite: 9] |
| **VAT Rate** (Umsatzsteuersatz) | `V` | `V0001` | Early Numbering / Hybrides NRO + DB Max[cite: 9] |
| **Purchase Order** (Bestellung) | *Unternehmenspräfix* | `1000000001` | Early-/On-Save-Nummerierung / Unternehmensbezogenes NRO |

### Key Generation Logic Flow (Logikablauf der Schlüsselgenerierung)[cite: 9]
1. Der Benutzer legt eine neue Entität an (löst RAP Early Numbering aus).[cite: 9]
2. Das Utility versucht, die nächste Nummer aus dem SAP NRO (`cl_numberrange_runtime`) abzurufen.[cite: 9]
3. Wenn das NRO nicht konfiguriert ist oder fehlschlägt, fragt die Fallback-Logik die Datenbank nach dem Maximalwert `MAX(code)` in aktiven Tabellen und Entwurfstabellen ab.[cite: 9]
4. Die Nummer wird hochgezählt und mit führenden Nullen sowie dem vordefinierten semantischen Präfix formatiert.[cite: 9]

---

## 3. Master Data Governance & Integrity Patterns (Stammdaten-Governance & Integritätsmuster)[cite: 9]

Um die Datenkonsistenz zu gewährleisten, verwaiste Datensätze zu verhindern und den Lebenszyklus von Datensätzen unter ABAP Cloud zu steuern, verwendet die Stammdaten-Domäne zwei standardisierte Entwurfsmuster:[cite: 9]

### 3.1. Relationale Integrität über Bulk-Vorprüfungen (`precheck_delete`)[cite: 9]
Bevor eine Stammdaten-Entität gelöscht wird, löst RAP die Operation `precheck_delete` in der entsprechenden Verhaltensimplementierungsklasse aus.[cite: 9]

Um Leistungsengpässe beim Löschen mehrerer Datensätze zu vermeiden, verwendet die Prüfung ein Massenabfragemuster:[cite: 9]
- **Schlüssel-Deduplizierung:** Zielschlüssel aus der RAP-Tabelle `keys` werden gesammelt und dedupliziert (`DELETE ADJACENT DUPLICATES`).[cite: 9]
- **Massen-SQL-Abhängigkeitsscan:** Eine einzelne `SELECT DISTINCT`-Abfrage wird gegen eine dedizierte CDS Usage View unter Verwendung eines internen Tabellen-JOINs (`INNER JOIN @lt_keys`) ausgeführt.[cite: 9]
- **In-Memory-Abgleich:** Identifizierte Abhängigkeiten werden über eine binäre Suche (`LOOP AT ... WHERE`) im Speicher zugeordnet.[cite: 9]
- **RAP Fail & Meldungsrückgabe:** Wenn Abhängigkeiten bestehen, wird der Datensatz mit `%fail-cause = if_abap_behv=>cause-dependency` markiert und eine benutzerfreundliche Fehlermeldung an die UI zurückgegeben.[cite: 9]

### 3.2. Soft Blocking und Value Help-Governance[cite: 9]
Um Stammdaten-Entitäten zu deaktivieren, ohne historische Transaktionsdaten zu beschädigen, implementieren alle 6 Entitäten ein `IsBlocked`-Feld:[cite: 9]
- **Datenerhaltung:** Blockierte Entitäten verbleiben zur Überprüfbarkeit und Berichterstattung in der Datenbank.[cite: 9]
- **Auswahlsperre:** Alle dedizierten Value Help CDS View Entities erzwingen die explizite Bedingung `WHERE IsBlocked = ''`, um die Auswahl inaktiver Datensätze in neuen Belegen zu verhindern.[cite: 9]

---

## 4. Transactional Document Architecture (Transaktionsbeleg-Architektur – Phase 2)[cite: 8, 9]

Transaktionsbelege folgen einer Kompositionsstruktur von Kopf (1) zu Positionen (N):[cite: 9]
- **Procurement Chain (Beschaffungskette):** Purchase Order (`ZMERP_R_PURCHASEORDER`) -> Goods Receipt[cite: 8, 9]
- **Sales Chain (Vertriebskette):** Sales Order -> Goods Issue[cite: 9]

### 4.1. Purchase Order Funktionale Architektur

#### Unternehmensbezogene sequentielle Nummerierung (Company-Scoped Numbering)
- **Kontextsensitive NRO-Zuweisung:** Belegnummern (`DocumentNumber`) werden beim Speichern über Nummernkreisobjekte generiert, die auf den spezifischen Buchungskreis (`CompanyCode`) zugeschnitten sind, wobei das Firmenpräfix für eine eindeutige Unternehmensidentifikation integriert wird.[cite: 8]

#### Belegberechnungs-Engine (`ZCL_MERP_DOC_CALC`)
- **Positionsspezifische Berechnungen:** Das Ändern von Menge (`Quantity`), Preis (`Price`) oder Steuersatz (`VatCode`) löst automatisierte Neuberechnungen der finanziellen Positionsbeträge (`NetAmount`, `VatAmount`, `GrossAmount`) basierend auf aktiven Steuersätzen aus.[cite: 8]
- **Kopf-Aggregation (Header Totals Aggregation):** Positionsänderungen fließen sofort in die automatisierte Aggregation der Beleg-Gesamtsummen (`TotalNetAmount`, `TotalGrossAmount`) über aktive und Entwurfs-Instanzen hinweg ein.[cite: 8]

#### Validierung & Meldungsverarbeitung
- **Echtzeit-UI-Fehlerbereinigung:** Zustandsbereichsbasierte Handler löschen feldspezifische Validierungsmeldungen sofort nach deren Korrektur.
- **Duplikatvalidierung für Belegzeilen:** Die In-Memory-Kontextauswertung verhindert doppelte `ItemCode`-Einträge in separaten Zeilen desselben Belegs.[cite: 8]
- **Übergreifende & Datumsregeln:** Erzwingt organisatorische Konsistenz (Lagerzuordnung zum Buchungskreis, Lieferantenrollenprüfung) und chronologische Datumsregeln.[cite: 8]

### 4.2. Document Status Lifecycle (Belegstatus-Lebenszyklus)[cite: 9]
- **New / Neu (`N`):** Bearbeitbarer Entwurf oder neu gespeicherter Beleg.[cite: 9]
- **Approved / Genehmigt (`A`):** Freigegebener Beleg über die Aktion `releaseDocument` (erfordert mindestens 1 Belegzeile).[cite: 9]
- **In Delivery / In Lieferung (`P`) / Completed / Abgeschlossen (`C`):** Logistische Ausführungsphasen.[cite: 9]
- **Cancelled / Storniert (`X`):** Beendeter Beleg über die Aktion `cancelDocument`; von nachgelagerten Berechnungen ausgeschlossen.[cite: 9]

---

## 5. Dynamic Inventory Calculation Concept (Konzept der dynamischen Bestandsberechnung)[cite: 9]

Lagerbestände werden nicht statisch in persistenten Tabellen gespeichert. Die aktuellen Bestände werden in Echtzeit dynamisch aus den gebuchten Lagerbewegungsbelegen berechnet:[cite: 9]

`Aktueller Bestand = Summe(Gebuchte Wareneingänge) - Summe(Gebuchte Warenausgänge)`[cite: 9]

### Rules (Regeln):[cite: 9]
- Die Nachverfolgung erfolgt pro Buchungskreis + Lager + Artikel.[cite: 9]
- Schließt Artikel aus, bei denen der Artikeltyp = Dienstleistung (`S`) ist.[cite: 9]
- Fehler wegen unzureichenden Bestands werden während des Übergangs von Warenausgangsbelegen in den Status Gebucht über RAP-Validierungen beim Speichern erzwungen.[cite: 9]