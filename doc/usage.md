# Bedienung

## Login

Musicnet ist eine Single-User-App (nur für den einen DJ, der die Spotify-Playlists besitzt). Es
gibt darum kein eigenes App-Konto — auf der Login-Seite gibt es nur den Button "Login mit
Spotify".

## Playlists holen

Auf der Playlists-Seite holt "Fetch all Playlists!" alle eigenen Spotify-Playlists, deren Name
"fusion" oder "blues" enthält, und spiegelt sie (inkl. Tracks, Alben, Künstler) in die lokale
Datenbank. Ein späterer Aufruf synchronisiert nur, was sich auf Spotify geändert hat — unveränderte
Playlists werden übersprungen. Auf der Detailseite einer einzelnen Playlist gleicht "Playlist
aktualisieren" nur diese eine Playlist ab, immer vollständig, auch ohne Änderung.

## Anzeige-Filter (Kategorie)

Unter "Einstellungen" lässt sich einstellen, ob Tracks/Playlists/Artists/Suche "Alle", "Nur Blues"
oder "Nur Fusion" zeigen. Das betrifft ausschliesslich die Anzeige — der Spotify-Sync oben holt
immer weiterhin beide Kategorien.

## Tracks-Suche

Das Suchfeld auf `/tracks` versteht eine kleine Abfragesprache (Freitext, `feld:wert`, Bereiche,
ODER-Verknüpfung, Negation) — siehe den Hilfeartikel [Suche](/help/suche-syntax).

## Song-Queue

Der "+"-Button bei einem Track legt ihn in eine kurze Warteschlange (max. 5 Einträge), sichtbar in
der permanenten Player-Leiste am unteren Bildschirmrand. Von dort lässt sich die Queue auch als
neue, lokale Playlist sichern.

## Cue-/Vorhörkanal

Der "🎧"-Button spielt einen Track über einen zweiten, unabhängigen Audio-Kanal vor — wie der
Kopfhörer-/Cue-Kanal an einem echten DJ-Mixer, ohne die laufende Wiedergabe im Hauptkanal zu
unterbrechen. Haupt- und Cue-Kanal können je ein eigenes Ausgabegerät (z.B. eingebaute Lautsprecher
vs. Kopfhörer) über den jeweiligen "Ausgabegerät wählen"-Link bekommen.

## Download

"Download Tracks" auf einer Playlist bzw. "Download Files" auf `/tracks` lädt die noch fehlenden
Audiodateien über `spotdl` herunter. Bei vielen betroffenen Playlists läuft das im Hintergrund, mit
einem live mitlaufenden Download-Log auf `/tracks`.

## Mixxx-Crates erstellen und importieren

Der Rake-Task `create_crates_lists` (`bin/rails create_crates_lists`) schreibt für jede Playlist
eine `.m3u`-Datei nach `~/Documents/mixxx/`. Vor dem Import in Mixxx müssen die bestehenden Crates
dort manuell gelöscht werden (in Mixxx' eigener `mixxxdb.sqlite`, Tabellen `crates` und
`crate_tracks`), danach lassen sich die frischen `.m3u`-Dateien über Mixxx' Oberfläche importieren
(Crates-Ordner, rechte Maustaste).
