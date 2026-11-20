#!/usr/bin/env sh
set -e
GODOT="${GODOT_BIN:-$(command -v godot4 || command -v godot)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$GODOT" --headless --path "$ROOT" --import
exec "$GODOT" --headless --path "$ROOT" --script res://tests/run_tests.gd
