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
scripts/dev_run.sh --game=breakout --press=launch --screenshot=<dir>   # Claude's test runs (D-048)
```
**Always use `scripts/dev_run.sh` (bash) for visual test runs.** It imports new assets, opens the windows without taking focus and on the second monitor, renders at full resolution, and accepts every dev flag (`--mode`, `--press`, `--screenshot`, `--screenshot-delay`; D-017, D-030). Don't launch the game in the foreground while the director is working.

The Godot binary is at `C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe`, unless `GODOT_BIN` overrides it.

## Gotchas
- A Control that anchors itself in `_ready()` must call `set_anchors_and_offsets_preset()`. `set_anchors_preset()` keeps its zero size.
- `ConfigFile.get_value(section, key, null)` logs an error when the key is missing. Check `has_section_key` first.
- Tests flag any ALL_CAPS_WITH_UNDERSCORE string literal that isn't a translation key, comments included.
- Never store masks or data in PNG alpha. Godot's "fix alpha border" import bleeds colour into low-alpha pixels, so use a separate greyscale texture.
- Don't name a class or inner class after a Godot built-in (e.g. `Engine`): it fails to parse.
- Billboard materials ignore node scale unless `billboard_keep_scale = true`.
- `GPUParticles3D` particles didn't move in our TABLE SubViewport setup; use `CPUParticles3D` for small emitters.
- Actions fired from outside `sim.step()` (debug keys, UI) must update the view directly, because sim events are cleared at the start of each step.
- Big game text (titles, GET READY, GAME OVER) uses that game's styled title font through `UI.styled_label(text, style, scale)` (D-062). Tilt Breaker = `nano`, Sky Striker = `squadron`, Turbo Run = `sunset`. Regenerate with `scripts/tools/gen_title_fonts.py`.
- UI text uses PinPixel (D-060). Create labels with `UI.label()`, which snaps sizes to multiples of 12 for crisp pixels. Keep the font's `.import` with `antialiasing=0`, `hinting=0` and `subpixel_positioning=0`.
- Tilt Breaker starts in its attract mode (D-061). Test runs that need gameplay straight away pass `--tb-skip-intro`.
- Blink UI with `modulate.a`, never `visible`: a hidden Control collapses in its container and the rest of the layout jumps (D-096).
- Screenshot runs use the real `user://` data (settings and scores). Don't leave runs that save anything there.

## Commit and push
- The repo is private on GitHub (`darkphoenixfox/PinGames`, branch `main`).
- Run the tests before every commit.
- Binary assets go through Git LFS (`.gitattributes`).
