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
