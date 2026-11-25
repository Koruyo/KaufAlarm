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
	"durst_alarm.ogg",
	"sirene.ogg",
	"traurige_posaune.ogg",
	416, -- Murloc-Gurgeln
}
