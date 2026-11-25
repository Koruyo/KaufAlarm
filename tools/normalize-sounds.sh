#!/usr/bin/env bash
# Gleicht die Lautstärke der Sounds an und speichert sie als .ogg.
#
#   normalize-sounds.sh          jede .mp3/.wav/.flac/.m4a/.opus-Datei in den
#                                Gruppen-Ordnern (Sounds/Wasser, Sounds/Munition,
#                                Sounds/Allgemein, …) angleichen; die .ogg ersetzt
#                                sie, das Original wandert nach
#                                Sounds/original/<Gruppe>/ (wird nicht geladen).
#                                Dateien direkt in Sounds/ landen in "Allgemein".
#   normalize-sounds.sh --all    dazu auch alle vorhandenen .ogg neu angleichen
#
# Zum Schluss wird Sounds.lua neu erzeugt. Braucht ffmpeg.
# Ziel: -16 LUFS Lautheit, Spitzen höchstens -1.5 dBTP.
set -euo pipefail

TARGET_I=-16
TARGET_TP=-1.5
TARGET_LRA=11

root="$(cd "$(dirname "$0")/.." && pwd)"
sounds="$root/Sounds"
originals="$sounds/original"
all=false
[[ "${1:-}" == "--all" ]] && all=true

# Gemessene Lautheit (LUFS) einer Datei
loudness() {
	ffmpeg -hide_banner -nostats -i "$1" -map 0:a:0 -af ebur128 -f null - 2>&1 |
		sed -n '/Summary/,$p' | awk '/ I:/ {print $2; exit}'
}

encode() { # encode <eingabe> <ausgabe> <filter>
	ffmpeg -hide_banner -loglevel error -y -i "$1" -map 0:a:0 -map_metadata -1 \
		-af "$3,aresample=44100" -c:a libvorbis -q:a 5 "$2"
}

# normalize <eingabe> <ausgabe.ogg>
normalize() {
	local in="$1" out="$2" stats mi mtp mlra mth off result
	# 1. loudnorm in zwei Durchgängen
	stats=$(ffmpeg -hide_banner -nostats -i "$in" -map 0:a:0 \
		-af "loudnorm=I=$TARGET_I:TP=$TARGET_TP:LRA=$TARGET_LRA:print_format=json" -f null - 2>&1 |
		sed -n '/^{/,/^}/p')
	mi=$(sed -n 's/.*"input_i" : "\(.*\)".*/\1/p' <<<"$stats")
	mtp=$(sed -n 's/.*"input_tp" : "\(.*\)".*/\1/p' <<<"$stats")
	mlra=$(sed -n 's/.*"input_lra" : "\(.*\)".*/\1/p' <<<"$stats")
	mth=$(sed -n 's/.*"input_thresh" : "\(.*\)".*/\1/p' <<<"$stats")
	off=$(sed -n 's/.*"target_offset" : "\(.*\)".*/\1/p' <<<"$stats")
	encode "$in" "$out" "loudnorm=I=$TARGET_I:TP=$TARGET_TP:LRA=$TARGET_LRA:measured_I=$mi:measured_TP=$mtp:measured_LRA=$mlra:measured_thresh=$mth:offset=$off:linear=true"
	result=$(loudness "$out")

	# 2. Bei sehr kurzen, spitzen Clips trifft loudnorm das Ziel nicht:
	#    dann Verstärkung plus Limiter, nachgemessen und korrigiert.
	if awk -v r="$result" -v t="$TARGET_I" 'BEGIN { d = r - t; exit !(d > 1 || d < -1) }'; then
		local limit gain
		limit=$(awk -v tp="$TARGET_TP" 'BEGIN { printf "%.4f", 10 ^ (tp / 20) }')
		gain=$(awk -v t="$TARGET_I" -v m="$mi" 'BEGIN { printf "%.2f", t - m }')
		for _ in 1 2 3; do
			encode "$in" "$out" "volume=${gain}dB,alimiter=limit=$limit:level=disabled"
			result=$(loudness "$out")
			gain=$(awk -v g="$gain" -v t="$TARGET_I" -v r="$result" 'BEGIN { printf "%.2f", g + t - r }')
			awk -v r="$result" -v t="$TARGET_I" 'BEGIN { d = r - t; exit !(d > 0.7 || d < -0.7) }' || break
		done
	fi
	printf '%-58s %7s LUFS -> %6s LUFS\n' "$(basename "$(dirname "$out")")/$(basename "$out")" "$mi" "$result"
}

shopt -s nullglob nocaseglob
mkdir -p "$sounds/Allgemein"

# Lose Dateien direkt in Sounds/ gehören zu "Allgemein".
for file in "$sounds"/*.{mp3,wav,flac,m4a,opus,ogg}; do
	mv -n "$file" "$sounds/Allgemein/"
done

count=0
for dir in "$sounds"/*/; do
	group="$(basename "$dir")"
	[[ "$group" == "original" ]] && continue
	for file in "$dir"*.{mp3,wav,flac,m4a,opus,ogg}; do
		name="$(basename "$file")"
		base="${name%.*}"
		ext="${name##*.}"
		if [[ "${ext,,}" == "ogg" ]]; then
			$all || continue
			tmp="$dir.$base.tmp.ogg"
			normalize "$file" "$tmp"
			mv "$tmp" "$file"
		else
			if [[ -e "$dir$base.ogg" ]]; then
				echo "Übersprungen: $group/$base.ogg gibt es schon (Original $name bleibt liegen)" >&2
				continue
			fi
			normalize "$file" "$dir$base.ogg"
			mkdir -p "$originals/$group"
			mv "$file" "$originals/$group/$name"
		fi
		count=$((count + 1))
	done
done

echo "$count Sounds angeglichen."
"$root/tools/update-sounds.sh"
