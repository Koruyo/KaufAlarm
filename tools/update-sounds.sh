#!/usr/bin/env bash
# Trägt alle .ogg- und .mp3-Dateien aus den Unterordnern von "Sounds" in
# Sounds.lua ein. Jeder Unterordner ist eine Sound-Gruppe (Wasser, Munition,
# Allgemein, …), die einem Alarm zugeordnet werden kann. "original" wird
# übersprungen. Nach dem Hinzufügen oder Löschen von Sounds einmal ausführen
# (tools/normalize-sounds.sh macht das automatisch).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
sounds="$root/Sounds"
mkdir -p "$sounds/Allgemein" "$sounds/Wasser" "$sounds/Munition"
count=0

lua_string() {
	local s=${1//\\/\\\\}
	printf '"%s"' "${s//\"/\\\"}"
}

{
	cat <<'EOF'
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
EOF
	while IFS= read -r group; do
		printf '\t[%s] = {\n' "$(lua_string "$group")"
		while IFS= read -r file; do
			printf '\t\t%s,\n' "$(lua_string "$file")"
			count=$((count + 1))
		done < <(find "$sounds/$group" -maxdepth 1 -type f \( -iname '*.ogg' -o -iname '*.mp3' \) -printf '%f\n' | LC_ALL=C sort)
		if [[ "$group" == "Allgemein" ]]; then
			printf '\t\t416, -- Murloc-Gurgeln (aus dem Spiel)\n'
		fi
		printf '\t},\n'
	done < <(find "$sounds" -mindepth 1 -maxdepth 1 -type d ! -name original ! -name '.*' -printf '%f\n' | LC_ALL=C sort)
	printf '}\n'
} > "$root/Sounds.lua.tmp"

mv "$root/Sounds.lua.tmp" "$root/Sounds.lua"
echo "$count Sounddateien in Sounds.lua eingetragen."

loose=$(find "$sounds" -maxdepth 1 -type f \( -iname '*.ogg' -o -iname '*.mp3' \) | wc -l)
if [[ "$loose" -gt 0 ]]; then
	echo "Hinweis: $loose Datei(en) liegen direkt in Sounds/ und werden nicht abgespielt." >&2
	echo "         In einen Unterordner (Wasser, Munition, Allgemein …) verschieben." >&2
fi
