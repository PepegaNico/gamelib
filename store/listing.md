# Microsoft Store – GameZer by ZerApps

Zum Kopieren ins Partner Center (Produkt «GameZer by ZerApps»).

## Paket

Das Paket `GameZer-Store.msix` baut GitHub bei jedem Push
(Workflow «Windows installer» → Artefakt **GameZer-Store-MSIX**). Die ZIP-Datei
entpacken und die `.msix` unter **Pakete** hochladen. Nicht selbst signieren –
das macht der Store.

## Preise und Verfügbarkeit

- Preis: **Kostenlos**
- Märkte: alle (oder nur Schweiz/Deutschland/Österreich zum Start)
- Sichtbarkeit: öffentlich

## Eigenschaften

- Kategorie: **Unterhaltung** (Unterkategorie keine)
- Datenschutzrichtlinie: https://pepeganico.github.io/gamelib/privacy.html
- Website: https://pepeganico.github.io/gamelib/
- Support-Kontakt: https://github.com/PepegaNico/gamelib/issues
- Systemanforderungen: Windows 10 Version 1809 oder neuer, x64
- Das Produkt greift auf Kontoinformationen zu, erfasst sie oder überträgt
  sie: **Ja** (Cloud-Sync mit E-Mail; Steam/Xbox/PlayStation-Anmeldung)

## Altersfreigabe (IARC-Fragebogen)

Kategorie «App» (kein Spiel). Keine Gewalt, keine Glücksspiele, keine
Nutzerinteraktion mit anderen Personen, keine Käufe. Standortfreigabe: nein.
Ergibt in der Regel **3+ / USK 0**.

## Store-Eintrag (Deutsch)

**Beschreibung**

GameZer bringt alle deine Spiele in eine Bibliothek: Steam, Epic Games, Xbox / Microsoft Store, PlayStation und itch.io.

Deine installierten Spiele startest du direkt aus GameZer – egal aus welchem Launcher. Die Bibliothek zeigt grosse Cover, Spielzeit und wann du zuletzt gespielt hast, und «Weiter spielen» bringt dich mit einem Klick zurück ins Spiel.

BIBLIOTHEK
• Steam-, Epic-, Xbox-, PlayStation- und itch.io-Spiele in einer Übersicht
• Installierte Epic- und Xbox-/Microsoft-Store-Spiele werden automatisch gefunden
• Filter nach Store, Suche (Ctrl+K), Sortierung und Backlog
• «Was spielen?» würfelt ein Spiel aus deinem Backlog

SPIELDETAILS
• Spielzeit, zuletzt gespielt, Erfolge und Metacritic-Wertung
• Beschreibung, Genres und Screenshots

WUNSCHLISTE & PREISALARME
• Steam-Wunschliste importieren, Zielpreise festlegen
• Preisvergleich über IsThereAnyDeal

XBOX & PLAYSTATION
• Mit deinem Microsoft-Konto: alle auf Xbox-Konsole, PC und in der Cloud gespielten Spiele mit Erfolgen
• Mit deinem PlayStation-Konto: alle gespielten PS4- und PS5-Spiele mit Spielzeit

AUCH AUF DEM IPHONE
• Mit Cloud-Sync siehst du deine Bibliothek und Wunschliste auch in der GameZer-App für iPhone

GameZer läuft im Hintergrund im Infobereich weiter, wenn du das Fenster schliesst.

Hinweis: GameZer ist eine unabhängige App und steht in keiner Verbindung zu Valve (Steam), Epic Games, Microsoft (Xbox) oder Sony Interactive Entertainment (PlayStation). Alle Marken gehören ihren jeweiligen Eigentümern. Für Steam wird ein eigener, kostenloser Steam-Web-API-Key benötigt.

**Kurzbeschreibung** (für Suchergebnisse)

Alle deine Spiele an einem Ort: Steam, Epic, Xbox und PlayStation in einer Bibliothek – installierte Spiele direkt starten.

**Features** (je eine Zeile, max. 20)

- Steam, Epic, Xbox, PlayStation und itch.io in einer Bibliothek
- Installierte Spiele direkt starten
- Spielzeit, zuletzt gespielt und Erfolge
- Wunschliste mit Preisalarmen
- Cloud-Sync mit der iPhone-App

**Suchbegriffe** (max. 7)

spielebibliothek, game launcher, steam, epic games, xbox, playstation, backlog

**Copyright**

© 2026 ZerApps

**Screenshots** (mind. 1, empfohlen 4; mind. 1366 × 768)

Auf dem PC in GameZer aufnehmen (Win + Shift + S, Fenster maximiert):
1. Bibliothek mit «Zuletzt gespielt» oben
2. Filter auf Xbox oder PlayStation
3. Spieldetails eines Spiels
4. Wunschliste

## Einreichungsoptionen → Hinweise für die Zertifizierung

> GameZer is a game library for Windows. Installed Epic Games and Xbox / Microsoft Store games are detected locally without any account. Showing the Steam library requires the user's own free Steam Web API key (steamcommunity.com/dev/apikey) and Steam sign-in; Xbox uses Microsoft sign-in (device code); PlayStation uses the user's own PlayStation account. The app keeps running in the notification area when the window is closed ("Beenden" in the tray menu quits it).
>
> runFullTrust: GameZer is a Flutter Win32 desktop app. It needs full trust to read the Epic Games Launcher's local manifest files, list installed Xbox/Microsoft Store game packages (PowerShell Get-AppxPackage) and start games through their launchers.

## Beschränkte Funktion `runFullTrust`

Das Partner Center fragt nach einer Begründung – den zweiten Absatz oben
einfügen.
