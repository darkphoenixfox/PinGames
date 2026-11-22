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
scripts\run_vr.ps1 [--game=racer]                # VR cabinet (OpenXR; desktop preview without a headset)
scripts\test.ps1                                 # headless smoke tests
```
- **Linux:** use `scripts/run.sh` / `scripts/test.sh`, with `GODOT_BIN` or `godot4` on your PATH.
- **Different Godot location:** set `GODOT_BIN` to the path of the Godot binary.

### Command-line options (after the script name)
| Option | Meaning |
|---|---|
| `--layout=windowed\|2screen\|3screen\|vr` | Screen layout (`vr`: 3D cabinet, D-164) |
| `--game=<breakout\|shmup\|racer>` | Skip the picker. Exit returns to the frontend. |
| `--lang=<locale>` | UI language |
| `--section.key=value` | Override any setting for this run, e.g. `--display.table_rotation=90` |
| `--mode=operator\|attract\|initials` | Open a shell mode directly (development aid) |
| `--press=flip_r,launch,hold:start+exit:3.5` | Simulate button presses (development aid) |
| `--mode=viewer --model=res://assets/models/<…>.glb` | Model viewer: flippers rotate, Launch toggles spin, Start changes view, Exit leaves |
| `--tb-enemy-now`, `--tb-dmd-anim=<name>`, `--tb-show-shields`, `--tb-lights-on`, `--tb-skip-intro`, `--tb-level=N` | Tilt Breaker dev aids (skip-intro = straight into play): early enemy, loop a DMD animation, show the edge shields, hold all backglass lights on |
| `--rc-skip-intro`, `--rc-autopilot`, `--rc-time=S`, `--rc-no-toon`, `--rc-night`, `--rc-car=N` | Turbo Run dev aids: straight into the countdown; the car drives itself (also used by the attract demo); start with S seconds on the clock; plain shading instead of cel (D-091); night from the start (D-113); race car N (0 easy, 1 normal, 2 hard, D-122). Debug keys: F freezes the clock, S skips to stage 5, O spawns the police |
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

### Debug keys (debug builds and the browser build, D-057, D-175)
Every run through `scripts/run.ps1` or the Godot binary is a debug build. Exported release builds for cabinets ignore these keys. `--debug-tools=off` disables them.

| Key | Action |
|---|---|
| **P** | Pause / resume the whole game |
| **F** | Tilt Breaker: a free piercing plasma bolt that destroys everything in a vertical line above the ship |
| **C** | Tilt Breaker: clear the current level instantly (level-complete sequence) |
| **U** | Tilt Breaker: drop the next power-up capsule (T, P, B, I, L, S in turn) over the ship |
| **I** | Input monitor: live view of held actions and window focus. Every press, release and focus change is logged to `<settings folder>/input_log.txt` |

### Default controls
| Action | Keyboard | Controller |
|---|---|---|
| Left / right flipper | Left / Right arrow | L1 / R1 |
| Left / right magna save | Left / Right Ctrl | L2 / R2 |
| Launch | Space | Cross |
| Start | Enter | Circle |
| Exit | Backspace | Square |
| Coin | 5 | — |

## Browser version (D-173 to D-175)

- **Address:** https://web.phoenixfox.net/pingames/. It needs HTTPS: Godot's web build won't start on the plain-HTTP LAN address (http://192.168.1.150:8086/pingames/), because the browser requires a secure context.
- **Layout:** one page, with the TABLE on the left and the BACKGLASS and DMD on the right.
- **Controls:** keyboard, the same keys as the cabinet defaults. The page's first click, tap or keypress turns the sound on (a browser rule).
- **Touch screens:** the buttons stand in two columns at the sides of the screens, so the play area keeps its full height. EXIT is above a big LEFT on the left; START and LAUNCH are above a big RIGHT on the right. Tapping the left or right half of the TABLE also works the flippers, and several fingers work at once. HIDE / SHOW BUTTONS (top-right corner) turns the columns off and on, and the choice is remembered. `?touch` shows them on any device, and mouse clicks work them then. In portrait, phones get the DMD above the TABLE and no BACKGLASS.
- **Focus pause:** when the page loses focus (another tab or window, minimised), the game stops and the sound is muted. Back on the page, any key, tap or click continues.
- **Install as an app:** the page is a PWA (web manifest + service worker), so Edge and Chrome offer "Install" in the address bar or the "Apps" menu. It opens in its own window with the PinGames icon (a placeholder from `scripts/tools/gen_app_icon.py`).
- **URL options:** the query string works like command-line options. For example, `?game=racer` opens Turbo Run directly, and `?game=breakout&tb-skip-intro` opens Tilt Breaker without its intro.
- **Deploy:** `scripts\deploy_web.ps1` builds the Web preset and mirrors it to `K:\heroar\www\pingames`. The HeroAR stack's NGINX serves it with pre-compressed `.gz` files (HeroAR DEC-0275). No restart is needed.

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
Turn **off** the Sticky Keys and Filter Keys keyboard shortcuts (Settings → Accessibility → Keyboard). Their prompts can steal focus mid-game, especially if your encoder maps flippers to Shift. The game warns on the picker if they're on (D-070), and it releases all inputs if it ever loses focus (D-069).

## Requirements
- Godot 4.7.2 stable (the standard build, not .NET)
- Git LFS: run `git lfs install` once before cloning
