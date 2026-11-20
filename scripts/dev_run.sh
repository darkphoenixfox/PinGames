#!/usr/bin/env sh
# Claude's test runs (D-048): like run.sh, but the game windows never take focus
# and open on the second monitor, so the director's work isn't interrupted.
#   scripts/dev_run.sh --game=breakout --press=launch --screenshot=<dir>
# - Writes a temporary override.cfg (display/window/size/no_focus) for this run
#   only and deletes it afterwards (override.cfg is git-ignored).
# - Puts the windowed layout on monitor index $PINGAMES_DEV_MONITOR (default 1)
#   and renders the TABLE at full base resolution (render_scale 1.0).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/c/Users/Phoenixfox/Dev/Godot/Godot_v4.7.2-stable_win64_console.exe}"
OVERRIDE="$ROOT/override.cfg"
printf '[display]\n\nwindow/size/no_focus=true\n' > "$OVERRIDE"
trap 'rm -f "$OVERRIDE"' EXIT
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true  # pick up new assets
"$GODOT" --path "$ROOT" -- --display.windowed_monitor="${PINGAMES_DEV_MONITOR:-1}" --display.render_scale=1.0 "$@"
