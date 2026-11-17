# Mini-ERP – Architektur & Technisches Design

[⬅ Zurück zu README.de.md](../README.de.md) | [English](Architecture.md) | [Deutsch](Architecture.de.md) | [Українська](Architecture.ua.md)

## 1. Domänenmodell

6 Stammdatenobjekte, 5 Belegarten (jeweils Kopf + Positionen) und ein Bestandsjournal.

### 1.1 Stammdaten

| Objekt (Tabelle) | Schlüssel | Wichtige Felder | Schreibgeschützt nach Verwendung in Belegen |
|---|---|---|---|
| Buchungskreis (`ZMERP_COMP_CODE`) | `1000`, manuell | Name, Präfix (2 Buchstaben, eindeutig), Währung, Land | Präfix, Währung |
| Lager (`ZMERP_WAREHOUSE`) | `WH001` | Name, Buchungskreis | Buchungskreis |
| Geschäftspartner (`ZMERP_BUS_PART`) | `00001` | Name, Rolle Kunde / Lieferant (mindestens eine), Steuernummer, Adresse, Kontakt | eine verwendete Rolle |
| Warengruppe (`ZMERP_ITEM_GROUP`) | `00001` | Beschreibung, Standard-MwSt.-Kennzeichen | — |
| Artikel (`ZMERP_ITEM`) | `00001` | Beschreibung, Artikelnummer, Typ (P Produkt / S Dienstleistung), Warengruppe, Standard-MwSt.-Kennzeichen, Basismengeneinheit | Typ, Basismengeneinheit |
| MwSt.-Satz (`ZMERP_VAT_RATE`) | `V001` (als Text angezeigt) | Beschreibung, Prozentsatz 0–100 | Prozentsatz |

- Jedes Objekt hat ein Sperrkennzeichen. Geschäftspartner gelten buchungskreisübergreifend; ein Lager gehört zu genau einem Buchungskreis.
- Die Warengruppe schlägt das MwSt.-Kennzeichen des Artikels vor; Belege übernehmen Einheit und MwSt. vom Artikel.
- Die Buchungskreiswährung ist Bewertungswährung des Bestands und die einzige in Belegen erlaubte Währung.

### 1.2 Belege

| Beleg | Tabellen | Root View | Status |
|---|---|---|---|
| Bestellung | `ZMERP_PO_HDR` / `_ITM` | `ZMERP_R_PURCHASEORDER` | Neu, Genehmigt, In Lieferung, Abgeschlossen, Storniert |
| Wareneingang | `ZMERP_GR_HDR` / `_ITM` | `ZMERP_R_GOODSRECEIPT` | Neu, Gebucht, Storniert |
| Kundenauftrag | `ZMERP_SO_HDR` / `_ITM` | `ZMERP_R_SALESORDER` | Offen, In Bearbeitung, Abgeschlossen, Abgelehnt |
| Warenausgang | `ZMERP_GI_HDR` / `_ITM` | `ZMERP_R_GOODSISSUE` | Neu, Gebucht, Storniert |
| Umlagerung | `ZMERP_ST_HDR` / `_ITM` | `ZMERP_R_STOCKTRANSFER` | Neu, Gebucht, Storniert |

Die Belegstrukturen sind in einen Basisteil und einen kaufmännischen Teil aufgeteilt:
- **Basis, in jedem Beleg:** Kopf Nummer, Status, Belegdatum, Buchungsdatum, Buchungskreis, Lager, Verantwortlicher, Bemerkungen; Position Positionsnummer (10, 20, …), Artikel, Menge, Einheit, Lager.
- **Kaufmännisch, nur in Bestellung, Wareneingang, Kundenauftrag und Warenausgang:** Kopf Partner, Währung, Netto- und Bruttosumme; Position Preis, MwSt.-Kennzeichen, Netto- / MwSt.- / Bruttobetrag, Währung.
- **Eigene Felder:** Lieferanten- / Kundenreferenz, Lieferdatum der Bestellung, Auftragsbezug in Wareneingang / Warenausgang (Kopf und Position), empfangendes Lager in der Umlagerung (Kopf und Position).
- Das Lager der Position ist eine schreibgeschützte Kopie des Kopflagers (wie der Lagerort einer SAP-Position). Bestandssperren, Verfügbarkeit, Bewegungen und die Spalte „Bestand“ verwenden es.

