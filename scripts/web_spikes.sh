#!/usr/bin/env bash
# Measures first-time stalls in the browser build (D-179): exports the Web
# preset to exports/web, serves it on localhost, opens it in headless Edge with
# ?log-spikes and a --press script, and prints the slow frames (> 80 ms) next
# to the game events before them.
# Usage: scripts/web_spikes.sh "<url query>" [seconds] [--no-export]
#   scripts/web_spikes.sh "game=breakout&tb-skip-intro&press=wait,launch" 120
set -u
cd "$(dirname "$0")/.."
QUERY="$1"; SECS="${2:-120}"
GODOT="${GODOT_BIN:-C:/Users/Phoenixfox/Dev/Godot/Godot_v4.7.2-stable_win64_console.exe}"
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
if [ "${3:-}" != "--no-export" ]; then
  rm -f exports/web/index.*
  mkdir -p exports/web
  ( timeout 900 "$GODOT" --headless --path . --export-release "Web" exports/web/index.html > /dev/null 2>&1 & )
  for i in $(seq 1 200); do
    sleep 3
    [ -s exports/web/index.pck ] && [ -s exports/web/index.wasm ] && [ -s exports/web/index.html ] && break
  done
  sleep 10
  taskkill //F //IM "$(basename "$GODOT")" > /dev/null 2>&1
fi
( cd exports/web && timeout $((SECS + 30)) python -m http.server 8765 --bind 127.0.0.1 > /dev/null 2>&1 & )
sleep 2
PROFILE="${TEMP:-/tmp}/pingames_edge_profile"
rm -rf "${PROFILE:?}"
timeout "$SECS" "$EDGE" --headless=new --enable-logging=stderr --v=0 \
  --user-data-dir="$(cygpath -w "$PROFILE")" --disable-extensions \
  --disable-component-extensions-with-background-pages --mute-audio \
  --autoplay-policy=no-user-gesture-required --window-size=1280,720 --no-first-run \
  "http://127.0.0.1:8765/index.html?log-spikes&no-focus-pause&$QUERY" 2>&1 \
  | grep -aoE '"(Spike|Event|Shell|Shader)[^"]*' | sed 's/"//' | uniq
