# Release und automatische Updates

Horizon aktualisiert sich selbst, ohne zu stören. Die installierte App fragt 30 Sekunden nach dem Start und danach alle sechs Stunden bei GitHub nach `latest.json`. Ist dort eine neuere Version, lädt sie die ZIP im Hintergrund, prüft sie und tauscht das App-Bundle aus. Die neue Version gilt ab dem nächsten Start. Bis dahin steht unten im Fenster „X bereit · Neu starten“. Von Hand: Einstellungen (Regler) → „Nach Updates suchen …“.

Geprüft wird zweifach, bevor etwas ersetzt wird:

1. **Ed25519-Signatur der ZIP** gegen den öffentlichen Schlüssel `HorizonUpdatePublicKey` in `Info.plist`.
2. **Code-Signatur der neuen App** gegen die Designated Requirement der laufenden App. Das neue Bundle muss also mit demselben Horizon-Zertifikat signiert sein und dieselbe Bundle-ID haben.

Beide Prüfungen sind getestet: Ein Update von 0.9.0 auf 1.0.0 über einen lokalen Server lief durch, eine gefälschte Signatur wurde abgelehnt.

## Aufbau

| Teil | Wo |
|---|---|
| Updater im Code | `Sources/Horizon/Updater.swift`, Anzeige in `PopoverView.swift` (Fußzeile, Einstellungen) |
| Bauen, signieren, DMG, ZIP, `latest.json` | `build.sh release X.Y.Z` |
| Update-Signatur | `scripts/sign_update.swift` |
| Pipeline | `.github/workflows/release.yml` |
| Release-Text | Abschnitt `## X.Y.Z` in `CHANGELOG.md`, sonst die Nachricht des Tags (`.github/release-notes.sh`) |

## Dateien im Release

| Datei | Zweck |
|---|---|
| `Horizon-X.Y.Z.dmg` | macOS 14 oder neuer, Apple Silicon und Intel |
| `Horizon-macOS.dmg` | dasselbe, fester Name für die Website |
| `Horizon-X.Y.Z.zip` | Update-Paket für den Updater |
| `latest.json` | Version, Download-Adresse, Signatur, Release-Text |

Fester Link für die Website:

- https://github.com/wl-lankin/horizon/releases/latest/download/Horizon-macOS.dmg

## Schlüssel und Zertifikat

Alles liegt in `~/.horizon/` (nur auf diesem Mac) und in den GitHub-Secrets. Nie committen, die `.gitignore` schließt `*.key`, `*.pass` und `*.p12` aus.

| Datei | Secret | Zweck |
|---|---|---|
| `update.key` | `HORIZON_UPDATE_KEY` | privater Ed25519-Schlüssel für die Update-Signatur |
| `signing.p12` (base64) | `HORIZON_SIGNING_P12` | Horizon-Signierzertifikat, selbst ausgestellt, gültig bis 2036 |
| `signing.pass` | `HORIZON_SIGNING_PASSWORD` | Passwort für p12 und den Schlüsselbund |
| `signing.keychain-db` | | lokaler Schlüsselbund, `build.sh` nutzt ihn automatisch |

Geht einer der beiden Schlüssel verloren, nehmen installierte Apps keine Updates mehr an: ohne `update.key` scheitert die Signaturprüfung, ohne das Zertifikat die Prüfung der Code-Signatur. Deshalb `~/.horizon/` zusätzlich im Passwortmanager sichern.

Das eigene Zertifikat hat noch einen zweiten Zweck: macOS merkt sich die Kalenderfreigabe anhand der Signatur. Mit einer ad-hoc-Signatur würde Horizon nach jedem Update erneut fragen, mit dem Zertifikat bleibt die Freigabe erhalten.

## Ein Release erstellen

1. Abschnitt `## X.Y.Z` oben in `CHANGELOG.md` ergänzen. Die Version in `Resources/Info.plist` ist nur der Stand für lokale Builds, die Pipeline nimmt die Version aus dem Tag.
2. Committen und pushen.
3. Tag setzen und pushen:
   ```bash
   git tag -a v1.1.0 -m "Horizon 1.1.0"
   git push origin v1.1.0
   ```
   Ein Tag mit Bindestrich (`v1.1.0-beta.1`) wird als Vorabversion markiert.
4. Lauf „Release“ unter Actions abwarten.
5. Entwurf prüfen (vier Dateien, `latest.json` mit `signature` und `url`) und veröffentlichen:
   ```bash
   gh release edit v1.1.0 --draft=false --latest
   ```
   Erst dann sehen installierte Apps das Update und der Website-Link liefert die neue Version.

Lokal geht dasselbe ohne Pipeline: `./build.sh release 1.1.0` legt alle Dateien in `dist/`.

## Updater lokal testen

```bash
./build.sh release 0.9.0 && cp -R build/Horizon.app /Applications/   # alte Version installieren
./build.sh release 1.0.0                                              # neue Version bauen
# dist/latest.json kopieren, "url" auf http://127.0.0.1:8765/Horizon-1.0.0.zip ändern, Ordner per
# python3 -m http.server 8765 bereitstellen, dann:
defaults write de.wolfganglinz.horizon updateFeedURL http://127.0.0.1:8765/latest.json
open /Applications/Horizon.app        # nach etwa 30 Sekunden ist /Applications/Horizon.app auf 1.0.0
defaults delete de.wolfganglinz.horizon updateFeedURL
```

## Einschränkungen

- TODO Apple-Notarisierung: Dafür braucht es ein „Developer ID Application“-Zertifikat aus dem kostenpflichtigen Apple-Developer-Programm. Bis dahin warnt macOS beim ersten Öffnen. Abhilfe: Systemeinstellungen → Datenschutz und Sicherheit → „Trotzdem öffnen“, oder `xattr -dr com.apple.quarantine /Applications/Horizon.app`. Updates sind davon nicht betroffen.
- Liegt Horizon an einem Ort ohne Schreibrechte, kann der Updater das Bundle nicht ersetzen und meldet das bei der Suche von Hand.
