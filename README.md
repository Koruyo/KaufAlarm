# KaufWasser

WoW-Classic-Addon: zeigt groß **KAUF WASSER DU HUANSOHN!** auf dem Bildschirm, sobald weniger
als 40 vom besten Wasser im Gepäck sind, und spielt dazu jede Minute einen zufälligen Sound.

Gezählt werden zusammen:

- Trichterwindentau (Item 8766)
- Herbeigezaubertes Kristallwasser (8079) und Sprudelwasser (8078) vom Magier

Gewarnt wird nur bei Klassen mit Mana, ab Stufe 45 und standardmäßig nicht im Kampf.

## Minimap, Broker-Leisten und Addon-Fach

- **Minimap-Knopf:** Linksklick öffnet die Optionen, Rechtsklick schaltet den Sound an/aus,
  Shift-Klick testet die Warnung. Der Knopf lässt sich um die Minimap ziehen und mit
  `/kw minimap` oder in den Optionen ausblenden.
- **Titan Panel, ChocolateBar, Bazooka, ElvUI usw.:** Ist LibDataBroker geladen (bringen diese
  Leisten mit), erscheint der Eintrag *KaufWasser* mit der Zahl deiner Wasser, rot unter der
  Grenze. Tooltip und Klicks wie beim Minimap-Knopf.
- **Minimap-Addons:** Ist LibDBIcon geladen, übernimmt es den Minimap-Knopf, damit Addons wie
  MinimapButtonBag ihn einsammeln können.
- **Addon-Fach:** KaufWasser steht im Addon-Menü an der Minimap, wo es der Client anbietet.

Das Addon bringt selbst keine Bibliotheken mit und läuft ohne sie mit eigenem Knopf.

## Optionen

`/kw` oder Linksklick auf den Knopf öffnet die Optionen unter *Einstellungen → AddOns →
KaufWasser*: Grenze, Schriftgröße, Anzeige im Kampf, Sound an/aus und Intervall, Minimap-Knopf,
Testen, Verschieben und Position zurücksetzen.

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
| `/kw reset` | Position zurücksetzen |
| `/kw minimap` | Minimap-Knopf an/aus |
| `/kw size 64` | Schriftgröße |
| `/kw sound` | Sound an/aus |
| `/kw combat` | Anzeige im Kampf an/aus |
| `/kw add [Item]` / `/kw remove [Item]` | weiteres Wasser mitzählen (Item-Link oder ID) |
| `/kw status` | aktueller Stand |

## Eigene Sounds

`.ogg`- oder `.mp3`-Dateien in den Ordner `Sounds` legen und `tools/update-sounds.sh` ausführen.
Das Skript trägt alle Dateien aus dem Ordner in [Sounds.lua](Sounds.lua) ein. Danach WoW komplett
neu starten, `/reload` reicht für neue Dateien nicht.

Die mitgelieferten Sounds sind mit `tools/make-sounds.sh` (ffmpeg) erzeugt.

## Test

```bash
luajit tests/mocktest.lua
```

Prüft die Logik mit einer nachgebauten WoW-API, einmal ohne und einmal mit Broker-Bibliotheken.
