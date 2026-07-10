# SolixBar — Implementierungsplan (Review-Fixes & Design)

Basis: Code-Review + Live-UI-Review vom 2026-07-11 (Fork `itsab1989/SolixBar`, Branch `review-fixes`).
Jede Phase endet mit: `swift build` grün, Tests grün, Offscreen-Renders aktualisiert, Commit.

## Phase 0 — Infrastruktur (Voraussetzung für "verified by tests")

- [ ] **Package-Umbau:** Code in Library-Target `SolixBarKit` + dünnes Executable `SolixBar` splitten, damit ein Test-Target möglich ist (SwiftPM kann Executables nicht direkt testen).
- [ ] **Test-Target** `SolixBarTests` (swift-testing) anlegen.
- [ ] **Render-Harness einchecken** (`Tools/render/`): rendert Dashboard, Graph, Slim-Bar, Settings-Tabs offscreen als PNG (hell/dunkel) — Grundlage für visuelle Verifikation ohne Screen-Recording-Berechtigung. Baseline-Renders unter `Tools/render/baseline/` versionieren.
- [ ] `.gitignore`: `outputs/`, `.build/`, `.claude/`, Render-Ausgaben.

## Phase 1 — P0: App auf dem Zielrechner funktionsfähig

1. **Notch-Breitenbudget** (Hauptbug: Statusitem wird auf Notch-MacBooks unsichtbar)
   - Verfügbare Breite messen (`NSScreen.safeAreaInsets` / `auxiliaryTopRightArea`, Position des Items).
   - Anzeige degradiert kontrolliert: volle Darstellung → ohne Labels → ohne Symbole → nur Kernwerte, bis das Budget passt; nie breiter als der Platz rechts der Notch.
   - Beim Start Diagnose loggen (Itembreite, Safe-Area) — hätte den Bug sofort sichtbar gemacht.
   - Tests: Budget-Rechner pur (Breite×Optionen→gewählte Stufe); On-Screen-AX-Test: Item existiert, `position.x + width` kollidiert nicht mit Notch-Zone.
2. **Hartkodierte `/Users/holger`-Pfade entfernen** (`SettingsWindowController`)
   - Credentials/Env nach `~/Library/Application Support/SolixBar/solixbar.env` (0600).
   - Helper-Script aus dem Repo bündeln bzw. relativ zur App auflösen; `SOLIXBAR_ENV_FILE` ans Script durchreichen (wird dort bereits unterstützt).
   - README-Beispielpfad korrigieren.
   - Tests: Env-Datei Roundtrip (schreiben/lesen/quoting), Pfadauflösung.
3. **Letzten Snapshot bei Fehlern behalten** (`StatusController.refresh`)
   - Fehler setzt `lastError`, löscht aber nicht `lastSnapshot`; UI zeigt Werte als "veraltet" (Zeitstempel + Warnsymbol).
   - Tests: Provider-Fake, der einmal wirft → Anzeige-Modell behält Werte.

## Phase 2 — P1: Robustheit der Datenpfade

- [ ] **Keychain statt Klartext-Env** für Mail/Passwort (Env-Datei bleibt als Fallback fürs Script, enthält dann nur noch Referenz/Non-Secrets).
- [ ] **HTTP-Status prüfen** in `URLSolixDataProvider` (Fehlertext: Status + URL).
- [ ] **`siteName` optional** im Decoder (+ Default "Anker SOLIX").
- [ ] **CommandProvider:** stdout/stderr asynchron lesen (kein 64-KB-Pipe-Deadlock), Timeout mit SIGTERM→SIGKILL-Eskalation, kein Busy-Poll.
- [ ] **History:** Samples pro Datenquelle trennen (Demo verschmutzt Live-Graf nicht mehr); Speicherung als JSON-Datei in App Support statt UserDefaults-Blob; Sample-Cap an Intervall × längste Range koppeln (30-Tage-Ansicht muss mit Standardintervall füllbar sein).
- [ ] Tests: Decoder-Fälle (minimal/voll/kaputt), History-Mathematik (kWh-Akkumulation, Pruning, Quellentrennung), Provider mit Fake-Befehlen (`/bin/echo`, Endlosschleife, 100-KB-Ausgabe).

## Phase 3 — Design-Pass (laufend, Theme-Fundament committet)

