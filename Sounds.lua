-- Sounds, aus denen bei aktiver Warnung zufällig einer abgespielt wird.
--
-- Diese Datei wird von tools/update-sounds.sh erzeugt: .ogg- oder .mp3-Datei in
-- den Ordner "Sounds" legen, Skript ausführen, WoW komplett neu starten (neue
-- Dateien erkennt das Spiel nicht per /reload).
--
-- Eine Zahl statt eines Dateinamens ist ein Sound aus dem Spiel (SoundKit-ID).
local _, ns = ...

ns.sounds = {
	"blubblub.ogg",
	"coconut-water-song-meme-mp3.ogg",
	"durst_alarm.ogg",
	"hello-im-under-the-water_4FMcD6D.ogg",
	"im-going-to-bust-nut-in-water-tower.ogg",
	"its-time-to-drink-water.ogg",
	"may-i-please-have-a-water.ogg",
	"my-seat-is-full-of-water.ogg",
	"sirene.ogg",
	"sorry-marvin-no-water-for-you.ogg",
	"spongebob-meme-sandy-cheeks-ice-cold-water.ogg",
	"still-water-meme-about-still-water.ogg",
	"traurige_posaune.ogg",
	"vls2.ogg",
	"water-ooooooooooooooh-water.ogg",
	"water-water-water-hell.ogg",
	416, -- Murloc-Gurgeln
}
