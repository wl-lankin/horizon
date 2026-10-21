# Horizon

Kalender für die macOS-Menüleiste, im Stil des Wetter-Popovers. Ersetzt Itsycal.

Horizon zeigt den Tag als Horizont: oben die Sonnenbahn mit echten Auf- und Untergangszeiten, darunter Termine und Erinnerungen, dazu Monatsansicht, Terminliste und einen Schnelleintrag auf Deutsch. Der Hintergrund färbt sich nach Tageszeit wie der Himmel draußen.

**Download:** https://github.com/wl-lankin/horizon/releases/latest/download/Horizon-macOS.dmg (macOS 14 oder neuer, Apple Silicon und Intel)

Kostenlos und Open Source unter der [MIT-Lizenz](LICENSE).

## Funktionen

- **Menüleiste**: Kästchen mit dem Tag (Zahl ausgestanzt, färbt sich wie Systemsymbole). Wahlweise nur Symbol, mit Datum oder mit nächstem Termin („Elterngespräch in 25 Min.“).
- **Kopf**: Wochentag, großes Datum, Monat, KW, Anzahl Termine heute, Symbol für die Tageszeit. Klick springt zu heute.
- **Tagesbogen**: der gewählte Tag mit Sonnenbahn, Sonne bzw. Mond an der aktuellen Uhrzeit, Termine als Balken in bis zu drei Spuren, Erinnerungen als Rauten, ganztägige Termine als Chips. Klick auf die Sonnenzeiten wählt den Ort.
- **Jetzt-Leiste**: laufender Termin mit Fortschritt und Restzeit oder nächster Termin in den nächsten 3 Stunden mit Countdown. Bei Zoom, Meet, Teams, Webex usw. ein „Beitreten“-Knopf.
- **Monat**: Kalenderwochen (abschaltbar), bis zu drei Farbpunkte je Tag, Tooltip mit den Terminen, Blättern mit Pfeilen, Mausrad oder Trackpad.
- **Demnächst**: Termine und fällige Erinnerungen nach Tagen gruppiert, Countdown für die nächsten 24 Stunden, überfällige Erinnerungen unter „Heute“. Erinnerungen lassen sich direkt abhaken.
- **Details**: Klick auf einen Termin zeigt Zeit, Kalender, Wiederholung, Ort mit Karte, Teilnehmer mit Zusagestatus, Notizen und Links. Von dort geht es weiter in „Kalender“ oder „Erinnerungen“.
- **Schnelleintrag**: „Fr 14 Uhr Zahnarzt“, „morgen 9:30-11 Friseur“, „23.10. Geburtstag“, „übermorgen 18 Uhr Training für 2 Std“. Dazu `#Kalender` („#Arbeit“), `@Ort` („@Bad Tölz“), „nächste Woche (Di)“ und Wiederholungen („jeden Di“, „täglich“, „monatlich“, „jährlich“). Vorschau vor dem Speichern, Enter trägt ein.
- **Tastatur**: ←/→ Tag, ↑/↓ Woche, ⌘←/⌘→ oder Bild-Tasten Monat, T heute, Enter öffnet den ersten Termin, Esc schließt Details. Systemweit öffnet ⌥⌘K das Fenster.
- **Einstellungen** (Regler unten rechts): Menüleisten-Anzeige, Vorschauzeitraum, sichtbare Kalender und Listen, Erinnerungen, Kalenderwochen, Ort für Sonnenzeiten, Kurzbefehl, Start bei Anmeldung, Updates.
- **Updates**: Horizon aktualisiert sich selbst über GitHub-Releases, siehe [docs/RELEASE.md](docs/RELEASE.md).

Alles bleibt auf dem Mac. Horizon liest die Kalender und Erinnerungen über EventKit, es gibt kein Konto und keinen Server. Netzwerkzugriffe gibt es nur für die Update-Prüfung, die Ortssuche und die Karte in den Details.

## Bauen

Voraussetzung: macOS 14 oder neuer zum Ausführen, Xcode 26 (macOS-26-SDK) zum Bauen.

```sh
./build.sh                  # build/Horizon.app
./build.sh install          # zusätzlich nach /Applications kopieren und starten
./build.sh release 1.1.0    # Universal-App, DMG, Update-ZIP und latest.json in dist/
swift test                  # Tests für den Schnelleintrag
```

Das Icon entsteht beim ersten Bauen aus `scripts/make_icon.swift`. Zum Neuzeichnen `Resources/AppIcon.icns` löschen und neu bauen.

Signiert wird mit dem Horizon-Zertifikat aus `~/.horizon/`, ohne dieses ad-hoc. Release-Ablauf und Schlüssel: [docs/RELEASE.md](docs/RELEASE.md).

Schnappschüsse des Fensters im hellen und dunklen Modus, ohne die Menüleiste anzuklicken:

```sh
open -n -W /Applications/Horizon.app --args --snapshot /tmp/shots main     # oder detail, place
```

## Aufbau

| Datei | Inhalt |
|---|---|
| `HorizonApp.swift` | Einstieg, `MenuBarExtra` im Fenster-Stil |
| `CalendarStore.swift` | EventKit-Zugriff (Termine und Erinnerungen), Navigation, Panels, Eintragen, Autostart |
| `Agenda.swift` | Modell für Termine und Erinnerungen, Erkennung von Meeting-Links |
| `QuickAdd.swift` | Parser für den deutschen Schnelleintrag |
| `Sun.swift` | Sonnenzeiten (NOAA-Näherung), Ort, Himmelsfarben |
| `PopoverView.swift` | Fensteraufbau, Tastatur, Kopf, Fußzeile, Einstellungen, Zugriffsabfrage |
| `DayArcView.swift` | Tagesbogen |
| `MonthGrid.swift` | Monatsansicht, Mausrad |
| `AgendaList.swift` | Terminliste, Abhaken von Erinnerungen |
| `DetailView.swift` | Details mit Karte, Ortswahl für die Sonnenzeiten |
| `NowBanner.swift` | Jetzt-Leiste, Beitreten-Knopf |
| `QuickAddView.swift` | Eingabefeld für den Schnelleintrag |
| `MenuBarLabel.swift` | Symbol und Text in der Menüleiste |
| `HotKey.swift` | systemweiter Kurzbefehl |
| `Updater.swift` | Selbst-Update über GitHub-Releases |
| `Snapshot.swift` | Schnappschuss-Modus für hell und dunkel |
| `Support.swift` | Kalender, Datumsformate, Farben |

## Bekannte Grenzen

- **Nicht notarisiert.** Beim ersten Öffnen warnt macOS, siehe [docs/RELEASE.md](docs/RELEASE.md).
- **Termin öffnen** in „Kalender“ nutzt `ical://ekevent/…`, bei Serienterminen mit dem Datum des Vorkommens. Ob „Kalender“ dabei das richtige Vorkommen zeigt, ist nicht geprüft.
- **Kurzbefehl ⌥⌘K** öffnet das Fenster über einen Klick auf das Menüleisten-Symbol, weil `MenuBarExtra` dafür keine Schnittstelle hat. Ist das Symbol ausgeblendet (z. B. hinter der Notch), passiert nichts.
- **Tests** gibt es für den Schnelleintrag, nicht für die Oberfläche.

## Wo es weitergeht

1. **Notarisierung** mit einem Developer-ID-Zertifikat, damit die Warnung beim ersten Öffnen entfällt.
2. **Tests für den Store**: Gruppierung nach Tagen, mehrtägige Termine, Tageswechsel um Mitternacht.
3. **Kurzbefehl frei wählbar** statt fest ⌥⌘K.
4. **Mehrere Orte für Sonnenzeiten** oder Ort automatisch aus dem nächsten Termin.
