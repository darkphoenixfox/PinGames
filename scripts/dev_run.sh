#!/usr/bin/env sh
# Claude's test runs (D-048): like run.sh, but the game windows never take focus
# and never show over the director's work.
#   scripts/dev_run.sh --game=breakout --press=launch --screenshot=<dir>
# - Writes a temporary override.cfg (display/window/size/...) for this run
#   only and deletes it afterwards (override.cfg is git-ignored).
# - D-393: the windows start off the desktop and are then put on the monitor
#   that is NOT the main one (--dev-screen=other; PINGAMES_DEV_MONITOR=N picks
#   one, counted from 0), without taking focus. With one monitor, or with
#   PINGAMES_DEV_HIDDEN=1, they stay off the desktop (D-355). Screenshots read
#   the viewports, so they work either way.
# - Renders the TABLE at full base resolution (render_scale 1.0).
# - Silent by default (dummy audio driver, D-100); PINGAMES_DEV_SOUND=1 keeps sound.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/c/Users/Phoenixfox/Dev/Godot/Godot_v4.7.2-stable_win64_console.exe}"
OVERRIDE="$ROOT/override.cfg"
# Always starts off the desktop, so nothing ever flashes on the main monitor.
printf '[display]

window/size/no_focus=true
window/size/initial_position_type=0
window/size/initial_position=Vector2i(-32000, -32000)
' > "$OVERRIDE"
MON="${PINGAMES_DEV_MONITOR:-other}"
if [ "${PINGAMES_DEV_HIDDEN:-0}" = "1" ]; then
	OFF="--dev-offscreen"
else
	OFF="--dev-offscreen --dev-screen=$MON"
fi
trap 'rm -f "$OVERRIDE"' EXIT
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true  # pick up new assets
AUDIO="--audio-driver Dummy"
[ "${PINGAMES_DEV_SOUND:-0}" = "1" ] && AUDIO=""
"$GODOT" --path "$ROOT" $AUDIO -- --display.windowed_monitor=1 --display.render_scale=1.0 $OFF "$@"
