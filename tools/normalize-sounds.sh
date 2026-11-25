#!/usr/bin/env bash
# Gleicht die Lautstärke der Sounds an und speichert sie als .ogg.
#
#   normalize-sounds.sh          jede .mp3/.wav/.flac/.m4a/.opus-Datei im Ordner
#                                "Sounds" angleichen; die .ogg ersetzt sie, das
#                                Original wandert nach Sounds/original/ (wird vom
#                                Spiel nicht geladen)
#   normalize-sounds.sh --all    dazu auch alle vorhandenen .ogg neu angleichen
#   normalize-sounds.sh DATEI…   genau diese Dateien als Sounds/<name>.ogg ablegen
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
	#    dann Verstärkung plus Limiter, einmal nachgemessen und korrigiert.
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
	printf '%-58s %7s LUFS -> %6s LUFS\n' "$(basename "$out")" "$mi" "$result"
}

shopt -s nullglob nocaseglob
count=0

if [[ $# -gt 0 && "$1" != "--all" ]]; then
	for file in "$@"; do
		name="$(basename "$file")"
		normalize "$file" "$sounds/${name%.*}.ogg"
		count=$((count + 1))
	done
else
	all=false
	[[ "${1:-}" == "--all" ]] && all=true
	for file in "$sounds"/*.{mp3,wav,flac,m4a,opus,ogg}; do
		name="$(basename "$file")"
		base="${name%.*}"
		ext="${name##*.}"
		if [[ "${ext,,}" == "ogg" ]]; then
			$all || continue
			tmp="$sounds/.$base.tmp.ogg"
			normalize "$file" "$tmp"
			mv "$tmp" "$file"
		else
			if [[ -e "$sounds/$base.ogg" ]]; then
				echo "Übersprungen: $base.ogg gibt es schon (Original $name bleibt liegen)" >&2
				continue
			fi
			normalize "$file" "$sounds/$base.ogg"
			mkdir -p "$originals"
			mv "$file" "$originals/$name"
		fi
		count=$((count + 1))
	done
fi

echo "$count Sounds angeglichen."
"$root/tools/update-sounds.sh"
