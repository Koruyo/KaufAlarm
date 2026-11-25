# KaufWasser

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

## Sounds

Solange eine Warnung sichtbar ist, spielt ein Sound sofort und dann in der eingestellten
Wiederholrate (10–300 Sekunden). Auf der Seite *Sounds* hakst du an, welche Sounds dabei sind,
und kannst jeden probehören. Auf der Hauptseite wählst du die Reihenfolge (zufällig oder der
Reihe nach) und den Lautstärke-Regler (Gesamt, Effekte, Dialog, Umgebung, Musik).

Eigene Sounds: `.mp3`-, `.wav`- oder andere Audiodateien in den Ordner `Sounds` legen und
`tools/normalize-sounds.sh` ausführen. Das Skript gleicht die Lautstärke an (−16 LUFS, damit
kein Clip viel lauter oder leiser ist als die anderen), speichert sie als `.ogg`, legt die
Originale nach `Sounds/original/` und trägt alles in [Sounds.lua](Sounds.lua) ein. Danach WoW
komplett neu starten, `/reload` reicht für neue Dateien nicht. Neue Sounds sind automatisch
angehakt.

## Minimap, Broker-Leisten und Addon-Fach

- **Minimap-Knopf:** Linksklick öffnet die Optionen, Rechtsklick schaltet den Sound an/aus,
  Shift-Klick testet die Warnung. Ziehbar, ausblendbar mit `/kw minimap` oder in den Optionen.
- **Titan Panel, ChocolateBar, Bazooka, ElvUI usw.:** Ist LibDataBroker geladen, erscheint der
  Eintrag *KaufWasser* mit den Vorräten aller Alarme, z. B. `37 · 1400`, rot unter der Grenze.
- **Minimap-Addons:** Ist LibDBIcon geladen, übernimmt es den Knopf.
- **Addon-Fach:** KaufWasser steht im Addon-Menü an der Minimap, wo es der Client anbietet.

Das Addon bringt selbst keine Bibliotheken mit und läuft ohne sie mit eigenem Knopf.

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/kw` | Optionen öffnen |
| `/kw test` | Warnung und Sound testen |
| `/kw move` | Text verschieben bzw. wieder fixieren |
| `/kw reset` | Position zurücksetzen |
| `/kw sound` | Sound an/aus |
| `/kw combat` | Anzeige im Kampf an/aus |
| `/kw minimap` | Minimap-Knopf an/aus |
| `/kw status` | Stand aller Alarme |

## Installation

Den Ordner als `KaufWasser` in den AddOns-Ordner des Spiels verlinken oder kopieren, z. B.:

```bash
ln -s ~/Projekte/KaufWasser "~/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/KaufWasser"
```

## Test

```bash
luajit tests/mocktest.lua
```

Prüft Logik und Optionen mit einer nachgebauten WoW-API, einmal ohne und einmal mit
Broker-Bibliotheken, dazu die Übernahme der Einstellungen aus Version 1.x.

Die mitgelieferten Sounds sind mit `tools/make-sounds.sh` (ffmpeg) erzeugt und angeglichen.
