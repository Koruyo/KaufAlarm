#!/usr/bin/env bash
# Erzeugt Media/icon.tga (64x64, 32 Bit, unkomprimiert) aus Media/icon.svg.
# Braucht rsvg-convert und ImageMagick.
set -euo pipefail

media="$(cd "$(dirname "$0")/.." && pwd)/Media"
tmp="$(mktemp --suffix=.png)"
trap 'rm -f "$tmp"' EXIT

rsvg-convert -w 64 -h 64 "$media/icon.svg" -o "$tmp"
magick "$tmp" -define tga:compression=none -type TrueColorAlpha "$media/icon.tga"
magick identify "$media/icon.tga"
