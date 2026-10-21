# Horizon

Kalender für die macOS-Menüleiste, im Stil des Wetter-Popovers. Ersetzt Itsycal.

Horizon zeigt den Tag als Horizont: oben die Sonnenbahn mit echten Auf- und Untergangszeiten, darunter die Termine, dazu Monatsansicht, Terminliste und einen Schnelleintrag auf Deutsch. Der Hintergrund färbt sich nach Tageszeit wie der Himmel draußen.

## Funktionen

- **Menüleiste**: Kästchen mit dem Tag (Zahl ausgestanzt, färbt sich wie Systemsymbole). Wahlweise nur Symbol, mit Datum oder mit nächstem Termin („Elterngespräch in 25 Min.“).
- **Kopf**: Wochentag, großes Datum, Monat, KW, Anzahl Termine heute, Symbol für die Tageszeit. Klick springt zu heute.
- **Tagesbogen**: der gewählte Tag mit Sonnenbahn, Sonne bzw. Mond an der aktuellen Uhrzeit, Termine als Balken in bis zu drei Spuren, ganztägige Termine als Chips. Vergangenes wird blasser.
- **Jetzt-Leiste**: laufender Termin mit Fortschritt und Restzeit oder nächster Termin in den nächsten 3 Stunden mit Countdown. Bei Zoom, Meet, Teams, Webex usw. ein „Beitreten“-Knopf.
- **Monat**: Kalenderwochen (abschaltbar), bis zu drei Farbpunkte je Tag, Tooltip mit den Terminen, animierter Monatswechsel.
- **Demnächst**: Termine nach Tagen gruppiert, Countdown für die nächsten 24 Stunden. Klick öffnet den Termin in „Kalender“.
- **Schnelleintrag**: „Fr 14 Uhr Zahnarzt“, „morgen 9:30-11 Friseur“, „23.10. Geburtstag“, „übermorgen 18 Uhr Training für 2 Std“. Vorschau vor dem Speichern, Enter trägt in den Standardkalender ein.
- **Einstellungen** (Regler unten rechts): Menüleisten-Anzeige, Vorschauzeitraum (3 Tage bis 1 Monat), sichtbare Kalender, Kalenderwochen, Start bei Anmeldung.

## Bauen und installieren

Voraussetzung: macOS 14 oder neuer, Xcode bzw. die Swift-Toolchain.

```sh
./build.sh           # baut build/Horizon.app
./build.sh install   # zusätzlich nach /Applications kopieren und starten
```

Das Icon entsteht beim ersten Bauen aus `scripts/make_icon.swift`. Zum Neuzeichnen `Resources/AppIcon.icns` löschen und neu bauen.

Autostart lässt sich in den Einstellungen schalten oder per `Horizon --launch-at-login` eintragen.

## Aufbau

| Datei | Inhalt |
|---|---|
| `HorizonApp.swift` | Einstieg, `MenuBarExtra` im Fenster-Stil |
| `CalendarStore.swift` | EventKit-Zugriff, Navigation, Termine je Tag, Autostart |
| `Agenda.swift` | Termin-Modell, Erkennung von Meeting-Links |
| `QuickAdd.swift` | Parser für den deutschen Schnelleintrag |
| `Sun.swift` | Sonnenzeiten (NOAA-Näherung), Himmelsfarben |
| `PopoverView.swift` | Fensteraufbau, Kopf, Fußzeile, Einstellungen, Zugriffsabfrage |
| `DayArcView.swift` | Tagesbogen |
| `MonthGrid.swift` | Monatsansicht |
| `AgendaList.swift` | Terminliste |
| `NowBanner.swift` | Jetzt-Leiste, Beitreten-Knopf |
| `QuickAddView.swift` | Eingabefeld für den Schnelleintrag |
| `MenuBarLabel.swift` | Symbol und Text in der Menüleiste |
| `Support.swift` | Kalender, Datumsformate, Farben |

## Bekannte Grenzen

- **Ad-hoc signiert.** Nach einem Neubau kann macOS den Kalenderzugriff erneut abfragen. Fehlen Termine, zuerst die Freigabe in Systemeinstellungen → Datenschutz → Kalender prüfen.
- **Sonnenzeiten fest für Kochel am See** (`Sun.latitude`/`Sun.longitude`), damit kein Standortzugriff nötig ist.
- **Nur Dunkelmodus gesehen.** Der helle Modus ist ungetestet.
- **Termin öffnen** nutzt `ical://ekevent/…`. Bei Serienterminen öffnet „Kalender“ eventuell nicht das richtige Vorkommen. Nicht geprüft.
- **Keine automatisierten Tests.** Der Parser wurde nur von Hand mit Beispielen geprüft.

## Wo es weitergeht

Ungefähr nach Nutzen sortiert:

1. **Hellen Modus prüfen** und Kontraste nachziehen (Farbpunkte, gedimmte Tage, Himmelsverlauf).
2. **Tests** für `QuickAdd` als Test-Target, mit den Beispielen oben und Randfällen (Monatswechsel, Jahreswechsel, Uhrzeit schon vorbei).
3. **Schnelleintrag erweitern**: Kalender wählen (z. B. „#Arbeit“), „nächste Woche“, Wiederholungen („jeden Mo“), Ort („in Bad Tölz“).
4. **Bedienung**: Pfeiltasten und Mausrad für Tage und Monate, Tastenkürzel zum Öffnen des Fensters.
5. **Erinnerungen** (Reminders) mit Fälligkeit im Tagesbogen und in der Liste.
6. **Termin-Details** direkt im Fenster (Notizen, Teilnehmer, Ort mit Karte) statt sofort „Kalender“ zu öffnen.
7. **Standort wählbar** für die Sonnenzeiten, z. B. als Ort in den Einstellungen statt fest im Code.
8. **Richtige Signatur** (Developer ID und Notarisierung), damit die Kalenderfreigabe Neubauten übersteht und die App weitergegeben werden kann.
