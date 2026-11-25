# KaufWasser

WoW-Classic-Addon: zeigt groß **KAUF WASSER DU HUANSOHN!** auf dem Bildschirm, sobald weniger
als 40 vom besten Wasser im Gepäck sind, und spielt dazu jede Minute einen zufälligen Sound.

Gezählt werden zusammen:

- Trichterwindentau (Item 8766)
- Herbeigezaubertes Kristallwasser (8079) und Sprudelwasser (8078) vom Magier

Gewarnt wird nur bei Klassen mit Mana, ab Stufe 45 und standardmäßig nicht im Kampf.

## Installation

Den Ordner als `KaufWasser` nach `World of Warcraft/_classic_era_/Interface/AddOns/` kopieren
oder verlinken.

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/kw` | Optionen öffnen |
| `/kw 40` | Grenze setzen |
| `/kw test` | Warnung und Sound testen |
| `/kw move` | Text verschieben bzw. wieder fixieren |
| `/kw size 64` | Schriftgröße |
| `/kw sound` | Sound an/aus |
| `/kw combat` | Anzeige im Kampf an/aus |
| `/kw add [Item]` / `/kw remove [Item]` | weiteres Wasser mitzählen (Item-Link oder ID) |
| `/kw status` | aktueller Stand |

## Eigene Sounds

`.ogg`- oder `.mp3`-Datei in den Ordner `Sounds` legen und den Dateinamen in
[Sounds.lua](Sounds.lua) eintragen. Danach WoW komplett neu starten, `/reload` reicht für neue
Dateien nicht.

Die mitgelieferten Sounds sind mit `tools/make-sounds.sh` (ffmpeg) erzeugt.
