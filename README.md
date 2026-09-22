# GameZer

Alle deine PC-Spiele an einem Ort: Steam, Epic Games, Xbox / Microsoft Store
und itch.io in einer Bibliothek, mit Wunschliste, Preisalarmen und
Cloud-Sync zur iPhone-App.

## Installieren (Windows)

1. Unter [Releases](https://github.com/PepegaNico/gamelib/releases) die
   neueste `GameZer-Setup-x.y.z.exe` herunterladen.
2. Ausführen. Windows SmartScreen warnt beim ersten Mal, weil der Installer
   nicht signiert ist: **Weitere Informationen → Trotzdem ausführen**.
3. Die Installation braucht keine Administratorrechte. Optional:
   Desktop-Verknüpfung und Autostart.

Updates: einfach die neue Setup-Datei ausführen, sie ersetzt die alte
Version.

## Was die App findet

| Store | Wie | Starten |
|---|---|---|
| Steam | Steam Web API (API-Key + Steam-Login) — alle besessenen Spiele | `steam://run/<id>` |
| Epic Games | installierte Spiele aus den Launcher-Dateien; ganze Bibliothek optional über [Legendary](https://github.com/derrod/legendary) | Epic-Launcher-Link |
| Xbox / Microsoft Store | installierte PC-Spiele (Pakete mit `MicrosoftGame.config`) | direkt über Windows |
| itch.io | itch.io API-Key | Store-Seite |

## Entwickeln

```bash
flutter pub get
flutter run -d windows
```

## Neue Version veröffentlichen

1. `version:` in `pubspec.yaml` erhöhen.
2. Committen, dann einen Tag pushen:

   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

3. Die GitHub Action [Windows installer](.github/workflows/windows-release.yml)
   baut die App, erstellt den Installer mit Inno Setup
   ([installer/gamezer.iss](installer/gamezer.iss)) und hängt ihn an ein
   neues Release. Jeder Push auf `master` und jeder Pull Request baut den
   Installer ebenfalls und legt ihn als Artefakt am Workflow-Lauf ab.