---

## 2. Nummernvergabe

| Objekt | Beispiel | Verfahren |
|---|---|---|
| Buchungskreis | `1000` | manuell |
| Lager | `WH001` | Nummernkreis beim Anlegen (`ZNR_WHSE`) |
| Geschäftspartner, Warengruppe, Artikel | `00001` | Nummernkreis beim Anlegen (`ZNR_BP`, `ZNR_IG`, `ZNR_ITEM`) |
| MwSt.-Satz | `V001` | Nummernkreis beim Anlegen (`ZNR_VAT`) |
| Bestellung, Wareneingang, Kundenauftrag, Warenausgang, Umlagerung | `DE00000001` | Firmenpräfix + 8 Ziffern, ein Nummernkreis pro Belegart und Buchungskreis (`ZNR_PURORD`, `ZNR_GDSREC`, `ZNR_SALORD`, `ZNR_GDSISS`, `ZNR_STKTRF`), Vergabe beim ersten Sichern |

- Alle Nummernkreise sind mit einer Nummer im Hauptspeicher gepuffert (Nummern werden vor der Sicherungsphase gezogen).
- Kein Fallback: schlägt der Nummernkreis fehl, wird der Datensatz / Beleg nicht gesichert. Ein Beleg wird nie ohne Nummer gesichert.
- Nummern müssen nicht lückenlos sein; Entwürfe erzeugen keine Lücken, da sie keine Nummer haben.
- Ein neuer Buchungskreis erhält automatisch Intervalle für alle Beleg-Nummernkreise. „Alles löschen“ setzt sie zurück; der Seed gleicht die Stammdaten-Intervalle mit der Datenbank ab.
- Zentrale Klasse: `ZCL_MERP_NUM_RANGE_UTIL` (Massenmethoden für Stammdatenschlüssel und Belegnummern) mit den freigegebenen SAP-APIs `cl_numberrange_runtime` (Nummern) und `cl_numberrange_intervals` (Intervalle).

---

## 3. Stammdatenregeln

- **Löschprüfung:** jedes Objekt hat eine Verwendungs-View (`ZMERP_I_<X>_USAGE`, nur aktive Daten). Jede Verwendung blockiert das Löschen (`precheck_delete`, RAP-Fehlerursache „dependency“); eine Meldung pro verwendendem Objekt. Massenlöschen ganz oder gar nicht.
- **Schreibgeschützte Felder** (Tabelle oben) werden nur durch Verwendung in Belegen gesperrt, nicht durch andere Stammdaten.
- **Partnerrollen:** die Lieferantenrolle wird bei Verwendung im Einkauf gesperrt, die Kundenrolle bei Verwendung im Vertrieb; eine nicht gesetzte Rolle kann immer gesetzt werden.
- **Prüfung bei Eingabe:** Firmenpräfix (eindeutig unter aktiven Buchungskreisen) und MwSt.-Prozentsatz; übrige Pflichtfelder beim Sichern.
- **SAP-Stammdaten** (Währung, Land, Einheit) werden in der Wertehilfe und im Backend geprüft, da API-Aufrufe die Wertehilfe umgehen.
- **Gesperrt = veraltet:** Wertehilfen blenden gesperrte Datensätze aus, Vorschläge verwenden sie nicht; bestehende Verweise bleiben gültig, Belege bleiben änderbar und buchbar.
- Jedes Objekt hat eine Selektorklasse (`ZCL_MERP_MD_<X>_SEL`, mit Interface), über die andere Objekte es lesen.

---

## 4. Belege

