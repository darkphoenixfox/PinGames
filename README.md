# PinGames

A bundle of arcade-inspired games built for **PC virtual pinball cabinets** on Windows and Linux. Each game uses three screens and is played with pinball buttons only:

- **TABLE**: the portrait (TATE) playfield screen, where the game is played
- **DMD**: a dot-matrix score display. It can be simulated on a monitor, drawn inside the backglass, or sent to a real LED DMD.
- **BACKGLASS**: the art and status screen

Players use 2 or 4 side buttons, Launch, Start and Exit. There is no mouse or keyboard.

Games planned so far:
- a block breaker (first vertical slice)
- a vertical shmup
- a super-scaler racer

Built with **Godot 4.7.2 + GDScript**. Nothing requires opening the Godot editor.

## Quick start (Windows)
```powershell
scripts\run.ps1                                  # picker, 3 windows on one monitor
scripts\run.ps1 --game=breakout                  # launch a game directly (Exit quits)
scripts\run.ps1 --layout=3screen                 # cabinet: 3 monitors, fullscreen
scripts\run.ps1 --layout=2screen                 # cabinet: DMD inside the backglass
scripts\test.ps1                                 # headless smoke tests
```
- **Linux:** use `scripts/run.sh` / `scripts/test.sh`, with `GODOT_BIN` or `godot4` on your PATH.
- **Different Godot location:** set `GODOT_BIN` to the path of the Godot binary.

### Command-line options (after the script name)
| Option | Meaning |
|---|---|
| `--layout=windowed\|2screen\|3screen` | Screen layout |
| `--game=<breakout\|shmup\|racer>` | Skip the picker. Exit returns to the frontend. |
| `--lang=<locale>` | UI language |
| `--section.key=value` | Override any setting for this run, e.g. `--display.table_rotation=90` |
| `--mode=operator\|attract\|initials` | Open a shell mode directly (development aid) |
| `--press=flip_r,launch,hold:start+exit:3.5` | Simulate button presses (development aid) |
| `--mode=viewer --model=res://assets/models/<…>.glb` | Model viewer: flippers rotate, Launch toggles spin, Start changes view, Exit leaves |
| `--tb-enemy-now`, `--tb-dmd-anim=<name>`, `--tb-show-shields`, `--tb-lights-on`, `--tb-skip-intro` | Tilt Breaker dev aids (skip-intro = straight into play): early enemy, loop a DMD animation, show the edge shields, hold all backglass lights on |
| `--screenshot=<dir>` | Save PNGs of every screen and window, then quit (development aid) |

### Settings
Settings live in `%APPDATA%\PinGames\pingames.cfg` on Windows, or `~/.local/share/PinGames/pingames.cfg` on Linux. It's a plain INI-style file, and every key has a default in `core/config.gd`. Main keys:
- `[display]`: layout, monitor index per screen, rotation per screen (0/90/180/270, -1 = auto), DMD sink, render scale
- `[dmd]`: dot resolution, colour, hardware host/port
- `[input]`: bindings per action, e.g. `flip_l=["key:Shift@left", "joy:9"]`
- `[dmd]` also has `mono`: `false` = full-colour LEDs, `true` = classic single-colour look
- `[operator]`: language, free play, balls per game, number of side buttons, attract delay, volumes

High scores are in `scores.cfg` in the same folder.

### Operator menu (no keyboard needed)
To open it, **hold Start + Exit for 3 seconds**, or **hold Exit for 5 seconds** on the game picker. Flippers move, Launch selects or edits, and Exit goes back.

| Page | What it does |
|---|---|
| Display Setup | Layout; monitor and rotation for each screen; DMD output (own monitor / inside backglass / LED hardware); render scale. **Identify monitors** shows a number on each screen. **Apply** shows the result and undoes it after 15 s unless you press Launch. |
| Controls | Select an action, then press the new button within 6 s. Reset to defaults. |
| Game Settings | Free play, balls/lives, side buttons (auto/2/4), attract delay, DMD style (colour/mono) |
| Audio | Master, music and effects volume; attract sounds |
| Language | UI language (any column in `strings.csv`) |
| Reset High Scores | Per game or all; press twice to confirm |
| System Info | Engine version, layout, monitors, render size, settings folder |

### Picker and game flow
- **Picker:** flippers choose a game, and Launch or Start plays it. Exit quits the app.
- After 60 s idle, the picker switches to attract mode (title and high-score pages).
- **Game over:** a top-10 score asks for initials. Flippers pick the letter, Launch confirms it and Exit goes back.
- **Coin mode** (Free play OFF): Coin adds a credit, and starting a game uses one.

### Debug keys (debug builds only, D-057)
Every run through `scripts/run.ps1` or the Godot binary is a debug build. Exported release builds for cabinets ignore these keys. `--debug-tools=off` disables them.

| Key | Action |
|---|---|
| **P** | Pause / resume the whole game |
| **F** | Tilt Breaker: a free piercing plasma bolt that destroys everything in a vertical line above the ship |
| **C** | Tilt Breaker: clear the current level instantly (level-complete sequence) |
| **I** | Input monitor: live view of held actions and window focus. Every press, release and focus change is logged to `<settings folder>/input_log.txt` |

### Default controls
| Action | Keyboard | Controller |
|---|---|---|
| Left / right flipper | Left / Right Shift | L1 / R1 |
| Left / right magna save | Left / Right Ctrl | L2 / R2 |
| Launch | Space | Cross |
| Start | Enter | Circle |
| Exit | Backspace | Square |
| Coin | 5 | — |

## Repository layout
```
core/            shared framework (autoloads: Config, I18n, CabinetInput, Audio, Credits, HighScores, Dmd, Screens)
  ui/            shared UI helpers + button-driven menu
  util/          pure helpers (CLI, bindings, CSV i18n) — unit-tested headless
  dmd/           DMD viewport + sinks (hardware sink is a stub)
  locale/        strings.csv — translation keys (column per language)
  shaders/       shared shaders (DMD dots)
  game_module.gd base script every game extends
shell/           boot + modes (picker, attract, game, initials, operator), dev flags
games/<id>/      one folder per game (game.gd + its content)
assets/          shared assets; licenses in assets/CREDITS.md (Git LFS)
scripts/         run / test scripts
tests/           headless smoke tests
docs/            DECISIONS.md (decision log), GDD.md (design)
```

## Documentation
- [docs/DECISIONS.md](docs/DECISIONS.md) records every technical and design decision. **Read it first.**
- [docs/GDD.md](docs/GDD.md) is the game design document: screens, controls, shared systems, each game, and the roadmap.
- [CLAUDE.md](CLAUDE.md) holds the working rules for AI dev sessions.

## Adding a translation
Add a column to `core/locale/strings.csv`, for example `es`. Alternatively, drop a CSV with the same format into `<user dir>/locale/`. Then set `operator.language`.

## Cabinet PC setup (Windows)
Turn **off** the Sticky Keys and Filter Keys keyboard shortcuts (Settings → Accessibility → Keyboard). With Shift as the flipper key, their prompts can steal focus mid-game. The game warns on the picker if they're on (D-070), and it releases all inputs if it ever loses focus (D-069).

## Requirements
- Godot 4.7.2 stable (the standard build, not .NET)
- Git LFS: run `git lfs install` once before cloning
