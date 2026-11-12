# Mini-ERP – Einkauf, Lagerhaltung und Vertrieb

[English](README.md) | [Deutsch](README.de.md) | [Українська](README.ua.md)

[![SAP ABAP Cloud](https://img.shields.io/badge/SAP-ABAP%20Cloud-0FAAFF?style=flat-square&logo=sap)](https://www.sap.com)
[![SAP RAP](https://img.shields.io/badge/Model-SAP%20RAP%20(Managed%20%2B%20Draft)-0073C6?style=flat-square)](https://help.sap.com)
[![Clean Core](https://img.shields.io/badge/Architecture-Clean%20Core%20Compliant-green?style=flat-square)](#6-clean-core-prinzipien)
[![Status](https://img.shields.io/badge/Status-Procurement%20%7C%20Sales%20%7C%20Stock%20Implemented-brightgreen?style=flat-square)](#3-implementierungsstatus)

**Version:** 1.0 (MVP)

---

## 1. Projektübersicht

Mini-ERP ist eine Demo-ERP-Anwendung auf Basis von SAP ABAP Cloud und dem SAP RESTful Application Programming Model (RAP, managed mit Draft) in der SAP BTP ABAP Environment (Trial).

Sie bildet eine vereinfachte, aber vollständige Prozesskette ab: Stammdaten → Einkauf (Bestellung → Wareneingang) → Bestand → Vertrieb (Kundenauftrag → Warenausgang). Das Verhalten folgt so nah wie möglich dem SAP-Standard (Einkauf, Vertrieb, Bestandsführung), vereinfacht.

Das Projekt ist ein Portfolio-Projekt für cloudfähige ABAP-Entwicklung: RAP Business Objects, CDS View Entities, OData-V4-Services und SAP Fiori Elements.

Details: [Architektur & Technisches Design](docs/Architecture.de.md).

---

## 2. Technologie-Stack

- **Plattform:** SAP BTP ABAP Environment (Trial)
- **IDE:** Eclipse ADT (ABAP Development Tools)
- **Programmiermodell:** SAP RAP, managed Business Objects mit Draft, strict mode
- **Datenmodellierung:** CDS View Entities
- **Persistenz:** Datenbanktabellen mit RAP-Draft-Tabellen
- **Services:** OData V4 UI Services (`ZUI_MERP_O4`, `ZUI_MERP_PROCUREMENT_O4`, `ZUI_MERP_SALES_O4`, `ZUI_MERP_STOCK_O4`)
- **UI:** SAP Fiori Elements
- **Entwicklungsstandard:** ABAP Cloud / Clean Core

---

## 3. Implementierungsstatus

| Bereich | Inhalt | Status |
|---|---|---|
| Stammdaten | Buchungskreis, Lager, Geschäftspartner, Warengruppe, Artikel, MwSt.-Satz | Umgesetzt |
| Einkauf | Bestellung, Wareneingang | Umgesetzt |
| Bestandsführung | Bestandsjournal und -salden, Verfügbarkeitsprüfung, gleitender Durchschnittspreis, Bestandssperren, Bestands-App (nur Anzeige) | Umgesetzt |
| Vertrieb | Kundenauftrag, Warenausgang | Umgesetzt |
| Testdaten | Alle Daten löschen und Seed mit Belegen in jedem Status | Umgesetzt |

**Ideen, nicht begonnen:** Umlagerung zwischen Lagern (wie SAP-Bewegungsart 311); automatischer Preisvorschlag in Belegen.
**Zurückgestellt:** Währungsumrechnung; Abschluss einzelner Auftragspositionen; Bestand zu einem Stichtag / Periodenabschluss.

---

## 4. Wichtigste Merkmale

### Nummernvergabe
- Stammdatenschlüssel kommen beim Anlegen aus Nummernkreisobjekten (`WH001`, `V001`, `00001`); der Buchungskreis wird manuell erfasst.
- Belegnummern laufen pro Belegart und Buchungskreis mit Firmenpräfix (`DE00000001`) und werden beim ersten Sichern vergeben. Entwürfe haben keine Nummer.
- Kein Fallback: schlägt der Nummernkreis fehl, wird nichts gesichert (ein früherer Fallback über das Datenbankmaximum erzeugte doppelte Nummern und wurde entfernt).
- Ein neuer Buchungskreis erhält automatisch Intervalle für alle Belegarten.

### Stammdaten-Integrität
- Ein verwendeter Datensatz kann nicht gelöscht werden; die Meldung nennt jedes verwendende Objekt.
- Kritische Felder werden schreibgeschützt, sobald der Datensatz in Belegen verwendet wird (z. B. Währung und Präfix des Buchungskreises, Buchungskreis des Lagers, Artikeltyp und Basismengeneinheit, MwSt.-Prozentsatz, eine verwendete Partnerrolle).
- Sperren statt Löschen: gesperrte Datensätze sind in Wertehilfen ausgeblendet und werden nicht vorgeschlagen; bestehende Belege bleiben gültig, änderbar und buchbar.
- SAP-Stammdaten (Währung, Land, Mengeneinheit) werden in der Wertehilfe und im Backend geprüft.

### Belege
- Positionsbeträge (netto, MwSt., brutto) und Kopfsummen werden bei jeder Änderung neu berechnet; Preise sind Nettopreise.
- Feldbezogene Meldungen verschwinden, sobald das Feld korrigiert ist; doppelte Artikel werden abgelehnt.
- Bis zur Währungsumrechnung ist nur die Buchungskreiswährung erlaubt; das Buchungsdatum darf nicht in der Zukunft liegen.

### Auftrag → Folgebeleg
- Wareneingang / Warenausgang entsteht entweder aus dem Auftrag (Aktion „Goods Receipt“ / „Goods Issue“, wie SAP „Anlegen mit Bezug“) oder durch Auswahl des Auftrags im Folgebeleg.
- Positionen werden aus den offenen Mengen gefüllt; wird die gesamte offene Menge übernommen, werden auch die offenen Beträge übernommen, sodass der letzte Eingang / Ausgang die Cents genau schließt.
- Keine Über- oder Mehrlieferung; der Auftragsstatus (in Lieferung / in Bearbeitung / abgeschlossen) folgt automatisch den gebuchten Belegen.

### Bestandsführung
- Bestandsbewegungen werden in der Sicherungsphase der Buchung geschrieben; Salden werden aus dem Journal berechnet.
- Wareneingänge erhöhen den Bestand mit ihrem Nettobetrag; Warenausgänge werden wie in SAP zum gleitenden Durchschnittspreis bewertet.
- Ein Warenausgang wird nur bei verfügbarem Bestand gebucht; die Rücknahme eines Wareneingangs darf den Bestand nicht negativ machen.
- Buchen und Zurücknehmen sperren den Auftrag und den Bestand seiner Artikel, parallele Buchungen können nicht überbuchen.
- Dienstleistungen erzeugen keine Bestandsbewegungen.

### Testdaten
- `ZCL_MERP_INITIAL_SETUP` (Ausführung mit F9) löscht alle Daten und legt Stammdaten sowie Einkaufs- und Vertriebsbelege in jedem Status an, einschließlich Rundungs- und Durchschnittspreisfällen.

---

## 5. Services & UI-Vorschau

Ein OData-V4-Service pro Bereich:
- **Stammdaten (`ZUI_MERP_O4`):** Buchungskreis, Lager, Geschäftspartner, Warengruppe, Artikel, MwSt.-Satz.
- **Einkauf (`ZUI_MERP_PROCUREMENT_O4`):** Bestellungen, Wareneingänge und ihre Positionen (plus referenzierte Stammdaten). Zusätzlich über ein Communication Scenario veröffentlicht.
- **Vertrieb (`ZUI_MERP_SALES_O4`):** Kundenaufträge, Warenausgänge und ihre Positionen (plus referenzierte Stammdaten).
- **Bestand (`ZUI_MERP_STOCK_O4`):** Bestandssalden und Bestandsbewegungen, nur Anzeige.

---

## 6. Clean-Core-Prinzipien

- **Striktes ABAP Cloud:** nur freigegebene SAP-APIs und -Objekte.
- **RAP Draft:** integrierte Zustandsverwaltung für zustandslose HTTP-Kommunikation; Standard-Draft-Sperren.
- **Verwaltungsdaten:** `CREATED_BY`, `CREATED_AT`, `LOCAL_LAST_CHANGED_BY`, `LOCAL_LAST_CHANGED_AT`, `LAST_CHANGED_AT` werden vom Framework für alle Datensätze gefüllt und dienen auch der optimistischen Sperre (ETag).

---

## 7. Einrichtung und Ausführung

1. Repository mit **abapGit** in Eclipse ADT in die SAP BTP ABAP Environment importieren.
2. Objekte aktivieren (Dictionary, CDS Views, Behavior Definitions, Services).
3. Service Bindings `ZUI_MERP_O4`, `ZUI_MERP_PROCUREMENT_O4`, `ZUI_MERP_SALES_O4`, `ZUI_MERP_STOCK_O4` öffnen und **Publish** (oder **Unpublish / Publish**) klicken.
4. Klasse `ZCL_MERP_INITIAL_SETUP` in Eclipse ADT ausführen (`F9`): löscht alle Daten und legt Stammdaten und Belege an. Jederzeit erneut ausführbar, um das System zurückzusetzen.
5. Apps über die Fiori-Elements-Vorschau in den Service-Binding-Editoren öffnen. Demo-Buchungskreis: **3000**.

---

## Lizenz
MIT, siehe [LICENSE](LICENSE).

---

## 📄 Zugehörige Dokumentation
- 📘 [Architektur & Technisches Design](docs/Architecture.de.md)
