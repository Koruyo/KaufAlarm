#!/usr/bin/env bash
# Trägt alle .ogg- und .mp3-Dateien aus dem Ordner "Sounds" in Sounds.lua ein.
# Nach dem Hinzufügen oder Löschen von Sounds einmal ausführen.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
count=0

{
	cat <<'EOF'
-- Sounds, die bei aktiver Warnung abgespielt werden (Auswahl in den Optionen).
--
-- Diese Datei wird von tools/update-sounds.sh erzeugt: Audiodatei in den Ordner
-- "Sounds" legen, tools/normalize-sounds.sh ausführen, WoW komplett neu starten (neue
-- Dateien erkennt das Spiel nicht per /reload).
--
-- Eine Zahl statt eines Dateinamens ist ein Sound aus dem Spiel (SoundKit-ID).
local _, ns = ...

ns.sounds = {
EOF
	while IFS= read -r file; do
		escaped=${file//\\/\\\\}
		escaped=${escaped//\"/\\\"}
		printf '\t"%s",\n' "$escaped"
		count=$((count + 1))
	done < <(find "$root/Sounds" -maxdepth 1 -type f \( -iname '*.ogg' -o -iname '*.mp3' \) -printf '%f\n' | LC_ALL=C sort)
	printf '\t416, -- Murloc-Gurgeln (aus dem Spiel)\n}\n'
} > "$root/Sounds.lua.tmp"

mv "$root/Sounds.lua.tmp" "$root/Sounds.lua"
echo "$count Sounddateien in Sounds.lua eingetragen."
