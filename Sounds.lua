-- Sounds, aus denen bei aktiver Warnung zufällig einer abgespielt wird.
--
-- Eigene Sounds: .ogg- oder .mp3-Datei in den Ordner "Sounds" legen und den
-- Dateinamen hier eintragen. WoW kann Ordner nicht selbst durchsuchen, und neue
-- Dateien erkennt das Spiel erst nach einem kompletten Neustart (nicht /reload).
--
-- Eine Zahl statt eines Dateinamens ist ein Sound aus dem Spiel (SoundKit-ID).
local _, ns = ...

ns.sounds = {
	"blubblub.ogg",
	"sirene.ogg",
	"traurige_posaune.ogg",
	"durst_alarm.ogg",
	416, -- Murloc-Gurgeln
}
