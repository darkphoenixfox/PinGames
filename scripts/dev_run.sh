#!/usr/bin/env sh
# Claude's test runs (D-048): like run.sh, but the game windows never take focus
# and never show over the director's work.
#   scripts/dev_run.sh --game=breakout --press=launch --screenshot=<dir>
# - Writes a temporary override.cfg (display/window/size/...) for this run
#   only and deletes it afterwards (override.cfg is git-ignored).
# - D-355: the windows start off the desktop and stay there (--dev-offscreen);
#   screenshots read the viewports, so they still work. PINGAMES_DEV_VISIBLE=1
#   shows them on monitor $PINGAMES_DEV_MONITOR (default 1) as before.
# - Renders the TABLE at full base resolution (render_scale 1.0).
# - Silent by default (dummy audio driver, D-100); PINGAMES_DEV_SOUND=1 keeps sound.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/c/Users/Phoenixfox/Dev/Godot/Godot_v4.7.2-stable_win64_console.exe}"
OVERRIDE="$ROOT/override.cfg"
if [ "${PINGAMES_DEV_VISIBLE:-0}" = "1" ]; then
	printf '[display]\n\nwindow/size/no_focus=true\n' > "$OVERRIDE"
	OFF=""
else
	printf '[display]\n\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\nwindow/size/initial_position=Vector2i(-32000, -32000)\n' > "$OVERRIDE"
	OFF="--dev-offscreen"
fi
trap 'rm -f "$OVERRIDE"' EXIT
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true  # pick up new assets
AUDIO="--audio-driver Dummy"
[ "${PINGAMES_DEV_SOUND:-0}" = "1" ] && AUDIO=""
"$GODOT" --path "$ROOT" $AUDIO -- --display.windowed_monitor="${PINGAMES_DEV_MONITOR:-1}" --display.render_scale=1.0 $OFF "$@"
