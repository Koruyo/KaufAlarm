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
	"coconut-water-song-meme-mp3.mp3",
	"couldn-t-get-no-water-he-died-of-the-dehydration.mp3",
	"durst_alarm.ogg",
	"hello-im-under-the-water_4FMcD6D.mp3",
	"im-going-to-bust-nut-in-water-tower.mp3",
	"its-time-to-drink-water.mp3",
	"may-i-please-have-a-water.mp3",
	"my-seat-is-full-of-water.mp3",
	"sirene.ogg",
	"sorry-marvin-no-water-for-you.mp3",
	"spongebob-meme-sandy-cheeks-ice-cold-water.mp3",
	"still-water-meme-about-still-water.mp3",
	"traurige_posaune.ogg",
	"vls2.mp3",
	"water-ooooooooooooooh-water.mp3",
	"water-water-water-hell.mp3",
	416, -- Murloc-Gurgeln
}