### 4.1 Gemeinsames Verhalten
- Vorschläge: Belegdatum heute, Buchungsdatum = Belegdatum, erster Status. Ein Wechsel des Buchungskreises leert ein fremdes Lager; Aufträge übernehmen die Buchungskreiswährung.
- Ändern nur im ersten Status; Aktionen nur auf gesicherten Belegen. Der Buchungskreis ist nach Nummernvergabe schreibgeschützt.
- Kopfprüfungen: Buchungskreis und Lager existieren, Lager gehört zum Buchungskreis; Belege mit Partner prüfen zusätzlich Partner, Rolle und Buchungskreiswährung; Beleg- und Buchungsdatum nicht in der Zukunft; Buchungsdatum ≥ Belegdatum.
- Positionen: Artikel → Einheit; Menge > 0. Kaufmännische Belege zusätzlich: Artikel → MwSt.; Preis > 0; netto = Menge × Preis; Summen bei jeder Änderung. Doppelte Artikel werden abgelehnt, erneut geprüft beim Löschen einer Position.
- Löschen nur im ersten Status oder storniert / abgelehnt und nur, wenn kein anderer Beleg darauf verweist.
- Draft-Sperren sind RAP-Standard: ein Auftragsentwurf sperrt den Auftrag ca. 15 Minuten nach der letzten Änderung; Buchungen seiner Folgebelege scheitern in dieser Zeit mit „Auftrag gesperrt“.
- Gemeinsame Logik: `ZCL_MERP_DOC_ITEM_LOGIC` (Vorschläge, Beträge, Summen), `ZCL_MERP_DOC_ORDER_REF_LOGIC` (Folgebeleg gegen Auftragspositionen), `ZCL_MERP_DOC_VALIDATOR`, `ZCL_MERP_DOC_CALC`.

### 4.2 Bestellung

| Status | Erreicht durch |
|---|---|
| Neu | Anlegen |
| Genehmigt | Freigabe (mindestens eine Position); Rücknahme aller Wareneingänge |
| In Lieferung | Aktion In Delivery (Datumsdialog, Vorschlag Lieferdatum); Teillieferung |
| Abgeschlossen | alles geliefert; Aktion Complete (aus Genehmigt / In Lieferung) |
| Storniert | Cancel aus Neu, Genehmigt, In Lieferung (letzteres nur ohne gebuchte Wareneingänge) |

- Wareneingänge sind in Genehmigt und In Lieferung möglich. Die Aktion **Goods Receipt** legt einen Wareneingangsentwurf mit Bestellbezug an.
- Lieferantenreferenz (Freitext) und Lieferdatum.

### 4.3 Wareneingang
- Immer mit Bezug zu einer Bestellung. Die Auswahl der Bestellung (oder das Anlegen aus ihr) füllt den Kopf (Buchungskreis, Lager, Lieferant, Währung, Lieferantenreferenz) und je Bestellposition eine Position mit der offenen Menge.
- Weicht Buchungskreis, Lager oder Lieferant von der Bestellung ab, werden Bestellung und Positionen geleert.
- Bestellpositionen: nur die Menge ist änderbar. Manuelle Positionen können ergänzt werden und sind voll änderbar. Positionsaktion **Fill Open Quantity**; Spalten „Offen in Bestellung“ und „Bestellung“.
- **Post** prüft: Status, mindestens eine Position, Buchungskreiswährung, Bestellung genehmigt / in Lieferung, Buchungsdatum ≥ Bestelldatum, Bestellposition existiert noch, Menge ≤ offene Menge. Entspricht die Menge der offenen Menge, werden die offenen Beträge übernommen (der letzte Eingang schließt die Cents). Mehrere Wareneingänge einer Bestellung in einer Anfrage werden nacheinander geprüft.
- Nach Post: Bestellstatus aktualisiert, Bestandsbewegungen geschrieben. **Unpost** setzt auf Neu zurück (nur wenn der Bestand nicht negativ wird) und berechnet den Bestellstatus neu. **Cancel** nur aus Neu.

### 4.4 Kundenauftrag
Spiegel der Bestellung mit vertriebsspezifischen Unterschieden:

| Status | Erreicht durch |
|---|---|
| Offen | Anlegen; Rücknahme aller Warenausgänge |
| In Bearbeitung | Teilausgang |
| Abgeschlossen | alles ausgeliefert; Aktion Complete aus In Bearbeitung |
| Abgelehnt | Aktion Reject aus Offen |

