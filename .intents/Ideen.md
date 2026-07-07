# Ideen

Sammlung von Lösungsvorschlägen/Ansätzen, die noch nicht als Intent geplant sind - meist, weil die
zugrundeliegende Ursache noch nicht bestätigt ist oder die Priorität (noch) nicht gegeben ist.

## Selbstheilung für den Audio-Player bei fehlgeschlagener Permanent-Element-Übernahme (Intent 56)

**Kontext:** Intent 56 hat per Diagnose-Logging bestätigt, dass Haupt- und Cue-Player-Controller
bei *jeder* Turbo-Drive-Navigation zwischen `turbo:before-render` und `turbo:render` disconnecten
und neu connecten (bekannte Turbo-Permanent-Stimulus-Reconnect-Eigenheit) - normalerweise, ohne
dass die Wiedergabe unterbrochen wird. Einmal (nicht reproduzierbar) verstummte der Ton bei genau
so einer Navigation trotzdem. Verdacht: ein selteneres Versagen der Permanent-Element-Übernahme in
genau diesem Fenster, das den `<audio>`-DOM-Knoten durch einen neuen (leeren) ersetzt, statt den
bestehenden (inkl. laufender Wiedergabe) zu übernehmen.

**Warum nicht "die Navigation abbrechen":** Turbo entscheidet synchron während des Renderns, ob ein
Permanent-Element übernommen wird - es gibt keinen Hook, das vorher zu erkennen und den Visit
gezielt zu canceln, ohne die gesamte Seitennavigation zu blockieren.

**Vorschlag - Selbstheilung statt Verhinderung:** Wiedergabe-Zustand (src, currentTime, ob gerade
am Spielen) ausserhalb des DOM zwischenspeichern (z.B. `sessionStorage`, überlebt einen Body-Swap
auch dann, wenn der Permanent-Knoten selbst nicht überlebt). Findet `connect()` danach einen
leeren/unerwarteten `<audio>`-Knoten vor (der Track sollte laut gespeichertem Zustand noch laufen),
Quelle und Position automatisch wiederherstellen und weiterspielen.

**Trade-off:** Kein echtes "nie unterbrochen" - ein kurzer, kaum hörbarer Aussetzer mit
Auto-Recovery statt eines kompletten, dauerhaften Stopps. Dafür ohne Eingriff in Turbos eigene
Navigations-/Cache-Mechanik.

**Status:** Zurückgestellt. Zuerst über das Diagnose-Logging (Intent 56) den tatsächlichen Auslöser
bestätigen, bevor eine Recovery dafür gebaut wird - siehe `.intents/completed/
56.bug_tracks-player_diagnose-audio-aussetzer.md`.

## SuperCollider als DJ-Mixer-Frontend mit bidirektionaler Queue-Sync

**Kontext:** Bei der Diagnose eines Stabilitätsproblems (Wiedergabe brach beim Klick auf einen
externen Spotify-Link ab, behoben in Commit `3a3764b` durch `target="_blank"` auf
`tracks/show.html.erb:18`) wurde diskutiert, den Player komplett aus dem Browser in eine separate
SuperCollider-Applikation zu verlagern - mit einem eigenen GUI dort für DJ-spezifische Regler (Pan,
EQ, Lautstärke pro Kanal), während Musicnet weiterhin Suche/Filter/Queue-Verwaltung übernimmt. Der
eigentliche Stabilitätsbug hatte eine unabhängige, viel einfachere Ursache und ist bereits gelöst -
diese Idee bleibt trotzdem als eigenständige, grössere Erweiterung interessant.

**Vorschlag:** OSC (UDP, sprach-/plattformunabhängig) als Protokoll Rails↔SuperCollider, z. B. via
`osc-ruby` oder handgebaute UDP-Pakete. SuperCollider übernimmt Buffer-Playback sowie Pan/EQ/Gain
per Synth-Args (Kernkompetenz von SC) und bekommt über `Window`/`Slider`/`QListView` ein eigenes
Mixer-GUI. Die Queue wird weiterhin von Musicnet befüllt (bestehendes `QueueEntry`-Modell, Intent
42), kann aber in SuperCollider umsortiert werden - diese Umsortierung müsste zurück nach Musicnet
gespiegelt werden.

**Offene Punkte:**
- Rückkanal SC→Rails (Queue-Reorder, Positions-Feedback) braucht einen dauerhaft laufenden
  UDP-Listener (separater Prozess oder Hintergrund-Thread im Rails-Prozess), der Änderungen per
  Turbo Streams/ActionCable an offene Browser-Tabs weitergibt - analog zum bestehenden
  Broadcast-Muster für Downloads/Queue (Intent 39/42). ActiveRecord-Zugriffe aus diesem Thread
  brauchen `with_connection`; bei geclustertem Puma dürfte nur ein Worker den UDP-Port öffnen. Für
  das aktuelle Single-Prozess-Setup (`bin/rails server -p 3001`) unproblematisch.
- Bidirektionale Queue-Synchronisation ist ein klassisches Dual-Write-Konsistenzproblem (Race, falls
  beide Seiten gleichzeitig ändern) - bei Single-User/lokalem Betrieb klein, aber nicht null. Bei
  konkreter Planung: eine Seite als Source of Truth definieren oder mit Sequenznummern arbeiten.

**Alternative geprüft und verworfen:** Mixxx (bereits im Einsatz für Crate-Export) fernsteuern -
Mixxx hat kein Netzwerk-/OSC-API, nur MIDI-Controller-Scripting (Transport-Controls auf bereits
geladenem Deck-Inhalt). Gezieltes Laden eines bestimmten Tracks aus Musicnet heraus ist darüber
nicht steuerbar; SuperCollider bietet dagegen volle programmatische Kontrolle inkl. Laden.

**Status:** Zurückgestellt, keine Priorität. Reine Idee, noch nicht in eine Intent-Planung überführt.