- [x] `Theme.swift`: semantische Farbrollen (hell/dunkel adaptiv inkl. Menüleisten-Luminanz), Radius-Token, `.solixRole`-Attribut. **Bewusste Änderung: Netzbezug rot (Kosten) statt blau — der Graph nutzte bereits rot.**
- [ ] **Slim-Bar:** Farb-Remapping per Textsuche (~150 Zeilen Keyword-Parsing) ersetzen durch `.solixRole`-Attribut → `Theme.bright(role)`; Akzent-Gradient entschlammen (ein dezenter Zwei-Stopp-Akzent statt 5 Farben à 0,18 Alpha).
- [ ] **Graph:** Header-Kollision mit Plotfläche beheben (Zeichenreihenfolge/Insets); doppelten "Verlauf"-Titel im Dropdown entfernen; runde Stunden-Ticks statt :33-Zeiten; nur Solar als Fläche füllen (kein Oliv-Matsch); Achsenzuordnung kennzeichnen (%-Labels in Akku-Farbe); "Jetzt"/Legende lokalisieren; Farben aus Theme.
- [ ] **Dashboard:** Radius-Skala vereinheitlichen (16/12/8); Tage-Feld nur bei "Eig." zeigen; Metrik-Checkboxen mit Farbpunkten (ersetzen die fehlende Legende); Grid-Farbe folgt Theme (rot bei Bezug).
- [ ] **CALayer-Farben:** dynamische `NSColor.cgColor`-Snapshots bei `viewDidChangeEffectiveAppearance` aktualisieren (Theme-Wechsel-Bug).
- [ ] **Menüleisten-Icon:** vereinfachtes Template-Glyph (Sonne/Blitz) für 18 px statt des 1,5-MB-PNG-Downscales; PNG nur noch für Dock/Abbildungen; Bundle-Load cachen.
- [ ] Verifikation: Vorher/Nachher-Renders (hell/dunkel), On-Screen-Check des Statusitems.

## Phase 4 — P2: Wartbarkeit & Feinschliff

- [ ] **Logging-Überarbeitung:** `os.Logger` (Subsystem `local.codex.SolixBar`, Kategorien refresh/ui/settings/window) mit Datei-Spiegel; Fehlerkontext (DecodingError-Details, HTTP-Status, Exit-Code + redigiertes stderr); DEBUG-Level per `defaults`-Schalter; `#function`/`#line`; FileHandle offen halten, Formatter cachen; Start-Diagnose (Itembreite, Safe-Area, Version, Settings-Digest); Secrets-Redaktion.
- [ ] **Settings-Dialog:** Tabs "App" + "Start" zusammenlegen; "?"-Buttons einheitlich ausrichten (oder als Popover klickbar machen); Eingabevalidierung mit Feedback (Intervall, Zahlenfelder); Modus-Popup lokalisieren; Live-Preview nicht mehr bei jedem Tastendruck in Settings schreiben (debouncen).
- [ ] **Lokalisierung:** String-Katalog statt `LocalizedText.text(de,en)`-Paare; Sprachwechsel aktualisiert offene Fenster vollständig.
- [ ] **`SMAppService`** statt LaunchAgent-Plist für Autostart.
- [ ] `StatusController` entflechten (Formatter/MenuBuilder/WindowCoordinator) — mechanisch, nach Tests.
- [ ] CHANGELOG + VERSION pflegen.

## Phase 5 — Abschluss

- [ ] Alle Phasen: Renders aktualisiert, Tests grün, `sh scripts/package_app.sh` verifiziert.
- [ ] Branch pushen, PR im Fork (Doku der Änderungen mit Vorher/Nachher-Bildern).
- [ ] **Upstream-Issue bei `Ravaners/SolixBar`** mit den Review-Befunden und Verbesserungsvorschlägen (DE + EN-TL;DR), nur Demo-Daten-Renders als Bilder, keinerlei private Daten/Pfade.

## Teststrategie (Querschnitt)

| Ebene | Werkzeug | Deckt ab |
|---|---|---|
| Unit | swift-testing im `SolixBarTests`-Target | Decoder, History-Mathematik, Breitenbudget, Env-Roundtrip, Theme-Rollen |
| Visuell | Offscreen-Render-Harness (PNG, hell/dunkel) | Dashboard, Graph, Slim-Bar, Settings — Vorher/Nachher-Vergleich |
| On-Screen | AX/AppleScript (Berechtigung erteilt) | Statusitem sichtbar & notch-frei, Menü öffnet, Settings-Roundtrip |
