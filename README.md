# Horizon

Kalender für die Menüleiste. Ersatz für Itsycal, im Stil der Wetter-App.

- **Tagesbogen**: der gewählte Tag als Horizont, mit Sonnenbahn (Auf- und Untergang für Kochel am See), Termine darunter, Jetzt-Markierung
- **Himmel**: der Hintergrund färbt sich nach Tageszeit (Nacht, Morgenrot, Tag, Abendrot)
- **Jetzt-Leiste**: laufender Termin mit Fortschritt oder nächster Termin mit Countdown, „Beitreten“ bei Zoom/Meet/Teams-Links
- **Monat** mit Kalenderwochen, farbigen Punkten je Kalender, Tooltips mit Terminen
- **Demnächst**: Liste nach Tagen, Klick öffnet den Termin in „Kalender“
- **Schnelleintrag**: „Fr 14 Uhr Zahnarzt“, „morgen 9:30-11 Friseur“, „23.10. Geburtstag“, „übermorgen 18 Uhr Training für 2 Std“
- Menüleiste: nur Symbol, mit Datum oder mit nächstem Termin

## Bauen

```sh
./build.sh           # build/Horizon.app
./build.sh install   # nach /Applications kopieren und starten
```

Das Icon wird beim ersten Bauen aus `scripts/make_icon.swift` erzeugt. Zum Neuzeichnen `Resources/AppIcon.icns` löschen.
Die App ist nur ad-hoc signiert, nach einem Neubau kann macOS den Kalenderzugriff erneut abfragen.
