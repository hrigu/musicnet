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
voneinander gibt es keine reine Freitext-Syntax — es gibt aber ein echtes
Kriterien-ODER für Feld-Kriterien wie `genre:` (siehe "Kriterien mit ODER
verknüpfen" unten), z.B. `genre:blues OR genre:shuffle`.

## Felder

| Feld | Beispiel |
|---|---|
| `artist:` | `artist:davis` |
| `album:` | `album:"kind of blue"` |
| `genre:` | `genre:jazz` |
| `playlist:` | `playlist:"Fusion Abende"` |
| `bpm:` / `tempo:` | `bpm:80..100` |
| `energy:` | `energy:50..80` |
| `popularity:` | `popularity:>50` |
| `year:` / `release:` | `year:2015` |
| `tag:` | `tag:traurig` |

## Tags

`tag:` sucht Tracks, denen ein Tag mit diesem Namen zugeordnet ist (z.B.
`tag:traurig`), genau wie `playlist:` bei Playlist-Namen. Mehrfaches Vorkommen
(`tag:traurig tag:tanzbar`) verlangt wie bei `playlist:`/`artist:` beide Tags
gleichzeitig (Schnittmenge), da ein Track mehrere Tags gleichzeitig haben kann.

Es gibt aktuell **keine** Möglichkeit, nach der Tag-*Stärke* (1-10) zu filtern
oder zu sortieren — nur danach, ob ein Tag überhaupt zugeordnet ist. Die Stärke
wird nur in der Tags-Spalte der Trackliste angezeigt.

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

## Kriterien mit ODER verknüpfen

Das Schlüsselwort `OR` (**gross**geschrieben) verknüpft zwei Kriterien mit ODER:

```
genre:pop OR genre:techno
```

`OR` bindet **schwächer** als das Leerzeichen-UND (wie bei Mixxx) — alles links
und rechts von `OR` wird zuerst für sich mit UND ausgewertet, erst danach werden
die beiden Seiten mit ODER verbunden:

```
genre:jazz bpm:>140 OR playlist:"Chill"
```

heisst also **(Genre Jazz UND Tempo über 140) ODER in der Playlist "Chill"**,
nicht "Genre Jazz UND (Tempo über 140 ODER in der Playlist Chill)". Es gibt keine
Klammerung, um diese Reihenfolge zu ändern (siehe "Was nicht geht" unten).

Ein kleingeschriebenes `or` ist **kein** Operator und wird wie jedes andere Wort
als Freitext behandelt. Ein `OR` innerhalb von Anführungszeichen
(`artist:"Air OR Water"`) ist ebenfalls kein Operator, sondern Teil des Werts.

Ein führendes, abschliessendes oder doppeltes `OR` (z.B. aus Versehen) wird
einfach ignoriert, es gibt keinen Fehler.

## Mehrfaches Vorkommen desselben Feldes (UND)

Zwei `playlist:`-Tokens verlangen, dass ein Track in **beiden** Playlists vorkommt
(Schnittmenge, nicht Vereinigung):

```
playlist:"Fusion Abende" playlist:"Blues Session"
```

Das funktioniert so nur bei Feldern, bei denen ein Track mehrere Werte gleichzeitig
haben kann (`artist`, `playlist`, `tag`). Bei einwertigen Feldern (`genre`, `bpm`/`tempo`,
`energy`, `popularity`, `year`/`release`, `album`) ergibt eine Wiederholung keinen
Sinn — ein Track hat z.B. nur ein Genre, `genre:jazz genre:blues` liefert darum
korrekterweise keine Treffer (kein Track kann beides gleichzeitig sein).

## Werte mit Leerzeichen

Werte mit Leerzeichen (Künstler-, Album- oder Playlist-Namen) müssen in
Anführungszeichen stehen:

```
artist:"James Cotton"
```

**Ein Leerzeichen nach dem Doppelpunkt ist erlaubt**, solange danach **ein
einzelnes Wort** oder **eine gequotete Phrase** folgt:

```
artist: davis
artist: "James Cotton"
```

funktionieren beide genau wie `artist:davis` bzw. `artist:"James Cotton"`. Das
gilt nur für bekannte Felder — ein Doppelpunkt in einem normalen Freitext (z.B.
ein Tracktitel wie "Blues: The Story") wird nicht fälschlich zu einem Feld
zusammengeführt, da "blues" kein bekanntes Feld ist.

**Bekannte Grenze:** ein **ungequotetes, mehrwortiges** Leerzeichen-Wert bleibt
weiterhin mehrdeutig — `artist: James Cotton` (ohne Anführungszeichen) ist
**nicht** garantiert dasselbe wie `artist:"James Cotton"`, da unklar ist, wo der
Wert endet. Für einen mehrwortigen Wert nach einem Leerzeichen also immer
Anführungszeichen verwenden:

```
artist: "James Cotton"
```

## Unbekannte Felder und ungültige Werte

Ein unbekanntes Feld (z.B. `composer:`, das es aktuell nicht gibt) wird als
Freitext behandelt. Ein ungültiger Wert für ein bekanntes Zahlen-Feld (z.B.
`bpm:abc`) wird stillschweigend ignoriert. Beides führt nie zu einem Fehler.

## Was nicht geht

* **ODER zwischen Freitext-Wörtern.** Anders als ODER zwischen Kriterien (siehe
  "Kriterien mit ODER verknüpfen" oben) gibt es kein "Wort A ODER Wort B" für
  reinen Freitext ohne Feld — mehrere Freitext-Wörter werden immer zu einem
  zusammenhängenden Suchtext zusammengesetzt (siehe Abschnitt "Freitext" oben).
* **UND zwischen mehreren Werten innerhalb eines Tokens per Leerzeichen.**
  `artist:James Otis` ist **nicht** "Künstler James UND Otis" — das Leerzeichen
  beendet den Token, `James` wird zum eigenständigen Feld-Wert und `Otis` zu einem
  separaten Freitext-Wort. Ein UND über mehrere Werte desselben Feldes geht nur
  durch Wiederholen des ganzen Feldes (siehe "Mehrfaches Vorkommen" oben), und
  auch nur bei mehrwertigen Feldern (`artist`, `playlist`, `tag`).
* **Klammerung/Gruppierung.** Es gibt keine Möglichkeit, Kriterien zu gruppieren
  (z.B. "(A oder B) und C") — die Sprache kennt nur die flache Verknüpfung aus
  Leerzeichen-UND, Komma-ODER innerhalb eines Feldes und `OR` zwischen Kriterien,
  in dieser festen Präzedenz.

## Alles kombiniert

```
genre:jazz,fusion bpm:80..100 -genre:blues playlist:"Fusion Abende"
```

Ein Beispiel mit ODER (Komma) und NOT (`-`) kombiniert — Jazz oder Fusion, aber
nicht von Miles Davis:

```
genre:jazz,fusion -artist:"Miles Davis"
```
