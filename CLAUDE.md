# CLAUDE.md — working rules for this repo

## Before you do anything
1. Read `docs/DECISIONS.md` in full. It is the source of truth for every past decision.
2. Read the relevant parts of `docs/GDD.md`.
3. Check `git log --oneline -20` to see recent work.

## Roles
- **The user is the Game Director.** They make the final call on design, art, scope and names. Bring them proposals; don't decide these alone.
- **Claude is lead developer** and shares art duties.

## Hard rules
- **No editor workflows** (D-004). The director never opens the Godot editor. Everything must be text and command-line driven.
  - Build scenes in code, or as small hand-written `.tscn` files.
  - Don't use `class_name`; use `extends "res://..."` paths instead (D-010).
- **2+1 buttons are enough** (D-007). Every game feature must work with `flip_l`, `flip_r` and `launch`. Magna saves are optional extras. Read input only through `CabinetInput` actions, never raw keys.
- **All visible text goes through `tr("KEY")`** (D-009). Add each key to `core/locale/strings.csv`; the test fails if one is missing.
- **Author content in base coordinates:** TABLE is 1080x1920, BACKGLASS is 1920x1080, and the DMD is its dot size. Never assume window size or rotation (D-005).
- **Original content only.** Games may be inspired by arcade classics, but never copy their names, characters, art, music or levels. Record every asset's source and license in `assets/CREDITS.md`.
- **Log decisions.** Any non-trivial technical or design choice gets a new `D-xxx` entry in `docs/DECISIONS.md`. The log is append-only: supersede old entries, don't edit them.

## Commands (Windows)
```powershell
scripts\test.ps1                                   # import + headless tests (must pass before commit)
scripts\run.ps1 [--layout=...] [--game=...]        # run
& $env:GODOT_BIN --path . -- --screenshot=<dir>     # capture all screens for visual checks (D-017)
```
The Godot binary is at `C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe`, unless `GODOT_BIN` overrides it.

## Commit and push
- The repo is private on GitHub (`darkphoenixfox/PinGames`, branch `main`).
- Run the tests before every commit.
- Binary assets go through Git LFS (`.gitattributes`).
