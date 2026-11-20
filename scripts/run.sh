#!/usr/bin/env sh
# Runs PinGames. Extra arguments are passed to the game, e.g.:
#   scripts/run.sh --layout=windowed --game=breakout
# Godot binary: $GODOT_BIN, else `godot4` / `godot` on PATH.
set -e
GODOT="${GODOT_BIN:-$(command -v godot4 || command -v godot)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$ROOT/.godot" ] || "$GODOT" --headless --path "$ROOT" --import
exec "$GODOT" --path "$ROOT" -- "$@"
