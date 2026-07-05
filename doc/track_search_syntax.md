# Suche-Syntax

Das Suchfeld auf `/tracks` versteht eine kleine Abfragesprache. Alles, was durch ein
Leerzeichen getrennt ist — egal ob unterschiedliche Felder oder dasselbe Feld
mehrfach — wird **UND**-verknüpft. Das gilt ausnahmslos, auch für das weiter unten
beschriebene "Mehrfaches Vorkommen desselben Feldes": das ist kein Sonderfall,
sondern einfach dieselbe Leerzeichen-UND-Regel.

## Freitext

Ein Wort ohne `feld:`-Präfix sucht wie eine normale Volltextsuche über Name,
Künstler, Album, Genre und Playlist-Name.

```
blues shuffle
```

**Wichtig:** Mehrere Freitext-Wörter werden **nicht** einzeln mit ODER verglichen
— sie werden zu einem einzigen, zusammenhängenden Suchtext zusammengesetzt. Das
Beispiel oben findet also Treffer, bei denen der Text "blues shuffle" **in dieser
Reihenfolge, direkt hintereinander** in einem der Felder vorkommt (Gross-/
Kleinschreibung egal) — z.B. "RSpec Blues Shuffle". Ein Track, der nur "Blues" im
Genre und "Shuffle" im Namen hat, aber nirgends den zusammenhängenden Text "blues
shuffle", wird **nicht** gefunden. Für "blues ODER shuffle" unabhängig
voneinander gibt es aktuell keine Syntax — das wäre eine echte ODER-Verknüpfung
zwischen Kriterien (siehe "Was nicht geht" unten).

## Felder

| Feld | Beispiel |
|---|---|
| `artist:` | `artist:davis` |
| `album:` | `album:"kind of blue"` |
| `genre:` | `genre:jazz` |
| `playlist:` | `playlist:"Fusion Abende"` |
| `bpm:` / `tempo:` | `bpm:80..100` |
| `energy:` | `energy:0.5..0.8` |
| `popularity:` | `popularity:>50` |
| `year:` / `release:` | `year:2015` |

## Mehrere Werte (ODER)

Ein Komma innerhalb eines Feldes verknüpft mehrere Werte mit ODER:

```
genre:jazz,fusion,blues
```

## Bereiche und Vergleiche

Für Zahlen-/Jahres-Felder (`bpm`/`tempo`, `energy`, `popularity`, `year`/`release`):

```
bpm:80..100      (zwischen 80 und 100, Grenzen eingeschlossen)
popularity:>50   (grösser 50)
year:>=2015      (ab 2015)
```

Erlaubte Vergleichsoperatoren: `>`, `>=`, `<`, `<=`.

## Negation

Ein `-` vor dem Feld schliesst Treffer aus:

```
-genre:blues
```

## Mehrfaches Vorkommen desselben Feldes (UND)

Zwei `playlist:`-Tokens verlangen, dass ein Track in **beiden** Playlists vorkommt
(Schnittmenge, nicht Vereinigung):

```
playlist:"Fusion Abende" playlist:"Blues Session"
```

Das funktioniert so nur bei Feldern, bei denen ein Track mehrere Werte gleichzeitig
haben kann (`artist`, `playlist`). Bei einwertigen Feldern (`genre`, `bpm`/`tempo`,
`energy`, `popularity`, `year`/`release`, `album`) ergibt eine Wiederholung keinen
Sinn — ein Track hat z.B. nur ein Genre, `genre:jazz genre:blues` liefert darum
korrekterweise keine Treffer (kein Track kann beides gleichzeitig sein).

## Werte mit Leerzeichen

Werte mit Leerzeichen (Künstler-, Album- oder Playlist-Namen) müssen in
Anführungszeichen stehen:

```
artist:"James Cotton"
```

**Wichtig:** Zwischen `feld:` und dem Wert darf **kein Leerzeichen** stehen, auch
nicht vor Anführungszeichen. `artist: James Cotton` (mit Leerzeichen nach dem
Doppelpunkt) wird **nicht** als Feld erkannt, sondern als Freitext behandelt und
findet in der Regel nichts. Richtig ist:

```
artist:"James Cotton"
```

## Unbekannte Felder und ungültige Werte

Ein unbekanntes Feld (z.B. `composer:`, das es aktuell nicht gibt) wird als
Freitext behandelt. Ein ungültiger Wert für ein bekanntes Zahlen-Feld (z.B.
`bpm:abc`) wird stillschweigend ignoriert. Beides führt nie zu einem Fehler.

## Was nicht geht

* **ODER zwischen unterschiedlichen Kriterien.** `genre:jazz OR bpm:>140` sucht
  nicht "Jazz ODER schnell" — `OR` wird einfach als Freitext-Wort behandelt und
  beide Seiten bleiben wie immer UND-verknüpft. ODER gibt es nur innerhalb eines
  einzelnen Feldes, per Komma (siehe oben).
* **UND zwischen mehreren Werten innerhalb eines Tokens per Leerzeichen.**
  `artist:James Otis` ist **nicht** "Künstler James UND Otis" — das Leerzeichen
  beendet den Token, `James` wird zum eigenständigen Feld-Wert und `Otis` zu einem
  separaten Freitext-Wort. Ein UND über mehrere Werte desselben Feldes geht nur
  durch Wiederholen des ganzen Feldes (siehe "Mehrfaches Vorkommen" oben), und
  auch nur bei mehrwertigen Feldern (`artist`, `playlist`).
* **Klammerung/Gruppierung.** Es gibt keine Möglichkeit, Kriterien zu gruppieren
  (z.B. "(A oder B) und C") — die Sprache kennt nur die flache Leerzeichen-UND-
  Verknüpfung plus Komma-ODER innerhalb eines Feldes.

## Alles kombiniert

```
genre:jazz,fusion bpm:80..100 -genre:blues playlist:"Fusion Abende"
```

Ein Beispiel mit ODER (Komma) und NOT (`-`) kombiniert — Jazz oder Fusion, aber
nicht von Miles Davis:

```
genre:jazz,fusion -artist:"Miles Davis"
```
