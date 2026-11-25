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
		"brr-brr-patapim-alarm-clock.ogg",
		"danger-alarm-sound-effect-meme.ogg",
		"emergency-alert-us-2.ogg",
		"miku-alarm.ogg",
		"nuclear-alarm-siren.ogg",
		"sound-the-alarm.ogg",
		"wake-tf-up.ogg",
		416, -- Murloc-Gurgeln (aus dem Spiel)
	},
	["Munition"] = {
		"cod-waw-zombies-max-ammo-sound_XHA7lsW.ogg",
		"i-need-more-bullets.ogg",
		"i-need-to-find-some-ammunition.ogg",
		"if-your-running-low-on-ammo.ogg",
		"jokerammo.ogg",
		"no-ammo.ogg",
		"reload-gun-sound_CpHCnmK.ogg",
		"scorch-ammo-exhausted.ogg",
		"shooting-a-lot-of-ammo.ogg",
		"solidhornetamc_ability_4c.ogg",
		"tachankaout.ogg",
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