- Ändern nur im Status Offen; Löschen in Offen oder Abgelehnt, wenn kein Warenausgang darauf verweist.
- Preis manuell; Kundenreferenz als Freitext; Sichern nur mit mindestens einer Position; kein Lieferdatum, keine Freigabe.
- Die Aktion **Goods Issue** legt einen Warenausgangsentwurf mit Auftragsbezug an. Keine Reservierung: die Verfügbarkeit wird erst beim Warenausgang geprüft.

### 4.5 Warenausgang
Spiegel des Wareneingangs mit dem Kundenauftrag in der Rolle der Bestellung:
- Immer mit Bezug zu einem Kundenauftrag; Kopf und Positionen aus den offenen Mengen; manuelle Positionen möglich; Spalten „Kundenauftrag“, „Offen im Auftrag“ und „Bestand“ (aktueller Bestand des Positionslagers, auch in nie gesicherten Entwürfen).
- **Post** prüft wie der Wareneingang (Auftrag offen / in Bearbeitung) plus **Bestandsverfügbarkeit** jeder Produktposition; danach Auftragsstatus und Bestandsbewegungen. **Unpost** ohne Bestandsprüfung.

### 4.6 Umlagerung
Wie SAP-Bewegungsart 301 (Umlagerung Werk an Werk in einem Schritt) innerhalb eines Buchungskreises: ein Lager übernimmt die Rolle des Werks. Nicht 311, da das Projekt keine Lagerorte hat.
- **Kopf:** Buchungskreis, abgebendes Lager, empfangendes Lager, Daten, Verantwortlicher, Bemerkungen. Kein Partner, keine Preise, keine Summen: der Wert existiert nur im Bestandsjournal.
- **Positionen:** nur Produkte (die Wertehilfe zeigt Artikeltyp P), Menge, Einheit; abgebendes und empfangendes Lager sind Kopien des Kopfes; Spalte „Bestand“ (abgebendes Lager).
- **Regeln:** beide Lager gehören zum Buchungskreis, das empfangende Lager ist Pflicht und ungleich dem abgebenden, keine doppelten Artikel, Menge > 0.
- **Status** wie beim Warenausgang: Neu → Gebucht (Post) → Neu (Unpost); Neu → Storniert. Ändern nur in Neu.
- **Post:** mindestens eine Position; sperrt beide Lager jeder Position; prüft die Verfügbarkeit im abgebenden Lager; entnimmt zum gleitenden Durchschnittspreis des abgebenden Lagers und bucht denselben Wert im empfangenden Lager zu, dessen Durchschnittspreis sich ändert. **Unpost:** gleiche Sperren; das empfangende Lager darf nicht negativ werden; die Bewegungen werden entfernt.

---

## 5. Bestandsführung

- **Journal** `ZMERP_STOCK_MOV`: Buchungskreis, Lager, Artikel, Menge (+ Eingang / − Ausgang), Einheit, Wert in Buchungskreiswährung, Buchungsdatum, Belegart (GR / GI / ST) und Belegbezug. Eine Bewegung pro gebuchter Produktposition im Lager der Position; bei der Umlagerung ergänzt die Buchung den Zugang im empfangenden Lager (wie die Position, die SAP automatisch erzeugt). Geschrieben nur in der Sicherungsphase durch `ZCL_MERP_STOCK_POSTING`; ein Statuswechsel löscht die Bewegungen des Belegs, Buchen schreibt neue (keine Stornobelege).
- **Salden** `ZMERP_R_STOCK_BALANCE`: Summe von Menge und Wert pro Buchungskreis, Lager, Artikel und Einheit; keine Saldentabelle.
- **Bewertung:** ein Eingang erhöht den Wert um seinen Nettobetrag (MwSt. ist kein Bestandswert). Ein Ausgang wird zum gleitenden Durchschnittspreis bewertet: Menge × Wert ÷ Menge des Saldos, auf 2 Stellen gerundet; der Ausgang der gesamten Restmenge nimmt den gesamten Restwert (schließt bei 0,00). Bewertungsebene = Buchungskreis + Lager (wie das SAP-Werk).
- **Verfügbarkeit und Sperren** (`ZCL_MERP_STOCK_CONTROL`): jedes Post / Unpost sperrt zuerst den Auftrag (Wareneingang / Warenausgang) und den Bestand pro Buchungskreis, Positionslager und Artikel (Umlagerung: beide Lager), liest und prüft danach. Die Verfügbarkeit wird geprüft bei Post des Warenausgangs, Unpost des Wareneingangs, Post (abgebendes Lager) und Unpost (empfangendes Lager) der Umlagerung. Ein gesperrter Beleg scheitert mit einer Meldung, die den Auftrag bzw. den sperrenden Benutzer nennt. Mehrere Positionen und Belege einer Anfrage werden nacheinander geprüft.
- Verwendet wird der aktuelle Saldo, nicht der Saldo zum Buchungsdatum; rückdatierte Buchungen sind erlaubt.
- Nur Produkte (Artikeltyp P) erzeugen Bestand, Dienstleistungen nicht.
- **Bestands-App** (`ZUI_MERP_STOCK`): Bestandssalden (Liste + Bewegungen) und Bestandsbewegungen (mit Belegart), beide nur Anzeige, sowie Umlagerungen; Filter Buchungskreis, Lager, Artikel, Warengruppe, Buchungsdatum, Belegart.

