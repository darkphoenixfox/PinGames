# Decision Log

> **Claude sessions: read this whole file before resuming work.** Then read `docs/GDD.md`.
> It is append-only. To change a decision, add a new entry that supersedes the old one, and set the old entry's status to `Superseded by D-xxx`. Never rewrite history.
> Format: **ID, title**, then Date / Decision / Why / Consequences / Status.
> Roles: the **Game Director** (the human project owner) has final say on design, art and scope. **Claude** is lead developer and shares art duties.

---

### D-001 — Project scope
- **Date:** 2026-11-20
- **Decision:** PinGames is one bundle of arcade-inspired games for PC virtual pinball cabinets on Windows and Linux. The first three are a super-scaler racer (OutRun / Chase HQ style), a block breaker (Arkanoid style) and a vertical shmup (1943 / Raiden style). The games are *inspired by* those genres. We do not recreate their names, characters, art, music or levels.
- **Why:** These are the director's goals.
- **Consequences:** All assets are self-made (AI-generated) or royalty-free, and every asset's license is tracked in `assets/CREDITS.md`.
- **Status:** Accepted

### D-002 — Engine: Godot 4.7.2 + GDScript
- **Date:** 2026-11-20
- **Decision:** Use Godot 4.7.2 stable with GDScript. The binary lives at `C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64(_console).exe`, and scripts can override it with the `GODOT_BIN` environment variable.
- **Why:** Godot opens native windows on chosen monitors (three.js in a browser can't do this reliably). It also has 3D with custom shaders, Win/Linux export, and is quick to iterate on in GDScript.
- **Consequences:** Export templates for 4.7.2 aren't installed yet; packaging is handled in M5.
- **Status:** Accepted

### D-003 — One app: game picker + `--game` CLI
- **Date:** 2026-11-20
- **Decision:** There is one executable. It opens on an attract/picker screen. `--game=<id>` launches a game directly. When launched that way, Exit quits the whole app instead of going back to the picker.
- **Why:** This supports both standalone use and cabinet frontends (PinUP Popper, PinballX), which launch one entry per game and expect the process to exit.
- **Consequences:** Every game is a module the shell loads (D-010).
- **Status:** Accepted

### D-004 — No-editor workflow
- **Date:** 2026-11-20
- **Decision:** The director never opens the Godot editor. Everything is authored as text:
  - `project.godot` is edited by hand.
  - Scenes are built in code, or written as small `.tscn` files.
  - Settings live in `pingames.cfg`.
  - Imports, runs, tests and exports happen through `scripts/`.
- **Why:** This is the director's requirement, and it keeps every change reviewable in git.
- **Consequences:** Don't add workflows that depend on the editor, such as editor-only import settings or tool scripts that must run in the editor. Input actions are created at runtime, not in `project.godot`.
- **Status:** Accepted

### D-005 — Rotation happens in-engine
- **Date:** 2026-11-20
- **Decision:** TABLE and BACKGLASS each render into a `SubViewport` at a fixed base size. TABLE is 1080x1920 (portrait), BACKGLASS is 1920x1080, and the DMD is at its dot resolution. A `ScreenView` control (`core/screen_view.gd`) draws each viewport into its OS window, fitted and rotated clockwise by 0, 90, 180 or 270 degrees.
- **Why:** Cabinet monitors are often left in landscape mode in Windows. Rotating inside the engine avoids depending on OS display rotation and matches how VPX works.
- **Consequences:** Games always author content in base coordinates. With `table_rotation = -1` (auto), the table is rotated 270 when its monitor is landscape.
- **Status:** Accepted

### D-006 — Screen layouts
- **Date:** 2026-11-20
- **Decision:** There are three layouts, set by `display.layout` or `--layout`:
  - `3screen`: TABLE is the main window (fullscreen). BACKGLASS and DMD each get a borderless window on their own monitor.
  - `2screen`: the DMD is drawn as a region of the BACKGLASS window (`display.dmd_region`).
  - `windowed`: see D-013.

  Monitor indexes and rotations are in `pingames.cfg`. A Display Setup wizard in the operator menu (M1) will set them using cabinet buttons only.
- **Why:** These cover the 2- and 3-monitor cabinet setups the director asked for, plus desktop development.
- **Consequences:** Secondary windows are `unfocusable`, so keyboard focus stays on TABLE. Input is read from the global `Input` singleton anyway (D-007). The original plan's single-window `dev` layout was dropped in favour of D-013.
- **Status:** Accepted

### D-007 — Logical input actions; 2+1 baseline
- **Date:** 2026-11-20
- **Decision:**
  - Gameplay reads only these logical actions through the `CabinetInput` autoload: `flip_l`, `flip_r`, `magna_l`, `magna_r`, `launch`, `start`, `coin`, `exit`.
  - Every game must be fully playable with `flip_l`, `flip_r` and `launch`. Magna saves are optional extras.
  - Start and Exit are guaranteed to exist.
  - Default bindings were superseded by D-019.
  - Bindings are text strings in `pingames.cfg [input]`, for example `key:Shift@left`, `joy:9` or `axis:4+`.
- **Why:** Cabinets differ, and the director's cabinet uses both a keyboard encoder and a HID board. There is no mouse or keyboard at play time.
- **Consequences:** Remapping goes into the operator menu in M1. Analog plunger and nudge input aren't supported yet; they can be added later as optional actions.
- **Status:** Accepted

### D-019 — Default bindings set by the director (refines D-007)
- **Date:** 2026-11-20
- **Decision:** These are the default bindings:

  | Action | Keyboard | Controller |
  |---|---|---|
  | flip_l | Left Shift | L1 (`joy:9`) |
  | flip_r | Right Shift | R1 (`joy:10`) |
  | magna_l | Left Ctrl | L2 (`axis:4+`) |
  | magna_r | Right Ctrl | R2 (`axis:5+`) |
  | launch | Space | Cross (`joy:0`) |
  | start | Enter | Circle (`joy:1`) |
  | exit | Backspace | Square (`joy:2`) |
  | coin | 5 | — |

- **Why:** The director specified them.
- **Consequences:** Claude assumed launch, start and exit follow the order the director listed them in. Confirm on the cabinet. The keys are deliberately not VPX's defaults (Enter for launch, Esc for exit).
- **Status:** Accepted

### D-008 — DMD output sinks
- **Date:** 2026-11-20
- **Decision:** The `Dmd` autoload owns a viewport at dot resolution (default 128x32, configurable). Its output goes to one of three sinks:
  - `window`: its own window, drawn with the `dmd_dots.gdshader` dot effect.
  - `backglass`: a region of the backglass window.
  - `hardware`: real LED DMDs such as ZeDMD or Pin2DMD, reached through libdmdutil's `dmdserver` over TCP (default port 6789).
- **Why:** GDScript can't talk to serial or USB DMD libraries directly, and `dmdserver` already supports the common devices.
- **Consequences:** `core/dmd/hardware_sink.gd` is a stub. **Verify the `dmdserver` protocol before implementing it (M5).** Shared DMD content should look good in monochrome.
- **Status:** Accepted (hardware part pending verification)

### D-009 — Translations loaded at runtime from CSV
- **Date:** 2026-11-20
- **Decision:**
  - All visible text uses `tr("KEY")`.
  - Keys live in `core/locale/strings.csv`, with a `keys` column and then one column per locale. Lines starting with `#` are comments.
  - The `I18n` autoload parses every CSV in `res://core/locale/` and `user://locale/` at runtime.
  - Only English ships for now.
- **Why:** New languages can be added as plain files, with no editor or import step. A test checks that every key used in code exists.
- **Consequences:** Godot also auto-imports the CSV into `*.translation` files. Those are git-ignored and unused. **The M5 export preset must include `*.csv` as non-resource files.** Fonts must cover the glyphs of future languages.
- **Status:** Accepted

### D-010 — Game module contract
- **Date:** 2026-11-20
- **Decision:**
  - Each game is `games/<id>/game.gd` and starts with `extends "res://core/game_module.gd"`. It overrides `get_info()`, `start(players)` and `on_action(action, pressed)`, and emits `score_changed` and `finished`.
  - Visual nodes are added with `add_to_table()` and `add_to_backglass()`, so they're cleaned up when the game ends.
  - Games are registered in `shell/main.gd` (`GAMES`).
  - **No `class_name`.** Scripts extend each other by path.
- **Why:** Godot's global class cache is built by the editor or the import step. Path-based `extends` always works from the command line.
- **Consequences:** A shared game module may not change another game's files.
- **Status:** Accepted

### D-011 — Repository and binary assets
- **Date:** 2026-11-20
- **Decision:** The code is in a private GitHub repo, `darkphoenixfox/PinGames`, on branch `main`. Binary assets (images, audio, models, fonts) are stored with Git LFS, as set in `.gitattributes`.
- **Why:** The director asked for this. LFS keeps clones small as AI-generated assets pile up.
- **Consequences:** Run `git lfs install` once on every machine that clones the repo.
- **Status:** Accepted

### D-012 — Art direction is chosen per game
- **Date:** 2026-11-20
- **Decision:** Each game picks its own visual style, set in its GDD section. Only the shell UI, the DMD style and the attract presentation are shared. The target fidelity is 3D models (cel-shaded or retro shaders allowed) mixed with scaled sprites.
- **Why:** The director chose this.
- **Status:** Accepted

### D-013 — `windowed` layout is the current default
- **Date:** 2026-11-20
- **Decision:** For now, all testing happens on one ultrawide monitor (5120x1440). `windowed` opens three separate OS windows on `display.windowed_monitor`, sized automatically from the usable area:
  - TABLE: 9:16 at full height, on the left.
  - BACKGLASS: 16:9, to the right of TABLE.
  - DMD: 4:1, under the BACKGLASS.
- **Why:** The director asked for this during M0.
- **Consequences:** The default `display.layout` is `windowed`. Switch to `3screen` or `2screen` when testing on the cabinet.
- **Status:** Accepted

### D-014 — Free play by default; coin mode is an operator option
- **Date:** 2026-11-20
- **Decision:** `operator.free_play = true`. When it is false, the `coin` action adds credits and Start uses one. The DMD shows FREE PLAY or INSERT COIN to match.
- **Status:** Accepted (credit logic arrives in M1)

### D-015 — Resolution and render scale
- **Date:** 2026-11-20
- **Decision:** The playfield monitor's resolution is unknown, so the app supports any resolution. TABLE's base coordinates are 1080x1920. `display.render_scale = "auto"` sizes the TABLE render target to match the output, clamped between 0.5x and 2x (2160x3840 at most). A number overrides it.
- **Why:** This covers 1080p and 4K playfields, and lets slower cabinet PCs render at a lower resolution.
- **Status:** Accepted

### D-016 — First vertical slice: block breaker
- **Date:** 2026-11-20
- **Decision:** After the core shell (M1), build the block breaker to completion first (M2), then the shmup (M3), then the racer (M4).
- **Why:** It has the simplest mechanics, so it proves the shared systems fastest. The racer is the highest technical risk, so it comes last, once the core is stable.
- **Status:** Accepted

### D-017 — Visual verification without a human
- **Date:** 2026-11-20
- **Decision:** `--screenshot=<dir>` waits 30 frames, saves `table.png`, `backglass.png`, `dmd.png` and `window_table.png`, then quits. Claude sessions use it, together with `scripts/test.ps1`, to check changes.
- **Status:** Accepted

### D-018 — Autoloads and their order
- **Date:** 2026-11-20
- **Decision:** The autoloads are `Config`, then `I18n`, `CabinetInput`, `Dmd` and `Screens`, in that order (`Screens` uses `Dmd`). They also load when running `--script` tests, so the tests import only the pure helpers in `core/util/`, which don't reference any autoload.
- **Status:** Accepted

### D-020 — 3D models come from Meshy as .glb
- **Date:** 2026-11-20
- **Decision:** 3D models are generated with Meshy and exported as `.glb` (binary glTF 2.0). The pipeline is in `docs/GDD.md` §8:
  - Files go in `assets/models/<game or shared>/<name>.glb`.
  - Godot imports them from the command line (`scripts/test.ps1` runs the import).
  - Code loads them as `PackedScene`.
  - Any per-game look, such as a cel or retro shader, is applied in code by overriding materials at runtime. Exported files are never edited by hand.
- **Why:** The director chose this. Godot supports glTF natively, so the no-editor workflow (D-004) keeps working.
- **Consequences:**
  - Export from Meshy at reduced polycount, because the cabinet GPU is unknown (D-015). See the §8 budgets.
  - Change import options by editing the `.glb.import` text file, never through the editor.
  - Each model gets a row in `assets/CREDITS.md` recording the Meshy plan or license it was made under, because the license terms depend on the plan.
  - Animated models (Meshy rigging) are allowed. Animations are played by name from code.
- **Status:** Accepted

### D-021 — Block breaker: flippers, multiple paddles, multi-floor stages
- **Date:** 2026-11-20
- **Decision:** Some stages have pinball flippers worked by the flipper buttons, placed anywhere in the stage. The same button moves the paddle and fires that side's flipper at the same moment. Some stages have several paddles at different heights, all moving together. Some stages are multi-floor and taller than the screen: the camera follows the ball, and a ball that drops off an upper floor falls to the floor below. These replace the earlier "flipper bumpers below the paddle" proposal.
- **Why:** The director's design.
- **Consequences:** The stage file format must support several floors, and paddles and flippers on each floor. Flippers need proper physics against the ball (rotating kinematic bodies with speed transferred to the ball). The camera system must handle tall stages. See GDD §5.1.
- **Status:** Accepted

### D-022 — Shmup: horizontal-only movement, fire and bomb controls
- **Date:** 2026-11-20
- **Decision:** The ship moves only left and right, on the flippers. On 2+1 cabinets it fires automatically. On 4+1 cabinets, holding either magna save fires manually. Holding both flippers for 3 seconds sets off a bomb, with a buildup effect and sound; letting go early cancels it. Launch has no role yet (still open). Cabinet type comes from `operator.cabinet_buttons` (`auto`/`2`/`4`). `auto` is proposed: start with auto-fire and switch to manual on the first magna save press.
- **Why:** The director's design. It keeps the game fully playable on 2+1 cabinets.
- **Status:** Accepted (the `auto` detection behaviour is a proposal)

### D-023 — Music comes from mixed sources; the game plays OGG only
- **Date:** 2026-11-20
- **Decision:** Music comes from AI-generated tracks, tracker modules and royalty-free packs. The game only ever plays OGG Vorbis. Tracker modules are committed as source files under `assets/audio/src/` and rendered to OGG with `openmpt123` by a script (to be written in M1 or M6).
- **Why:** The director wants a mix of all three. Rendering to OGG avoids a native GDExtension module player, which would complicate the no-editor, cross-platform builds.
- **Consequences:** Every track needs a row in CREDITS.md. Loop points are set in OGG import options (in the `.import` text file) or in code.
- **Status:** Accepted

### D-024 — Operator menu access approved
- **Date:** 2026-11-20
- **Decision:** Open the operator menu by holding Start + Exit for 3 seconds, or by holding Exit for 5 seconds on the picker.
- **Status:** Accepted

### D-025 — Shmup: Launch stays unassigned
- **Date:** 2026-11-20
- **Decision:** Sky Striker uses only the flippers (movement, and both held for the bomb) and the magna saves (manual fire on 4+1 cabinets). Launch has no gameplay role.
- **Why:** The director's call. Players won't have time to move a hand to Launch while dodging.
- **Status:** Accepted

### D-026 — The DMD is full colour, with a single colour per dot
- **Date:** 2026-11-20
- **Decision:** The DMD simulates an RGB LED panel such as ZeDMD. Every dot shows exactly one colour at a time: the colour of its source pixel, with no sub-dot blending. Games and the shell may use any colours. A shared palette (`Dmd.ORANGE/YELLOW/CYAN/RED/GREEN/WHITE/DIM`) keeps the bundle consistent. Setting `dmd.mono = true` (the operator's "DMD STYLE" option) switches to a classic single-colour plasma look, where everything is tinted `dmd.color` by brightness.
- **Why:** The director's requirement.
- **Consequences:** `dmd_dots.gdshader` samples each dot's centre pixel. The hardware sink (M5) must send RGB frames, which RGB panels such as ZeDMD support. Monochrome panels need a colour-to-shade conversion.
- **Status:** Accepted

### D-027 — Built-in 5x7 dot font for the DMD
- **Date:** 2026-11-20
- **Decision:** DMD text is drawn dot by dot with a built-in 5x7 font (`core/dmd/dot_font.gd`) at 1x or 2x size. The font is uppercase only, and accented Latin letters fold to their base letter. Ñ has its own glyph. Text too wide for the DMD scrolls as a marquee automatically.
- **Why:** It needs no font asset or licence, the dots stay crisp, and long translations stay legible.
- **Consequences:** Languages that aren't Latin-based (CJK, Cyrillic and so on) will need a pixel font asset rendered into the DMD viewport. Revisit this when such a language is requested. DMD strings in `strings.csv` should be ≤ 21 characters, or they will scroll.
- **Status:** Accepted

### D-028 — Shell flow and `--game` behaviour (refines D-003)
- **Date:** 2026-11-20
- **Decision:**
  - The shell runs one mode at a time: picker, attract, game, initials or operator.
  - On the picker, Start, Launch and Exit act on *release*, and only for taps under 0.9 s. This lets holding Start+Exit for 3 s, or Exit for 5 s, open the operator menu without side effects (D-024).
  - Exit during a game aborts it with no high-score entry.
  - When started with `--game=<id>`, Exit during the game quits the app. After game over (and initials entry, if earned), a picker locked to that game asks "PLAY AGAIN?", and Exit there quits.
  - Attract starts after `operator.attract_delay` seconds idle, but only in the unlocked picker.
- **Status:** Accepted

### D-029 — Operator menu behaviour
- **Date:** 2026-11-20
- **Decision:**
  - **Display changes** are staged, then applied with a 15-second "keep or undo" countdown. Launch keeps them, and Exit or the timeout reverts. A wrong monitor choice can't strand the cabinet.
  - **Identify monitors** shows each monitor's 1-based number and resolution.
  - **Remapping** captures the next physical press within 6 s. The new binding replaces that action's bindings of the same kind (keyboard vs joypad) and is removed from any other action. "Reset to defaults" restores D-019.
  - **Destructive actions**, such as resetting high scores, need a second press.
  - **Saving:** settings are saved on "Save and exit" or when Exit leaves the main page.
- **Status:** Accepted

### D-030 — Dev automation flags (extends D-017)
- **Date:** 2026-11-20
- **Decision:**
  - `--mode=operator|attract|initials` opens a shell mode directly.
  - `--press=a,b,c` simulates cabinet actions, one every 12 frames. `wait` skips a slot, and `hold:start+exit:3.5` holds actions for a set time.
  - `--screenshot=<dir>` now also saves every secondary window as it is displayed (`window_dmd.png` shows the dot shader).
  - Placeholder games give fake points (Launch = +1000) and end the game on Start, so the game-over → high-score flow can be tested.
- **Status:** Accepted
