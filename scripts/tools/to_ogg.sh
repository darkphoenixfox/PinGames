#!/usr/bin/env sh
# Converts any audio file to OGG Vorbis for the game (D-023).
# Usage: scripts/tools/to_ogg.sh <in> <out.ogg> [trim]
#   trim  = also strip leading/trailing silence (not for tracks that are already seamless loops)
# Quality 6 (~190 kbps stereo); mono sources stay mono.
set -e
IN="$1"; OUT="$2"; MODE="$3"
FILTER="anull"
if [ "$MODE" = "trim" ]; then
  FILTER="silenceremove=start_periods=1:start_threshold=-55dB,areverse,silenceremove=start_periods=1:start_threshold=-55dB,areverse"
fi
ffmpeg -hide_banner -loglevel error -y -i "$IN" -map_metadata -1 -af "$FILTER" -c:a libvorbis -q:a 6 "$OUT"
ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$OUT" | xargs printf "%s  %ss\n" "$OUT"