---

## 6. Testdaten

- `ZCL_MERP_CLEAR_ALL_DATA`: löscht Bestand, Belege, Beleg-Intervalle, Stammdaten und Stammdaten-Intervalle (in dieser Reihenfolge).
- `ZCL_MERP_INITIAL_SETUP` (F9): alles löschen, dann über RAP (EML) Ebene für Ebene:
  - Buchungskreise 1000–3000 und gesperrt 4000 (EUR), MwSt.-Sätze, Warengruppen, 10 Lager, 16 Artikel (inkl. Dienstleistungen und einem gesperrten), 13 Partner (Lieferanten, Kunden, beides, einer gesperrt);
  - 9 Bestellungen und 6 Kundenaufträge mit ihren Wareneingängen und -ausgängen in jedem Status, mit dem Cent-Fall beim letzten Eingang, Durchschnittspreisbewertung und einem absichtlich scheiternden Warenausgang (Bestand nicht ausreichend);
  - im Buchungskreis 3000 eine 10. Bestellung und 3 Umlagerungen: eine gebucht (das empfangende Lager hat danach 2 TVs für 1.299,99, ein Durchschnittspreis mit Cents), eine neu, eine storniert.
- **Demo-Buchungskreis 3000:** ein offener Wareneingang (Cent-Fall), der restliche Durchschnittspreisbestand zum Ausliefern und die neue Umlagerung bleiben für Live-Demos offen.

---

## 7. Konventionen und Vereinfachungen

- **Namen:** Tabellen `ZMERP_<X>` (+ `_D` Draft), Root Views `ZMERP_R_<X>`, Projektionen `ZMERP_C_<X>`, Hilfs- / Wertehilfe- / Verwendungs-Views `ZMERP_I_…`, Klassen `ZCL_MERP_…` mit Interfaces `ZIF_MERP_…`, Ausnahmen `ZCX_MERP_…`, Nachrichtenklassen `ZMC_MERP_…`, Nummernkreise `ZNR_…`.
- **RAP-Technik:** Behavior Definitions im strict mode 2; optimistische Sperre über ETag (`LocalLastChangedAt`) und Total ETag für Entwürfe (`LastChangedAt`); Side Effects in den Projektionen aktualisieren abhängige Felder und Summen in der UI; globale Berechtigungsprüfung (erlaubt alles).
- **Tests:** ABAP-Unit-Testklasse für den Buchungskreis-Selektor.
- **Muster:** Vertriebsbelege kopieren ihre Einkaufszwillinge (Kundenauftrag ← Bestellung, Warenausgang ← Wareneingang, Umlagerung ← Warenausgang ohne Auftrag); Bestandsbelege verwenden nur die Basisstrukturen; andere Objekte werden nur über Selektorklassen gelesen.
- **Vereinfachungen gegenüber SAP:** Rücknahme statt Stornobeleg; kein Positionsstatus im Auftrag; keine Reservierungen; Umlagerung nur innerhalb eines Buchungskreises und in einem Schritt (kein Bestand in Transit); eine Währung pro Buchungskreis; keine Berechtigungen (alles erlaubt); Communication Scenario nur für den Einkauf.
