# KaufAlarm

WoW-Addon: zeigt groß **KAUF WASSER DU HUANSOHN!** auf dem Bildschirm, sobald dir Wasser,
Munition, Gifte oder etwas anderes ausgeht – oder du als Schurke vergessen hast, deine Waffen zu
vergiften – und spielt dazu regelmäßig einen Sound.

## Alarme

Jeder Alarm zählt eine Liste von Items zusammen und warnt unter seiner Grenze. Voreingestellt:

| Alarm | zählt | Grenze | für |
| --- | --- | --- | --- |
| Wasser | Trichterwindentau (8766), Kristallwasser (8079), Sprudelwasser (8078) | 40 | Klassen mit Mana ab Stufe 45 |
| Munition | die ausgerüstete Munition, egal welche Sorte | 600 | Jäger ab Stufe 10 |
| Gift auf Waffe | Gift auf Waffen- und Schildhand (Schilde zählen nicht) | 5 Minuten Restlaufzeit | Schurken ab Stufe 20 |
| Gifte | alle Ränge von Sofort wirkendem, Tödlichem, Verkrüppelndem, Gedankenbenebelndem und Wundgift | 5 | Schurken ab Stufe 20 |

*Gift auf Waffe* warnt nur im Kampf, dafür überall – auch in Dungeons, Raids und Schlachtfeldern –, sobald eine Waffe gar kein Gift hat oder es in weniger als
5 Minuten ausläuft, und nennt in der Zeile darunter die Hand, z. B. `Waffenhand: 30 min, Schildhand: kein Gift`.

In den Optionen unter *Alarme* lässt sich für jeden Alarm einstellen: an/aus, Name, Warntext,
Grenze, Mindeststufe, „nur Klassen mit Mana“, was geprüft wird (Items im Gepäck, dazu die
ausgerüstete Munition, oder das Gift auf den Waffen), wann im Kampf gewarnt wird (wie auf der
Hauptseite, nur im Kampf oder immer), ob er auch in Dungeons, Raids und Schlachtfeldern warnt,
Klassenauswahl und die Item-Liste. Items fügst du per Shift-Klick, Item-Link, Item-ID oder Namen hinzu.
Weitere Alarme (Seelensplitter, Reagenzien, Essen, Verbände …) legst du mit *Neuer Alarm* an.

Warnen mehrere Alarme gleichzeitig, stehen ihre Texte untereinander.

Im Kampf (außer bei Alarmen auf „nur im Kampf“ oder „immer“) und in Dungeons, Raids,
Schlachtfeldern und Arenen (außer bei Alarmen mit dem Haken „Auch in Dungeons, Raids,
Schlachtfeldern“, z. B. *Gift auf Waffe*) bleibt der Alarm still – weder Text
noch Sound. Beides lässt sich auf der Hauptseite der Optionen (oder mit `/ka combat` und
`/ka instanz`) einschalten.

## Sounds

Die Sounds liegen nach Gruppen in Unterordnern von `Sounds/`:

| Ordner | gehört zu |
| --- | --- |
| `Sounds/Wasser/` | Alarm *Wasser* |
| `Sounds/Munition/` | Alarm *Munition* |
| `Sounds/Gift/` | Alarme *Gift auf Waffe* und *Gifte* (Brr Brr Patapim) |
| `Sounds/Allgemein/` | neuen Alarmen; springt ein, wenn eine Gruppe leer ist (enthält den Murloc aus dem Spiel) |

Jeder Alarm wählt seine Gruppe in den Optionen (*Alarme → Sounds: …*). Ein neuer Unterordner
wird automatisch zu einer weiteren Gruppe.

Solange eine Warnung sichtbar ist, spielt ein Sound sofort und dann in der eingestellten
Wiederholrate (5–300 Sekunden, voreingestellt 15,25 – etwas länger als der längste Clip). Warnen
mehrere Alarme gleichzeitig, kommen ihre Sounds abwechselnd. Auf der Seite *Sounds* hakst du je
Gruppe an, welche Sounds dabei sind, und kannst jeden probehören. Auf der Hauptseite wählst du
die Reihenfolge (zufällig oder der Reihe nach) und den Lautstärke-Regler (Gesamt, Effekte,
Dialog, Umgebung, Musik).

Die angeglichenen `.ogg`-Clips sind im Git und kommen mit ins Release, die Originale in
`Sounds/original/` nicht. Fehlt eine Datei, gurgelt stattdessen ein Murloc.

Neue Sounds: `.mp3`-, `.wav`- oder andere Audiodateien in den passenden Gruppen-Ordner legen
und `tools/normalize-sounds.sh` ausführen. Das Skript gleicht die Lautstärke an (−16 LUFS, damit
kein Clip viel lauter oder leiser ist als die anderen), speichert sie als `.ogg`, legt die
Originale nach `Sounds/original/<Gruppe>/` und trägt alles in [Sounds.lua](Sounds.lua) ein.
Danach WoW komplett neu starten, `/reload` reicht für neue Dateien nicht. Neue Sounds sind
automatisch angehakt.

## Minimap, Broker-Leisten und Addon-Fach

- **Minimap-Knopf:** Linksklick öffnet die Optionen, Rechtsklick schaltet den Sound an/aus,
  Shift-Klick testet die Warnung. Ziehbar, ausblendbar mit `/ka minimap` oder in den Optionen.
- **Titan Panel, ChocolateBar, Bazooka, ElvUI usw.:** Ist LibDataBroker geladen, erscheint der
  Eintrag *KaufAlarm* mit den Vorräten aller Alarme, z. B. `37 · 1400`, rot unter der Grenze.
- **Minimap-Addons:** Ist LibDBIcon geladen, übernimmt es den Knopf.
- **Addon-Fach:** KaufAlarm steht im Addon-Menü an der Minimap, wo es der Client anbietet.

Das Addon bringt selbst keine Bibliotheken mit und läuft ohne sie mit eigenem Knopf.

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/ka` | Optionen öffnen |
| `/ka test` | Warnung und Sound testen |
| `/ka move` | Text verschieben bzw. wieder fixieren |
| `/ka reset` | Position zurücksetzen |
| `/ka sound` | Sound an/aus |
| `/ka combat` | Anzeige im Kampf an/aus |
| `/ka instanz` | Anzeige in Dungeons, Raids und Schlachtfeldern an/aus |
| `/ka minimap` | Minimap-Knopf an/aus |
| `/ka status` | Stand aller Alarme |

## Installation

Den Ordner als `KaufAlarm` in den AddOns-Ordner des Spiels verlinken oder kopieren, z. B.:

```bash
ln -s "$HOME/Projekte/KaufAlarm" "$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/KaufAlarm"
```

## Release

Ein Tag wie `v1.5.0` baut über GitHub Actions ([BigWigs packager](https://github.com/BigWigsMods/packager))
ein Zip mit Code, Icon und allen Sounds und hängt es an ein GitHub-Release. `tests/`, `tools/`,
`Media/icon.svg` und die README bleiben draußen (siehe [.pkgmeta](.pkgmeta)).

## Test

```bash
luajit tests/mocktest.lua
```

Prüft Logik und Optionen mit einer nachgebauten WoW-API, einmal ohne und einmal mit
Broker-Bibliotheken, dazu die Übernahme der Einstellungen aus Version 1.x.

Das Icon wird mit `tools/make-icon.sh` aus [Media/icon.svg](Media/icon.svg) erzeugt.
