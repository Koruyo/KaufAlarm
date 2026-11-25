# KaufAlarm

WoW-Addon: zeigt groß **KAUF WASSER DU HUANSOHN!** auf dem Bildschirm, sobald dir Wasser,
Munition oder etwas anderes ausgeht, und spielt dazu regelmäßig einen Sound.

## Alarme

Jeder Alarm zählt eine Liste von Items zusammen und warnt unter seiner Grenze. Voreingestellt:

| Alarm | zählt | Grenze | für |
| --- | --- | --- | --- |
| Wasser | Trichterwindentau (8766), Kristallwasser (8079), Sprudelwasser (8078) | 40 | Klassen mit Mana ab Stufe 45 |
| Munition | die ausgerüstete Munition, egal welche Sorte | 1000 | Jäger ab Stufe 10 |

In den Optionen unter *Alarme* lässt sich für jeden Alarm einstellen: an/aus, Name, Warntext,
Grenze, Mindeststufe, „nur Klassen mit Mana“, „ausgerüstete Munition mitzählen“, Klassenauswahl
und die Item-Liste. Items fügst du per Shift-Klick, Item-Link, Item-ID oder Namen hinzu.
Weitere Alarme (Seelensplitter, Reagenzien, Essen, Verbände …) legst du mit *Neuer Alarm* an.

Warnen mehrere Alarme gleichzeitig, stehen ihre Texte untereinander.

Im Kampf und in Dungeons, Raids, Schlachtfeldern und Arenen bleibt der Alarm still – weder Text
noch Sound. Beides lässt sich auf der Hauptseite der Optionen (oder mit `/ka combat` und
`/ka instanz`) einschalten.

## Sounds

Die Sounds liegen nach Gruppen in Unterordnern von `Sounds/`:

| Ordner | gehört zu |
| --- | --- |
| `Sounds/Wasser/` | Alarm *Wasser* |
| `Sounds/Munition/` | Alarm *Munition* |
| `Sounds/Allgemein/` | neuen Alarmen; springt ein, wenn eine Gruppe leer ist (enthält den Murloc aus dem Spiel) |

Jeder Alarm wählt seine Gruppe in den Optionen (*Alarme → Sounds: …*). Ein neuer Unterordner
wird automatisch zu einer weiteren Gruppe.

Solange eine Warnung sichtbar ist, spielt ein Sound sofort und dann in der eingestellten
Wiederholrate (5–300 Sekunden, voreingestellt 15,25 – etwas länger als der längste Clip). Warnen
mehrere Alarme gleichzeitig, kommen ihre Sounds abwechselnd. Auf der Seite *Sounds* hakst du je
Gruppe an, welche Sounds dabei sind, und kannst jeden probehören. Auf der Hauptseite wählst du
die Reihenfolge (zufällig oder der Reihe nach) und den Lautstärke-Regler (Gesamt, Effekte,
Dialog, Umgebung, Musik).

Die Meme-Clips sind nicht im Git, nur ihre Einträge in Sounds.lua. Fehlt eine Datei, gurgelt
stattdessen ein Murloc.

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

## Test

```bash
luajit tests/mocktest.lua
```

Prüft Logik und Optionen mit einer nachgebauten WoW-API, einmal ohne und einmal mit
Broker-Bibliotheken, dazu die Übernahme der Einstellungen aus Version 1.x.

Das Icon wird mit `tools/make-icon.sh` aus [Media/icon.svg](Media/icon.svg) erzeugt.
