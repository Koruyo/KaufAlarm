-- Sounds, die bei aktiver Warnung abgespielt werden, nach Gruppen. Jeder Alarm
-- wählt in den Optionen seine Gruppe; ist sie leer, kommt "Allgemein" dran.
--
-- Diese Datei wird von tools/update-sounds.sh erzeugt: Audiodatei in den
-- passenden Unterordner von "Sounds" legen, tools/normalize-sounds.sh
-- ausführen, WoW komplett neu starten (neue Dateien erkennt das Spiel nicht
-- per /reload). Ein neuer Unterordner wird zu einer neuen Gruppe.
--
-- Eine Zahl statt eines Dateinamens ist ein Sound aus dem Spiel (SoundKit-ID).
local _, ns = ...

ns.sounds = {
	["Allgemein"] = {
		416, -- Murloc-Gurgeln (aus dem Spiel)
	},
	["Munition"] = {
	},
	["Wasser"] = {
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
	},
}
