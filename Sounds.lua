-- Sounds, die bei aktiver Warnung abgespielt werden (Auswahl in den Optionen).
--
-- Diese Datei wird von tools/update-sounds.sh erzeugt: Audiodatei in den Ordner
-- "Sounds" legen, tools/normalize-sounds.sh ausführen, WoW komplett neu starten (neue
-- Dateien erkennt das Spiel nicht per /reload).
--
-- Eine Zahl statt eines Dateinamens ist ein Sound aus dem Spiel (SoundKit-ID).
local _, ns = ...

ns.sounds = {
	"coconut-water-song-meme-mp3.ogg",
	"hello-im-under-the-water_4FMcD6D.ogg",
	"im-going-to-bust-nut-in-water-tower.ogg",
	"its-time-to-drink-water.ogg",
	"may-i-please-have-a-water.ogg",
	"my-seat-is-full-of-water.ogg",
	"sorry-marvin-no-water-for-you.ogg",
	"spongebob-meme-sandy-cheeks-ice-cold-water.ogg",
	"still-water-meme-about-still-water.ogg",
	"vls2.ogg",
	"water-ooooooooooooooh-water.ogg",
	"water-water-water-hell.ogg",
	416, -- Murloc-Gurgeln (aus dem Spiel)
}
