#!/usr/bin/env bash
# Erzeugt die mitgelieferten Sounds neu. Braucht nur ffmpeg.
set -euo pipefail

out="$(cd "$(dirname "$0")/.." && pwd)/Sounds"
mkdir -p "$out"

render() { # render <datei> <ausdruck> <dauer>
	ffmpeg -y -loglevel error -f lavfi -i "aevalsrc='$2':d=$3:s=44100" \
		-af "afade=t=in:d=0.02,afade=t=out:st=$(awk "BEGIN{print $3-0.15}"):d=0.15" \
		-ac 1 -c:a libvorbis -q:a 4 "$out/$1"
}

# Blubbern: kurze, aufsteigende Töne in wechselnder Höhe
render blubblub.ogg \
	"0.7*sin(2*PI*(1+0.35*sin(2.4*floor(t/0.17)))*(350*mod(t,0.17)+2600*pow(mod(t,0.17),2)))*exp(-16*mod(t,0.17))" 1.9

# Sirene
render sirene.ogg "0.5*sin(2*PI*850*t+140*sin(2*PI*2*t))" 2.6

# Alarm-Piepsen: dreimal drei Pieptöne
render durst_alarm.ogg "0.5*sin(2*PI*1320*t)*lt(mod(t,0.16),0.09)*lt(mod(t,0.9),0.48)" 2.6

# Traurige Posaune: vier absteigende Töne, der letzte lang mit Vibrato
note() { # note <frequenz> <start> <dauer> <vibrato>
	local p="(2*PI*$1*(t-$2)+$4*sin(2*PI*5.5*(t-$2))-$4*8*pow(t-$2,2))"
	echo "between(t,$2,$2+$3)*min(1,(t-$2)*30)*min(1,($2+$3-t)*10)*(sin($p)+sin(2*$p)/2+sin(3*$p)/3+sin(4*$p)/4+sin(5*$p)/5)"
}
render traurige_posaune.ogg \
	"0.3*($(note 293.66 0 0.42 0)+$(note 277.18 0.45 0.42 0)+$(note 261.63 0.9 0.42 0)+$(note 246.94 1.35 1.3 2.5))" 2.8

ls -l "$out"
