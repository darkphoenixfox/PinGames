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

### D-031 — Quitting the app needs confirmation (refines D-028)
- **Date:** 2026-11-20
- **Decision:** Tapping Exit on the picker opens a "QUIT?" overlay on the TABLE and DMD. Launch or Start quits; Exit, any flipper or magna save, or 5 s without input cancels. When the app was started with `--game`, Exit during a game no longer quits straight away. It goes to the locked "PLAY AGAIN?" picker with the quit confirmation already open, so one Launch press returns to the frontend.
- **Why:** The director asked for this. It prevents quitting by accident from the cabinet.
- **Status:** Accepted

### D-032 — Asset licensing: commercial-safe only
- **Date:** 2026-11-20
- **Decision:** PinGames may be distributed commercially, so **every asset must allow commercial use and modification**. This covers music, SFX, models, textures, fonts and AI-generated output.
  - **Preferred:** CC0, then CC BY (credit given in the format below).
  - **Case by case, with the director's approval:** CC BY-SA (edited versions must use the same license), and permissive font licenses such as SIL OFL.
  - **Not allowed:** NonCommercial (-NC), NoDerivatives (-ND), "personal use only", or unclear and missing licenses.
  - **AI tools** (Meshy, music generators and others): the plan or terms in force when the asset was generated must grant commercial rights. Record the plan in CREDITS.md. Free tiers often don't grant them.
  - **Attribution format (TASL):** "Title" by Author (source URL), licensed under LICENSE (license URL), plus any changes made, e.g. "looped and trimmed". Keep proof of the license, such as a screenshot or saved page dated at download, in `assets/licenses/` (not shipped).
- **Why:** This is the director's call; commercial distribution is possible.
- **Consequences:** The game will have an in-game credits screen (attract page and operator System Info), generated from `assets/CREDITS.md` data (M6). Before any commercial release, every row in CREDITS.md is re-checked.
- **Status:** Accepted

### D-033 — Asset intake from the director's drop folder; music playback
- **Date:** 2026-11-20
- **Decision:**
  - **Intake:** the director drops raw assets into `C:\Users\Phoenixfox\Dev\PinGamesAssets` (outside the repo). Claude imports **only the files the director names**. Other files there are staged for later and are left alone. Originals are never moved or deleted.
  - **Processing tools:**
    - `scripts/tools/to_ogg.sh <in> <out> [trim]` converts audio to OGG Vorbis q6 with ffmpeg, optionally trimming silence at both ends. Don't trim tracks that are already seamless loops.
    - `scripts/tools/sprite_cutout.py` removes a plain background from AI-generated sprites by flood fill from the border, then crops and scales them.
  - **Layout in the repo:**
    - `assets/audio/music/<main|game id>/`
    - `assets/models/<game id|shared>/`
    - `assets/sprites/<game id|shared>/`
    - `assets/source/` for kept originals
    - `assets/licenses/` for license proof
  - **Music playback:** `Audio.play_music(path, fade)` loops OGG and fades out the previous track. `Audio.MUSIC_MAIN` plays on the picker, and in attract mode only when `attract_sounds` is on. Games stop the shell music on start and play their own tracks (`MUSIC` const in the module).
- **Why:** The director asked Claude to organise the assets. Only named files are imported because the director stages future assets in the same folder.
- **Status:** Accepted

### D-034 — Local ComfyUI is an asset source
- **Date:** 2026-11-20
- **Decision:** ComfyUI on the director's PC (`http://127.0.0.1:8188`, RTX 5080) can generate assets:
  - images: Qwen-Image 2.1, FLUX.2 klein 4B, FLUX.1-dev
  - 3D: Hunyuan3D 2.x image-to-3D
  - video: MiniMax H3
  - audio: Stable Audio 3 medium

  Claude may call its API to generate assets **only when the director asks**. Results go through `scripts/tools/` (background cutout, scaling, OGG conversion) into `assets/`.
- **Licensing (D-032):** a model's license applies to its output, so check it before shipping that output. Until each one is verified:
  - **Preferred:** models with permissive licenses (Apache 2.0, for example), to be confirmed per model.
  - **Avoid for shipping assets:** FLUX.1-dev (non-commercial model license).
  - **Check carefully before use:** Hunyuan3D (Tencent community license, which has territory exclusions and conditions), Stable Audio (Stability community license, with revenue thresholds) and MiniMax H3.
  - **Record:** each generated asset's CREDITS.md row names the model, the workflow and the date.
- **Status:** Accepted (per-model license verification pending)

### D-035 — Approved generation models (refines D-034)
- **Date:** 2026-11-20
- **Decision:** The director approves these models for PinGames assets:
  - **Images:** Qwen-Image 2.1 (incl. turbo)
  - **3D:** Hunyuan3D 2.0 / 2.1
  - **Video:** MiniMax H3, if we render any videos

  Other installed models (FLUX.1-dev, FLUX.2 klein, Stable Audio) are not used for shipping assets unless the director approves them later.
- **Why:** The director's call. The director accepts the model licenses for the project. Claude flagged Hunyuan3D's territory restrictions in D-034, and they should be re-checked before any commercial release in excluded regions.
- **Consequences:** Generation requests default to Qwen-Image for 2D, Hunyuan3D for models (alongside Meshy, D-020) and MiniMax H3 for video. Each asset's CREDITS.md row records the model, the workflow and the date.
- **Status:** Accepted

### D-036 — Hunyuan3D license restrictions accepted
- **Date:** 2026-11-20
- **Decision:** The director has reviewed Hunyuan3D's license restrictions (territory and conditions) and accepts them for PinGames. The re-check note in D-035 is closed.
- **Status:** Accepted

### D-037 — The block breaker is named "TILT BREAKER"
- **Date:** 2026-11-20
- **Decision:** The block breaker is called **TILT BREAKER**. The game id stays `breakout`. "Flipanoid" was rejected: an itch.io brick breaker by StrictPossum (2022) already uses that name, and "-anoid" echoes Taito's Arkanoid trademark.
- **Why:** The director's choice. Web searches on 2026-11-20 found no game called "Tilt Breaker", "TiltBreaker" or "Tilt-Breaker". The nearest titles were a jam game "TILT-out" (GameDevJS 2025) and the iOS "Tilt 'n' Tumble". "TILT" is also pinball's penalty word, which fits the pinball theme.
- **Consequences:** Do a proper trademark search before any commercial release; the web searches don't count as legal clearance.
- **Status:** Accepted

### D-038 — Model viewer and Blender for headless model processing
- **Date:** 2026-11-20
- **Decision:**
  - **Model viewer:** `--mode=viewer --model=res://...glb` shows a model on the TABLE screen, auto-framed, with its size and triangle count. Flippers rotate it, Launch toggles the spin, Start cycles views (3/4, front, top, side) and Exit leaves. With `--screenshot` it serves both director reviews and Claude's checks.
  - **Blender:** Blender 5.3 at `C:\dev\Blender\blender.exe` is available for headless (`--background --python`) model processing: decimating over-budget meshes, fixing orientation and scale, resizing textures, and pre-rendering sprites from 3D (GDD §8). Scripts go in `scripts/tools/`, and the director never needs to open Blender.
- **Why:** The director has no editor workflow (D-004), but models still need review and processing.
- **Status:** Accepted

### D-039 — Assets with no stated source are director-made
- **Date:** 2026-11-20
- **Decision:** If the director hands over an asset without naming a source, it was made by the director with one of: ComfyUI (approved models, D-035), Gemini Pro or Meshy Pro. These are paid or approved tools, so they're cleared for commercial use. Record it in CREDITS.md as "Director-made". Ask about the source only when the director names a third-party source (a website, an artist or a pack), which then needs the usual license check (D-032).
- **Why:** The director's instruction. It saves a round trip for every asset.
- **Status:** Accepted

### D-040 — Tilt Breaker architecture: pure sim + 3D view
- **Date:** 2026-11-20
- **Decision:**
  - **Split:** gameplay lives in `games/breakout/sim.gd`, a pure simulation with no nodes. It uses custom circle-vs-rect collision (`ball_physics.gd`) with substeps of at most 0.05 units, so the ball can't tunnel through anything. `game.gd` renders the sim in 3D and turns cabinet actions into sim inputs.
  - **Camera:** orthographic, leaning 20° towards the player, with 16 units fitted to the TABLE height (9 units wide).
  - **Lighting:** linear tonemapping, to keep arcade colours saturated. Flat surfaces get no or low specular, because an orthographic camera turns specular into a uniform grey sheen.
  - **Placeholders:** the paddle is the director's `paddle.glb`, scaled to the gameplay width. Bricks are coloured boxes until the art pass.
- **Why:**
  - Deterministic, frame-rate-independent physics that can be tuned and tested headless: an autopilot plays 3 minutes in the tests.
  - Godot's physics engine is unnecessary for arcade ball rules and harder to make exact.
- **Consequences:** Later features (flippers, multiple paddles, floors, power-ups) go into the sim first, with tests, and the view follows.
- **Status:** Accepted

### D-041 — Tilt Breaker art direction and fiction
- **Date:** 2026-11-20
- **Decision (director):**
  - The bricks are a sentient, self-replicating nanomachine alien race, with 16-bit-style circuit and chip textures.
  - The ball is a plasma shot with a trail, fired from the ship with Launch.
  - Rebounds off the ship show its energy shield deflecting the plasma.
  - Lives are energy charges.
  - The ship banks a little when moving, while its hitbox stays a constant rectangle. Its side rocket engines emit blue flame particles.
- **Implementation:**
  - **Bricks:** 64x32 textures generated by `scripts/tools/gen_circuit_bricks.py`, 6 colour families × 4 variants. The glow mask is a **separate greyscale PNG**, because Godot's "fix alpha border" import bleeds colour into low-alpha pixels. The textures are projected top-down by `brick_circuit.gdshader`, which pulses the glow with a per-brick `instance uniform` phase.
  - **Plasma:** a billboard shader (`plasma.gdshader`) plus a ribbon trail. **Shield:** `shield.gdshader`, with a ripple from the hit point. **Engines:** GPU particles plus omni lights, with thrust driven by paddle velocity. All the effects are in `games/breakout/fx.gd`.
  - **Visual only:** none of the effects read back into the sim (D-040).
- **Also:** the tests now compile every project script. This caught two errors that the gameplay tests didn't load, including an inner class named `Engine`, which clashes with Godot's built-in `Engine`.
- **Status:** Accepted

### D-042 — Tilt Breaker: afterburners, firing and recoil (refines D-041)
- **Date:** 2026-11-20
- **Decision (director):**
  - **Afterburners:** the side engines are off when the ship is still. While moving, only the trailing side burns (moving right = left engine), as a cone of particles.
  - **Plasma:** invisible until fired. Pressing the button shoots it from the ship, with a sound and a ship shake.
- **Implementation:**
  - **Engines:** `CPUParticles3D` in local coordinates, with a 3° spread and a 1→0 scale curve, which gives the cone shape. Length and light grow with speed. `GPUParticles3D` was tried first, but its particles didn't move in this setup, so CPU particles are used (two small emitters cost almost nothing).
  - **Firing:** Launch **and** Start fire, since the director said "start button" and Launch was specified earlier. The shot gives a recoil kick of 0.18 units towards the player plus a 0.05-unit shake, decaying over 0.3 s, and a muzzle-flash halo.
  - **Dev:** `--press` gained `down:`/`up:` steps and `--screenshot-delay=N`, to capture mid-action frames.
- **Status:** Accepted (confirm whether Start should fire in addition to Launch)

### D-043 — Tilt Breaker: planet backdrop and impacts
- **Date:** 2026-11-20
- **Decision (director):**
  - An earth-like planet's surface runs across the bottom of the screen: huge (minimal curvature), out of focus, glowing. The ship moves up to make room.
  - A lost plasma shot plays an explosion sound and lights up the planet where it would have hit.
- **Implementation:**
  - **Placement:** `Fx.Planet` is a sphere of radius 100 (vs a 9-unit field), placed by orthographic maths so its silhouette sits 1.7 units above the screen bottom, with its centre 30 units behind the playfield.
  - **Look:** `planet.gdshader` draws procedural fbm oceans, land and clouds. The rim term is raised to a high power (14), because only a thin slice near the silhouette is ever visible; a low power makes the whole slice glow. A slightly larger additive shell (`atmosphere.gdshader`) adds haze above the horizon.
  - **Focus:** `CameraAttributesPractical` far DOF (from 26 units) blurs the planet and keeps the playfield sharp.
  - **No floor:** the opaque floor was removed (space background), and the walls now end at the horizon.
  - **Sim:** `PADDLE_Y` is 5.9 and `DRAIN_Y` is 7.3 (the horizon line). The `lost` event now carries the exit x.
  - **Impact:** a ray from the exit point along the camera direction meets the sphere. The shader lights a wide area (it's seen at a grazing angle) with an expanding shockwave, plus a short additive fireball billboard and the `tb_explode` sound.
- **Status:** Accepted

### D-044 — Tilt Breaker game-over finale
- **Date:** 2026-11-20
- **Decision (director):** when the last plasma is lost, the explosion covers the whole screen, fades to black, then shows game over and the score.
- **Implementation:**
  - The last `lost` event calls `Planet.impact(..., big=true)`: a fireball that grows to 18× (about 40 units, covering the TABLE) over 1.1 s, with `tb_explode_big`.
  - At 0.9 s a black overlay fades in over 0.8 s.
  - At 1.9 s GAME OVER, "FINAL SCORE" and the score fade in on the TABLE, and the DMD and backglass switch to the same.
  - At 6 s the module emits `finished` (high-score entry or the picker). From 2.6 s, Launch/Start skips ahead.
  - Fix found on the way: billboard materials need `billboard_keep_scale`, otherwise every fireball stayed at its base size.
- **Status:** Accepted

### D-045 — Brick textures come from the director's circuit art (supersedes the procedural textures in D-041)
- **Date:** 2026-11-20
- **Decision (director):** bricks use the director's `circuit_red/green/blue.png`. Each brick is a rectangle cut from a random spot, giving a low-pixel texture per brick. There are 3 colours.
- **Implementation:**
  - **Preparation:** `scripts/tools/prepare_circuit_textures.py` keeps the 2048 px originals in `assets/source/breakout/` and writes 512 px box-downsampled copies to `assets/textures/breakout/`.
  - **Shader:** `brick_circuit.gdshader` samples with nearest filtering. Each brick gets a random texel-snapped `crop_offset` (instance uniform), and `crop_size` is the brick footprint: 64 texels across, aspect-correct. Crops are re-randomised for each new rack.
  - **Bevel:** a 1-texel bevel (light top-left in the glow colour, dark bottom-right) separates the bricks, because the art is continuous.
  - **Glow:** the glow mask is derived from the texture (bright and saturated pixels).
  - **Colours:** rows run red, red, green, green, blue, blue.
  - **Retired:** the procedural generator and its 48 textures were removed.
- **Status:** Accepted

### D-046 — Pixel-art brick explosions
- **Date:** 2026-11-20
- **Decision (director):** bricks break with pixelated explosions and particles.
- **Implementation:**
  - **Blast:** `pixel_explosion.gdshader` on a billboard quad, with UVs quantised to a 14×14 grid. It's a ragged ring that expands and hollows out, with a stepped palette (white, yellow, orange, brick colour), and dissolves through ordered dithering over 0.45 s (`age` instance uniform tweened).
  - **Particles:** 28 `CPUParticles3D` hard-edged square quads, each in one flat palette colour (constant-interpolation `color_initial_ramp`), with gravity and damping.
  - **Brightness:** kept at modest HDR so bloom doesn't blur the pixels.
- **Status:** Accepted

### D-047 — Lives shown as plasma-ball icons
- **Date:** 2026-11-20
- **Decision (director):** remaining lives (charges) are shown as plasma-ball icons at the top of the screen.
- **Implementation:** `plasma_icon.gdshader` is a canvas shader matching the in-game plasma look. The HUD has one 64 px icon per starting charge, and a spent charge becomes a faint ring. The DMD and backglass still show "CHARGES n" as text.
- **Status:** Accepted

### D-048 — Yellow circuit texture; quiet test runs
- **Date:** 2026-11-20
- **Decision:**
  - **Yellow:** `circuit_yellow.png` (director) is added as a fourth brick colour. Rows are red, red, yellow, green, blue, blue until stage layouts (M2 step 3) set colours per stage.
  - **Quiet test runs:** Claude's visual test runs use `scripts/dev_run.sh`. It does three things:
    - writes a temporary, git-ignored `override.cfg` with `display/window/size/no_focus=true` for that run only, so the windows don't take focus from the director;
    - puts the windowed layout on monitor index 1 (`PINGAMES_DEV_MONITOR`), the director's secondary screen, with `render_scale=1.0` so screenshots stay full resolution;
    - runs a headless import first, so new assets load.
- **Why:** The director asked that test runs not come to the foreground.
- **Status:** Accepted (no_focus behaviour to be confirmed by the director)

### D-049 — Tilt Breaker: starfield, no walls, edge shields
- **Date:** 2026-11-20
- **Decision (director):**
  - Add a starfield to the black background that rotates when the ship moves.
  - Remove the level barriers. A rebound at the screen edge, a little inside it, shows the shield rebound effect at the hit point.
- **Implementation:**
  - **Starfield:** `starfield.gdshader` on a ColorRect in a `CanvasLayer(layer=-1)`, used as the 3D background through `Environment.BG_CANVAS` (`background_canvas_max_layer=-1`). It has three parallax layers of square pixel stars rotating around a pivot far below the screen. The angle is advanced each frame by a smoothed `-paddle_vx * 0.006` spin plus a small drift.
  - **No camera DOF:** it blurred the canvas background into bokeh blobs. The planet's defocus is now faked in `planet.gdshader` (3 noise octaves and soft coast and cloud edges, `softness`).
  - **Boundaries:** `Sim.FIELD` is now (-4.1, -7.1, 8.2, 15.1), 0.4 inside the 9-unit screen. `wall` events carry `[side, hit]`. Each side has a flat shield strip using `shield.gdshader`, with the ripple at the hit point. The wall boxes and the `tb_wall` sound were removed.
  - **Dev:** `--tb-show-shields` keeps the edge shields lit, for visual checks.
- **Status:** Accepted

### D-050 — 16-bit era sound effects, synthesized
- **Date:** 2026-11-20
- **Decision (director):** better, 16-bit-era sound effects.
- **Implementation:** `core/util/synth.gd` was rewritten. It renders at 32 kHz (SNES rate) and supports:
  - **waves:** square, 25 % and 12.5 % pulse, triangle, saw, sine, white noise, NES-style 15-bit LFSR noise;
  - **segments:** exponential pitch glide, arpeggios, vibrato, attack plus exp/lin/hold envelopes, one-pole low-pass;
  - **sound level:** layered voices, SNES-style feedback echo, bit-crushing, soft clipping.

  Sounds are cached per spec. All UI sounds (`Audio.UI_SOUNDS`) and Tilt Breaker sounds were redesigned. The legacy array format still works.
- **Why synthesize rather than download:** no licence tracking (D-032), a consistent sound across the bundle, and easy tweaking.
- **Status:** Accepted

### D-051 — Tilt Breaker energy blast, power bar, status only on the DMD (supersedes D-047's TABLE icons)
- **Date:** 2026-11-20
- **Decision (director):**
  - Holding L+R for 1 s and then releasing fires a blast straight up. It counts as one hit on a brick, then dissolves.
  - Each blast uses energy from a power bar. A full bar holds 3 shots, and recharging starts slowly 1 s after the last shot.
  - Lives, score and remaining power are shown only on the DMD.
- **Implementation:**
  - **Sim** (`sim.gd`, tested): `power`, `blast_charge` and `blasts`, plus the events `charge_start`, `charged`, `blast`, `blast_fail` and `blast_end`. Recharge runs at 1/15 per second after a 1 s delay. Brick damage is shared through `_damage_brick()`.
  - **DMD:** `Dmd.show_status()` draws a big score, life dots (5×5 plasma pixels) and a segmented power bar; the partly charged cell blinks.
  - **Visuals:** `blast.gdshader` bolt, a nose charge glow (a small plasma ball), recoil on firing, and a pixel explosion where the blast ends.
  - **Removed:** the TABLE HUD and the backglass score and charges.
- **Status:** Accepted

### D-052 — Tilt Breaker enemy: tetrahedron
- **Date:** 2026-11-20
- **Decision (director):** a polygonal tetrahedron enemy.
  - It teleports in through a wormhole in the top 10% of the screen.
  - It is about 2 bricks in size, with brick-style circuit textures on its faces, and rotates in 3D.
  - It moves in wide horizontal waves while slowly descending, and needs a path through the bricks or it stays at the top.
  - Plasma attacks (the ball and blasts) destroy it. Touching the ship destroys the ship, and the enemy self-destructs in a pixel explosion.
  - At ship height it circles widely around the bottom.
- **Implementation:**
  - **Sim** (`sim.gd`, tested):
    - **Enemy data:** `enemies` entries with states `wormhole` (1.2 s, not collidable), `sweep` and `orbit`.
    - **Sweep:** x = sin(phase) × 3.2, reversing when bricks block. It descends at 0.45 u/s only where the circle (r = 0.62) clears all bricks.
    - **Orbit:** starts at `PADDLE_Y - 1.1`, an ellipse with radii (2.6, 0.9).
    - **Collisions:** ball vs enemy is circle-circle, and the ball reflects. Blast vs enemy is rect-circle, and the blast is consumed. Enemy vs ship is circle-rect, triggering `_destroy_ship()`: lose a charge, 2 s invulnerability, reset the serve, or the game-over finale.
    - **Spawning:** first after 10 s of play, then every 14–22 s, at most 2 at once.
    - **Rack:** `BRICK_TOP` moved to -5.55, so the top area fits the enemy.
  - **View:**
    - **Body:** `Fx.make_tetrahedron` builds 4 faces, each a random crop of a random circuit colour (nearest filtering, emissive), plus glowing line edges, with a random spin axis.
    - **Wormhole:** `wormhole.gdshader`, a billboard vortex whose `open` (an instance uniform) is tweened open and closed.
    - **Death and respawn:** bigger pixel explosions, and the ship blinks during invulnerability.
    - **Sounds:** `tb_wormhole`, `tb_enemy_die`, `tb_ship_die`.
  - **Dev:** `--tb-enemy-now` brings the first enemy in 0.3 s after firing.
- **Status:** Accepted

### D-053 — Blast charge particles; smaller single-colour tetrahedrons
- **Date:** 2026-11-20
- **Decision (director):**
  - While charging, particles are collected towards a single point in front of the ship. Once charged, the plasma ball shows there.
  - The tetrahedron is 50% smaller, uses one texture colour per enemy, and at most 2 are on screen at the same time.
- **Implementation:**
  - **Charge particles:** `Fx.make_charge_particles` creates CPU particles on a ring (radius 0.9) with negative radial acceleration, tuned to reach the centre within their 0.35 s lifetime, plus a slight swirl. They emit only while `0 < blast_charge < 1`. The plasma ball (`_charge_glow`) shows only when fully charged.
  - **Tetrahedron:** `Sim.ENEMY_R` is 0.31 (it now fits through a single-brick gap). `make_tetrahedron` takes one texture, and the edge and explosion colours match it. The wormhole is scaled down to 1.7.
  - **Cap:** `ENEMY_MAX` stays at 2, unchanged.
- **Status:** Accepted

### D-054 — Three-level charged blast; no blasts before firing; faster ball speed-up
- **Date:** 2026-11-20
- **Decision (director):**
  - Charge time is cut by 20%.
  - The charge has up to 3 levels: blue particles, then a small blue sphere; yellow particles, then a medium yellow sphere; red particles, then a full-size red sphere. Each level takes the same time and has its own sounds, and enough power must be available for each level.
  - The "level reached" sound is a hum, not a beep.
  - No blasts while the plasma isn't in play.
  - The ball speeds up slightly on every ship touch, up to a reasonable maximum.
- **Implementation:**
  - **Charging:** `BLAST_CHARGE_TIME` is 0.8 s per level. `blast_charge` is measured in levels, capped by `affordable_level()` (floor(power / ⅓)). The events are `charge_start(level)` and `charged(level)`. Charging and firing are only allowed in `State.PLAY`.
  - **Firing:** level n costs n/3 power. **Assumed (director didn't specify):** a level-n blast pierces up to n bricks or enemies (`hits_left`), with hitbox width scaling 0.75/1.0/1.3 × `BLAST_W`, and a bigger, brighter bolt.
  - **View:** particle tint per level (`CPUParticles3D.color`), with `Fx.tint_plasma` and the sphere scale 0.5/0.75/1.0 showing the reached level. Sounds: `tb_charge1-3` (rising sweeps), `tb_level1-3` (low sine/triangle hums with vibrato and echo, pitch rising by level) and `tb_blast1-3`.
  - **Ball:** `SPEEDUP_PER_PADDLE_HIT` is 0.25 (was 0.12, too subtle) and `BALL_MAX_SPEED` is 13.5 (was 15).
  - **Tests:** `Sim.freeze_ball` is a test hook so long charge holds don't drain the plasma.
- **Status:** Accepted (blast-level effect is an assumption to confirm)

### D-055 — Blast level effect confirmed (closes the assumption in D-054)
- **Date:** 2026-11-20
- **Decision (director):** a level 1 blast breaks 1 block or enemy. Level 2 carries on after 1 hit (2 in total). Level 3 carries on after the second impact (3 in total). This is what `hits_left = level` already implements.
- **Status:** Accepted

### D-056 — Shorter charge; DMD pixel animations
- **Date:** 2026-11-20
- **Decision (director):**
  - Charge time is 15% shorter.
  - Add short DMD pixel animations, for example a tetra hit by a ball and exploding.
- **Implementation:**
  - **Charge time:** `BLAST_CHARGE_TIME` is 0.68 s per level.
  - **Animation API:** `Dmd.play(anim: Callable, duration)` draws `anim(painter, t)` every frame over everything else, and a new animation replaces the current one. `Dmd.Painter` offers `dot`, `line`, `disc`, `ring`, `text` and `text_center` in logical 128×32 dots, scaled for bigger DMDs. Any game can use it.
  - **Tilt Breaker clips** (`games/breakout/dmd_anims.gd`, durations in `DURATIONS`): `tetra_hit` (only when shot down; `enemy_destroyed` now carries a shot-down flag), `incoming`, `charge_lost`, `ship_destroyed` and `rack_clear`. They replace the earlier text flashes and are skipped while the game-over finale owns the DMD.
  - **Dev:** `--tb-dmd-anim=<name>` loops one clip.
- **Status:** Accepted

### D-057 — Debug tools: P pause, F piercing line
- **Date:** 2026-11-21
- **Decision (director):** add debug tools: P pauses, and F fires a plasma ball that destroys everything in a vertical line.
- **Implementation:**
  - **Autoload:** `DebugTools` (`core/debug_tools.gd`, `PROCESS_MODE_ALWAYS`) reads raw keys only when `OS.is_debug_build()`, so exported release builds ignore them. `--debug-tools=off` disables them.
  - **P:** toggles `get_tree().paused` and shows "PAUSED" on the TABLE.
  - **F:** emits `debug_action(&"fire_line")`. Tilt Breaker calls `Sim.debug_fire_line()`, a free level-3 blast with unlimited hits, spawns its view node and plays the sound directly, because events raised between steps would be lost.
  - **Robustness:** `_animate_blasts` now creates missing blast nodes instead of indexing past them.
  - **Dev:** `--press` gained `key:<Name>` for raw keyboard taps.
- **Status:** Accepted

### D-058 — Tilt Breaker backglass art with event-driven lights
- **Date:** 2026-11-21
- **Decision (director):** use `breaker_lights_off` / `breaker_lights_on` for the backglass. The "on" image has some areas lit, and game events make those lights blink on and off.
- **Implementation:**
  - **Prep:** `scripts/tools/prepare_backglass_lights.py` keeps the originals in `assets/source/breakout/` and writes 1920×1080 off/on images plus an RGB group mask. It differences the two images, then assigns connected lit regions by their centre: R = engines (exhaust), G = shots (plasma comets), B = impacts (hits and lightning). The result was 3/6/9 regions.
  - **Display:** `backglass_lights.gdshader` cross-fades off→on per group by `levels` (vec3), with a small extra boost on lit pixels.
  - **Light logic:** `backglass_lights.gd` holds idle engine breathing, engine drive from ship speed, shots glow while charging, `pulse(groups, dur, hz)` square-wave blinks that fade, `chase()`, and `set_dark()`.
  - **Event hooks:** fire → shots; shield → shots (short); brick → impacts; enemy kill and blast → shots + impacts; lost charge or ship → all (alarm); rack clear → chase; game over → all blink, then dark.
  - **Dev:** `--tb-lights-on` holds all groups lit, for mapping checks.
- **Status:** Accepted

### D-059 — "PLASMA CANNON READY" prompt
- **Date:** 2026-11-21
- **Decision (director):** replace "LAUNCH TO FIRE" with a blinking "PLASMA CANNON READY".
- **Implementation:** the `TB_PRESS_LAUNCH` text changes. The TABLE prompt is cyan and blinks (0.5 s on, 0.3 s off) while waiting to fire.
- **Status:** Accepted

### D-060 — PinPixel: the bundle's pixel-art UI font
- **Date:** 2026-11-21
- **Decision (director):** create a pixel-art font that fits the game style.
- **Implementation:**
  - **Design:** `scripts/tools/gen_pixel_font.py` (fontTools, installed with `pip --user`) builds `assets/fonts/pinpixel.ttf` from pixel-grid glyph drawings. The style is 16-bit sci-fi arcade: 2-pixel strokes, squared letters with chamfered corners, and a 9-pixel cap height.
  - **Coverage:** A–Z, 0–9, punctuation, and Latin accents (á é í ó ú, à è ì ò ù, ä ë ï ö ü, â ê î ô û, ñ ã õ ç ¡ ¿) for translations. Lowercase maps to the same capitals. Commas and semicolons have tails below the baseline.
  - **Metrics:** UPM 1200 with 1 font pixel = 100 units, so at size N one font pixel is N/12 screen pixels.
  - **Use:** project-wide theme font (`gui/theme/custom_font`). Import has antialiasing, hinting and subpixel positioning off. `UI.label()` snaps sizes to multiples of 12 (`UI.pixel_size`), with a 2-font-pixel outline.
  - **DMD:** keeps its own 5×7 dot font (D-027).
- **Status:** Accepted

### D-061 — Tilt Breaker attract mode and intro
- **Date:** 2026-11-21
- **Decision (director):**
  - The game starts in attract mode, with high scores and pixel animations on the DMD.
  - Start shows a game-start message on the DMD and in the middle of the screen.
  - The wall forms with bricks arriving in sequence, dropping into place in 3D.
  - The ship blasts in from the bottom of the screen on a bottom afterburner.
- **Implementation:**
  - **Phases:** `game.gd` runs `attract` → `intro` → `play`, and the sim isn't stepped until `play`.
  - **Attract:** the TABLE shows the title and a blinking PRESS START. The DMD step list shows title/PRESS START, "HIGH SCORES" and the top 5, and the `tetra_hit` / `incoming` / `rack_clear` clips plus the credit status.
  - **Intro:** Start or Launch plays the start jingle, shows GET READY (DMD and TABLE) and runs a backglass chase. Bricks drop with a 22 ms stagger, a 0.4 s fall from 9 units with an ease-out bounce and a little tumble, and a clack every few landings. The ship rises from z = 10.5 over 0.8 s on a belly `ShipEngine` (pointing +Z), then settles for 0.35 s.
  - **Engines:** `Fx.ShipEngine` now takes a `Vector3` direction.
  - **Dev:** `--tb-skip-intro`.
  - **Note:** in coin mode, the credit is still spent when the game is chosen on the picker (shell), not on the in-game Start.
- **Status:** Accepted

### D-062 — Per-game styled pixel title fonts
- **Date:** 2026-11-21
- **Decision (director):** a "retro pixel" style font (the director's reference: gradient fill, highlight, 3D drop), fitted to each game's theme, with a separate font per game. PinPixel (D-060) stays as the plain UI font.
- **Implementation:**
  - **Generator:** `scripts/tools/gen_title_fonts.py` renders PinPixel's glyph shapes at 3 atlas pixels per font pixel. Each glyph gets a vertical gradient, a 1 px top highlight, a softer left highlight, darker bottom/right edges, dither shading in the lower half, a 3 px extrusion down-right (3 shades) and a 1 px dark outline. Output is an RGBA atlas plus JSON metrics (47 px cells).
  - **Styles:**
    - `nano` (Tilt Breaker): white→cyan→blue→violet with a bright band, violet extrusion.
    - `squadron` (Sky Striker): yellow→orange→red.
    - `sunset` (Turbo Run): chrome pink/white over blue/cyan with a hard horizon split.
  - **Loader:** `core/ui/styled_fonts.gd` builds a fixed-size `FontFile` (`FIXED_SIZE_SCALE_INTEGER_ONLY`, so it scales only by whole multiples). RGBA8 atlas glyphs keep their baked colours.
  - **Usage:** `UI.styled_label(text, style, scale)`. Games expose `"font"` in `get_info()`, and the picker shows each game's name in its own font, dimmed when not selected. Tilt Breaker uses it for the attract title, PRESS START, GET READY, PLASMA CANNON READY and GAME OVER / FINAL SCORE.
  - **Shapes:** for now all three styles share PinPixel's letter shapes. Per-game letterforms can follow if the director wants them.
- **Status:** Accepted

### D-063 — Game logos: picker, backglass, DMD pixel art
- **Date:** 2026-11-21
- **Decision (director):** use `tilt_breaker_logo1.png` in the game select menu, and simulate `tilt_breaker_logo_horiz.png` on the DMD as pixel art.
- **Implementation:**
  - **Prep:** `scripts/tools/prepare_logos.py` keeps the originals in `assets/source/<game>/`. It writes `logo.png` (trimmed, ≤1200 px) and `dmd_logo.png`: trimmed, fitted to 32 dots high (70×32) through a 4× sharpened intermediate, with saturation, contrast and brightness boosted and hard alpha.
  - **Game info:** games may expose `"logo"` and `"dmd_logo"` in `get_info()`.
  - **Picker:** shows the selected game's logo on the TABLE (900×690 box) and the backglass. The DMD shows the pixel logo through the new `Dmd.show_image()`.
  - **Attract:** Tilt Breaker's attract step 1 is the `logo` DMD clip (drop-in with bounce, diagonal white glint over opaque pixels, sparkles). It uses the new `Painter.image()`.
- **Status:** Accepted

### D-064 — Updated backglass art with a lit title logo (4th light group)
- **Date:** 2026-11-21
- **Decision (director):** updated `breaker_lights_off/on`. The new art includes the TILT BREAKER logo, unlit and lit.
- **Implementation:**
  - **Prep:** `prepare_backglass_lights.py` puts lit regions centred in the top-centre (y < 30 %, 25–70 % x) into a **logo** group, written as a separate greyscale `backglass_mask_logo.png` (never in alpha). The result was 3/6/9/1 regions.
  - **Shader:** takes `vec4 levels` (engines, shots, impacts, logo).
  - **Light logic:** the logo is steady on in play and blinks slowly in attract. ALL pulses make it flicker, and the rack-clear chase now cycles four steps.
- **Status:** Accepted

### D-065 — In the picker, a game's logo replaces its name (refines D-063)
- **Date:** 2026-11-21
- **Decision (director):** the logo replaces the "TILT BREAKER" text in the game select menu; it isn't an extra image above the list. Logos for the other two games will follow.
- **Implementation:** each list entry is the game's logo if `get_info()` has `"logo"`, otherwise its styled title. The selected logo is 700×540 at full brightness; others are 400×300 and dimmed. The backglass (logo) and the DMD (pixel logo) still follow the selection. The vertical layout shifts slightly while only some games have logos, and it will be stable once all three do.
- **Status:** Accepted

### D-066 — Attract DMD animations show art only
- **Date:** 2026-11-21
- **Decision (director):** attract-mode animations don't show "+XXX" points, just the art.
- **Implementation:** `_dmd_anim()` passes empty `plus_enemy` / `plus_rack` texts while `_phase == "attract"`. In-game clips still show the points.
- **Status:** Accepted

### D-067 — Fix: charge effects linger after releasing a blast
- **Date:** 2026-11-21
- **Problem (director):** after releasing, the next level's charge sound and particles sometimes kept going while the bolt was already flying. Two causes:
  - The charge sfx is fire-and-forget, and the next level's 0.68 s sweep starts the moment a level is reached.
  - Stopping CPU particles only stops new emissions; live ones finish their 0.35 s life.
- **Fix:**
  - **Sound:** `Audio.sfx()` now returns its player, and `Audio.stop_sfx(player, name)` stops it only if that player is still playing that sound. Tilt Breaker keeps the charge sound and stops it on a new `charge_start`, on `blast`, and whenever the charge drops to zero.
  - **Particles:** the charge particles are hidden immediately when charging stops, and `restart()` clears them when a new charge begins.
- **Status:** Accepted

### D-068 — Levels from text files; level-complete sequence
- **Date:** 2026-11-21
- **Decision (director):**
  - When a level is completed, all remaining enemies explode, the ship flies away toward the top and toward the screen (3D), the screen fades to black, and the next level loads with the same brick-in and ship blast-in animations.
  - Level 1 is shorter (fewer bricks), and level 2 is a different pattern (not a rectangle).
- **Implementation:**
  - **Level files:** text in `games/breakout/levels/level_NN.txt` (R/Y/G/B/., `#` comments), listed in `Sim.LEVEL_FILES`, looping. Bricks carry `colour`/`col`, and points come from the colour (R 120, Y 100, G 80, B 60). Level 1 is 4×11 (44 bricks); level 2 is a 7-row stepped pyramid.
  - **Sim:** clearing the last brick adds `RACK_BONUS`, destroys the remaining enemies (no points), clears blasts and charge, and enters `State.LEVEL_CLEAR`, which freezes the sim. `next_level()` builds the next layout and resets the serve and the enemy timer. Tested.
  - **Game (`outro` phase):** at 0.5–1.9 s the ship rises (+y) and moves up the screen (-z) with ease-in, scales to 3.2× (the camera is orthographic) and pitches, on the belly afterburner, with a roar sound. It fades to black at 1.5 s. At 2.3 s it rebuilds the bricks and runs the intro, labelled "LEVEL n" (the DMD says LEVEL n / GET READY), fading back in. The DMD clip text is now "LEVEL CLEAR!".
  - **Debug:** a new key **C** (debug builds) clears the level instantly.
  - **Export note (M5):** level `.txt` files are non-resource files and must be added to the export include filter.
- **Status:** Accepted

### D-069 — Stuck paddle: release inputs on focus loss; input monitor; ship rotated
- **Date:** 2026-11-21
- **Problem (director):** the paddle sometimes gets stuck for a few seconds, more often near the screen edge.
- **Analysis:** the sim has no stall at the walls (re-tested). The candidates are on the input side:
  - **(a)** a Windows accessibility prompt (Sticky/Filter Keys, triggered by Shift) steals focus and the key-up is never delivered, so an action stays "held" and both-flippers freezes the ship;
  - **(b)** a Shift key-up being lost when both Shifts are held (to be confirmed).

  On the director's PC both shortcuts read as off (Flags = 26), so (a) is unlikely there.
- **Fix and diagnostics:**
  - **Focus loss:** `CabinetInput` releases every action on `NOTIFICATION_APPLICATION_FOCUS_OUT` and emits `focus_changed`.
  - **Input monitor:** debug key **I** shows a live overlay of held actions (with hold time) and focus, and logs every press, release and focus change to `user://input_log.txt`, to pin down the real cause next time.
- **Ship:** the director asked for the model to be rotated 180° so the cockpit faces up the screen, like the backglass. Applied as a Y rotation on `paddle.glb`. The model has glass on both faces, so the change is subtle; the director is confirming against an upside-down (X) alternative.
- **Status:** Accepted (cause pending log evidence)

### D-070 — Warn about Windows Sticky/Filter Keys shortcuts
- **Date:** 2026-11-21
- **Decision (director):** the game should warn if the Filter Keys or Sticky Keys shortcuts are on.
- **Implementation:** `core/system_checks.gd` (Windows only, once per run) reads `HKCU\Control Panel\Accessibility\StickyKeys` and `...\Keyboard Response` with `reg query`, and flags bits 0x1 (feature on) and 0x4 (shortcut on). The picker shows red warnings plus a how-to line, and the operator's System Info has a "KEYBOARD SHORTCUTS" row. Tests cover flag parsing: 26 = off, 510/126 = Windows defaults with the shortcut on. Dev flag: `--fake-keys-warning`. README has a cabinet setup note.
- **Status:** Accepted

### D-071 — Ship model orientation (supersedes the rotation in D-069)
- **Date:** 2026-11-21
- **Decision (director, with a reference image):** the camera should see the ship's **front face**, with the cockpit window at the top and vents/thrusters at the bottom, cockpit toward the top of the screen. The earlier Y-axis 180° turn was the wrong axis.
- **Implementation:** `paddle.glb` is pitched −90° about X (`model.rotation_degrees = (-90, 0, 0)`), so the model's +Z face points at the camera and the model's +Y (cockpit side) points up the screen (−Z). The hitbox, engines, shield and charge point are unchanged.
- **Status:** Accepted

### D-072 — Tilt Breaker power-ups, multi-ball, ship pass-through
- **Date:** 2026-11-21
- **Decision (director):** every 10 bricks, a 70 % chance of a power-up capsule (coloured sphere, letter, two orbiting "atom" particles). One at a time, lasting until level end or death. T triple laser, P power laser, B bounce plasma, I ion cannon, L lightspeed, S shield (see GDD). LOW POWER shows only in the bar area; the current power-up shows next to the bar, which takes its colour. The ship must not stop a ball coming back up from below.
- **Implementation:** sim `powerup`, `powerups`, `extra_balls` (main ball loss promotes an extra), `shield_active`, `ghost_xs()`, per-power-up `affordable_level`/`blasts_enabled`, `_fire()` with triple directions / ion column / extra ball. The paddle only bounces descending balls. View: `Fx.PowerupCapsule`, `ion_beam.gdshader`, extra plasma balls, ghost ships, shield strip, angled bolts, `Dmd.show_status(..., level, badge, badge_color, bar, warn)`. Debug key U drops the next capsule; `--tb-level=N`.
- **Assumption to confirm:** Lightspeed also makes the ship 30 % faster.
- **Status:** Accepted

### D-073 — Brick types, levels 1–10, enemy difficulty tiers
- **Date:** 2026-11-21
- **Decision (director):** levels 1 to 10 of increasing difficulty; every 5 levels enemies become faster and more aggressive.
- **Implementation:** lowercase letters = 2-hit armoured bricks (1.5× points, cracked look after a hit); `X` = indestructible metal. `brick_circuit` shader gains `mode` 0–3. `enemy_tier() = (level-1)/5`: speed ×(1 + 0.4·tier), spawn interval ÷(1 + 0.5·tier), max enemies +tier, orbits steer toward the ship from tier 1.
- **Status:** Accepted

### D-074 — Auto-fire at max charge; shield-hit and serve-cannon sounds
- **Date:** 2026-11-21
- **Decision (director):** maximum-level charged shots fire automatically; the ball's rebound off the ship sounds like a laser hitting a shield; serving plays a laser-cannon sound.
- **Implementation:** reaching `max_level()` (3, or 1 for Bounce) fires at once and blocks re-charging until the flippers are released. New `tb_shield` and `tb_fire` synth patches.
- **Status:** Accepted

### D-075 — LOW POWER only on long holds; capsule volume
- **Date:** 2026-11-21
- **Decision (director):** with an empty bar, show LOW POWER and its sound only if both flippers are held for more than 0.5 s. Give the capsules volume (shading on the sphere and the text). Shift still seemed to stick, so the flipper keys moved (final choice in D-077).
- **Implementation:** `blast_fail` fires once per hold after `LOW_POWER_HOLD` = 0.5 s. Capsule: low emission, glossy specular, rim light, small coloured key light, dark drop-shadow copy of the letter. Fix: capsules keep falling while waiting to serve.
- **Status:** Accepted

### D-076 — Power-laser effects, full bar per level, DMD level-change boost
- **Date:** 2026-11-21
- **Decision (director):** the P charge plays only the level-3 sound and particles; the power bar is full at the start of each level; add a DMD animation for the level-change ship boost.
- **Implementation:** P emits only `charge_start(3)` / `charged(3)`. `next_level()` sets `power = 1.0`. New DMD clip `ship_boost` (pixel ship scaling up on belly flames, star streaks, exit flash; new `Painter.block`). The outro lift-off moves to 0.9 s so "LEVEL CLEAR!" reads first.
- **Status:** Accepted

### D-077 — Default flipper keys: arrow keys (supersedes the keyboard part of D-019)
- **Date:** 2026-11-21
- **Decision (director):** `\` didn't work, so the flippers use the Left/Right arrow keys.
- **Why:** arrows exist in the same place on every keyboard layout and avoid the Shift / accessibility-shortcut problems.
- **Consequences:** `flip_l = key:Left`, `flip_r = key:Right`; controller unchanged (L1/R1). Encoders that send Shift can be remapped in the operator menu.
- **Status:** Accepted

### D-078 — Capsules refill one bar level; triple at 20°; ion beam one column
- **Date:** 2026-11-21
- **Decision (director):** grabbing a power-up capsule restores 1 level of the power bar; the triple shot's side bolts fly at 20° instead of 45°; the ion cannon must not break 2 brick columns at once.
- **Implementation:** collecting adds 1/3 bar (capped). `TRIPLE_ANGLE = 20`. `_ion_beam` burns only the brick column whose centre is closest to the beam (enemies anywhere in the beam still die).
- **Status:** Accepted (supersedes the ±45° of D-072)

### D-079 — Reverb on bounce and explosion sounds
- **Date:** 2026-11-21
- **Decision (director):** add a bit of reverb to the bounce and explosion sound effects.
- **Implementation:** the synth gets a `reverb: [decay_s, wet]` option, a small Schroeder room (4 damped feedback combs at 29.7/37.1/41.1/43.7 ms plus 2 allpasses) that extends the sample by its tail. Applied to `tb_shield` (ball bounce, 0.6 s / 0.3), `tb_explode` (1.0 s / 0.35), `tb_enemy_die` (0.9 s), `tb_explode_big` and `tb_ship_die` (1.4 s). These are rendered once at game load, which adds about 1.3 s of load time; there's no cost during play.
- **Status:** Accepted

### D-080 — 2-screen backglass: dedicated art, framed DMD at the bottom centre
- **Date:** 2026-11-21
- **Decision (director):** add `_2screen` versions of the backglass (on/off). On 2-screen cabinets, place the DMD at the bottom of the second screen, centred, with a frame around it.
- **Implementation:**
  - **Setting:** the existing operator layout setting (Windowed / 2 screens / 3 screens, D-006) chooses the mode. `Screens.dmd_in_backglass` is true for 2 screens, or whenever DMD output = backglass. The windowed dev layout honours it too, as a preview (`--display.dmd_sink=backglass`).
  - **Placement:** the backglass art is no longer squashed above a strip; it fills the screen. The DMD keeps its dot aspect, centred in `dmd_region`, whose default changes to `0.25,0.78,0.5,0.18`. Around it there is a bezel: a gunmetal border with a bright bevel, a drop shadow, and a thin cyan glowing inner trim.
  - **Art:** Tilt Breaker loads `backglass_{off,on,mask,mask_logo}_2screen.png` in that mode. `prepare_backglass_lights.py` gains a suffix argument with grouping tuned for the higher framing: engines below 42 % height, the logo above 22 %, and a comet touching the logo split off into shots.
- **Status:** Accepted (supersedes the full-width DMD strip of D-013)

### D-081 — Tilt Breaker background music
- **Date:** 2026-11-21
- **Decision (director):** use "n-Dimensions (Main Theme - Retro Version)" (opengameart.org/content/space-dimensions-8bitretro-version, CC BY 3.0) as Tilt Breaker's background music.
- **Implementation:** converted to `assets/audio/music/breakout/n_dimensions.ogg` (Vorbis q6, untrimmed, because it already loops cleanly). The original is kept in `assets/source/breakout/`. `game.gd start()` plays it on the Music bus, looping, through attract, intro and play.
- **Attribution:** "Matthew Pablo" (from the MP3's artist tag). The OGA page returned 403 to automated fetching, so the licence and credit name need a manual check and screenshot, like the other OGA tracks.
- **Status:** Accepted

### D-082 — Tilt Breaker attract-mode music
- **Date:** 2026-11-21
- **Decision (director):** "My Very Own Dead Ship" by yd (CC0, opengameart.org/content/background-space-track) is the music for Tilt Breaker's attract mode. The director also confirmed D-081's track as CC BY 3.0 by Matthew Pablo.
- **Implementation:**
  - `_enter_attract()` plays `dead_ship_attract.ogg`, and `_begin_intro()` crossfades to the game track (n-Dimensions). `--tb-skip-intro` starts the game track directly.
  - **Format:** the director asked for a conversion to MP3, but the file was already Ogg Vorbis, the project format (D-023). It stays OGG: re-encoding to MP3 loses quality, and MP3 encoder padding puts a gap in loops. The 0.76 s of leading silence was trimmed with `to_ogg.sh trim` for a gapless loop.
- **Status:** Accepted

### D-083 — Smooth explosions (supersedes the pixel-art look of D-046)
- **Date:** 2026-11-21
- **Decision (director):** make the explosion effects less pixelated; they clashed with the rest of the art style.
- **Implementation:**
  - `pixel_explosion.gdshader` is replaced by `explosion.gdshader`. It's a billboard fireball with an fbm-noise billowing edge, an ease-out expansion and a smooth heat gradient (white → yellow → orange → brick colour). A faint shockwave ring travels ahead of it and the whole effect fades over 0.55 s. There's no UV quantising or dither any more.
  - The square pixel debris becomes soft additive round sparks (a shared radial-gradient material) that cool from white to the brick colour and shrink as they fade.
  - This applies to every explosion that goes through `_explode_brick`: bricks, armour cracks, enemies and lost shots.
- **Status:** Accepted

### D-084 — Lost shield ends the power-up; yellow recharge flash
- **Date:** 2026-11-21
- **Decision (director):**
  - When the shield is used up, return to the normal plasma cannon.
  - Every time the power bar recharges a level, the ship flashes yellow briefly. For 3-level guns that's every third of the bar; for 1-level guns, when the bar is full.
- **Implementation:**
  - **Shield:** the barrier save calls `_end_powerup()`. The bar and the charged shot come back, and the DMD badge clears.
  - **Flash:** a yellow additive `material_overlay` on all ship meshes, fading over 0.3 s, quadratic. It triggers when `floor(power × levels)` rises during play. Bounce and Ion count as 1-level guns; Lightspeed and Shield have no bar, so they never flash. Capsule refills count as recharges.
- **Status:** Accepted

### D-085 — Ship settles before the level-change lift-off
- **Date:** 2026-11-21
- **Decision (director, bug):** if the ship was moving when the level ended, the transition kept its offset position, bank and side thrusters. Reset it to neutral before it flies off.
- **Implementation:** `_begin_outro()` clears the paused sim's `paddle_vx`, so per-frame banking levels out and the side thrusters cut. During the 0.9 s before lift-off, the ship glides (smoothstep) from where it was to the centre of the field. Then it lifts off on the belly engines as before.
- **Status:** Accepted

### D-086 — 2-screen DMD 20 % bigger
- **Date:** 2026-11-21
- **Decision (director):** make the 2-screen DMD 20 % bigger.
- **Implementation:** the default `dmd_region` changes from `0.25,0.78,0.5,0.18` to `0.2,0.755,0.6,0.216`. The DMD is about 933×233 px at backglass base resolution (it was 777×194), and its frame keeps a ~15 px margin above the bottom edge.
- **Status:** Accepted (refines D-080)

### D-087 — Explosions revised: solid brick-coloured fireball, shard debris
- **Date:** 2026-11-21
- **Decision (director):** after D-083, the fireball transparency was too strong and created a weird hue; the particles were tiny dots that didn't feel like debris; debris should match the brick colour.
- **Implementation:**
  - **Fireball:** `explosion.gdshader` switches from additive to normal blending, so it reads solid over the bricks. Its palette is white-hot core → brightened brick colour → deep brick colour, with no orange stage. Noise holes open up only in the second half of its life.
  - **Debris:** 16 tumbling box shards (0.13×0.05×0.09, scale 0.5–1.5) in a lit, glowing material in the brick's colour (cached per colour). They spin up to ±720°/s and shrink to nothing over 0.8 s.
- **Status:** Accepted (supersedes the look of D-083)

### D-088 — Shell screens show each game's backglass art
- **Date:** 2026-11-21
- **Decision (director):** on the game select screen, the backglass shows the selected game's backglass, not its logo; the same applies to the high score screens.
- **Implementation:**
  - **Registry:** `get_info()` gains an optional `backglass` path (Tilt Breaker: the lit `backglass_on.png`). `Registry.backglass_art(id)` picks its `_2screen` version when `Screens.dmd_in_backglass`, and `Registry.backglass_rect()` builds a full-screen cover TextureRect.
  - **Screens:** the picker, the attract-mode high-score pages and the initials-entry screen show the art. Games without backglass art keep the old fallback (logo, then styled title on the picker; title or "NEW HIGH SCORE" text elsewhere). The initials screen still shows "NEW HIGH SCORE" on the table.
- **Status:** Accepted

### D-089 — Turbo Run prototype: 3D road, auto/manual pedals, drift, nitro
- **Date:** 2026-11-21
- **Decision (director):** start the racer prototype using the director's `red_car.glb`. Gameplay in the OutRun style: a road with turns and ups and downs, racing the clock, checkpoints, obstacles beside the road, traffic, and an emphasis on drifting in corners. Automatic accelerate/brake on 2+1 buttons, manual on 4 buttons. Holding 2 buttons for 2 seconds fires nitrous. Models should be PS2-level with 16-bit-looking textures, made with ComfyUI/Blender when needed.
- **Implementation:**
  - **Sim and track:** pure `games/racer/sim.gd` plus `track.gd`, headless-tested. Road coordinates are s/x. Curves push the car outwards by curvature × v² × 0.21, against a steering authority of 12 m/s, so the sharpest curves can't be held at full speed without drifting or braking.
  - **Drift:** while drifting, the push is 45 %, the steering is ×1.25 and the drag is small. Drifting refills nitro.
  - **Nitro:** both flippers held for 2 s, which also means no steering meanwhile.
  - **View:** `game.gd` streams 100 m road chunks (one SurfaceTool strip each, `road.gdshader` with 25 cm texels and 8 m light/dark bands) and MultiMesh props built in code from a 160×32 procedural atlas (`scenery.gd`).
  - **Cars:** `car.gdshader` samples the car texture nearest. Traffic recolours it with a per-instance hue rotation.
  - **Camera and effects:** a chase camera with FOV kick, drift roll and shake, CPU particle tyre smoke and dust, and nitro flames.
  - **Sound:** engine and squeal are generated looping WAVs; the other sounds are Synth one-shots.
  - **Music:** the CodeManu menu and race loops (D-033).
- **Car model:** the original is kept in `assets/source/racer/`. `scripts/tools/prepare_racer_car.py` (headless Blender) decimates it from 10.8k to 4k tris, scales it to 4.4 m, drops the normal and ORM maps, and writes a 256 px albedo PNG. The game samples that PNG directly, because the glb's embedded texture didn't come through Godot's import. The model's nose is +Z, so the view turns it 180°.
- **Why 3D instead of a sprite scaler (GDD §5.3 proposal):** the director supplied a 3D car and asked for PS2-level models. Real 3D gives hills, banking views and drift yaw for free. The 16-bit look comes from texel-snapped shaders and nearest filtering.
- **Dev flags:** `--rc-skip-intro` and `--rc-autopilot`. The attract mode is the autopilot driving.
- **Tuning to confirm in playtests:** start time 45 s, +34 s per checkpoint every 1.8 km, top speed 288 km/h (360 with nitro), drift entry above about 150 km/h.
- **Status:** Accepted (prototype)


### D-090 — Turbo Run car: keep the full mesh, no decimation (supersedes the car-model line of D-089)
- **Date:** 2026-11-21
- **Decision (director feedback "the car model looks broken"):** the D-089 collapse-decimate from 10.8k to 4k tris tore the red car's UV seams and smoothing, which caused black slivers, smeared paint and faceted panels. The game now uses the full 10.8k-tri mesh, which is already a PS2-level budget. The PS2/16-bit look comes only from the 256 px nearest-filtered albedo and the dropped normal/ORM maps.
- **Tool:** `prepare_racer_car.py` decimates only when given a tris target (default 0 = keep the mesh). It also takes an optional texture size.
- **Cost:** player plus 10 pooled traffic cars is about 120k tris, trivial for the cabinet GPU.
- **Lesson:** don't collapse-decimate textured AI meshes blindly. Render a before/after check (Blender workbench) before shipping a reduced model.
- **Status:** Accepted

### D-091 — Turbo Run: cel-shading render style
- **Date:** 2026-11-21
- **Decision (director approved Claude's recommendation):** cel-shade the racer.
  - **Cars:** `car.gdshader` has a custom `light()` with 3 flat diffuse bands and one hard highlight; metallic is off.
  - **Props:** the scenery material uses Godot's toon diffuse with specular disabled.
  - **Outlines:** an inverted hull (`games/racer/toon.gd`, `shaders/outline.gdshader`) on the cars and roadside props. It is pushed along normals averaged per position, so UV seams and hard edges don't crack it. The width grows with distance, so it stays about 2–3 px on screen.
  - **Left unoutlined:** road, sky and mountains, so the distance stays clean through the fog.
- **Why an inverted hull, not a screen-space edge pass:** it is cheap, works with pooled traffic and MultiMesh props, and doesn't produce noisy edges on the pixel textures.
- **Consequences:**
  - Mirrored transforms would flip the hull's culling, so props are never mirrored. Left lamps are turned 180°, and left chevrons are a separate mesh (`chevron_l`) with flipped UVs.
  - The dev flag `--rc-no-toon` shows the plain look for comparison.
- **Status:** Accepted (prototype look, pending director review)

### D-092 — Turbo Run: cars turn like 32-angle sprites, steering turns the nose on straights
- **Date:** 2026-11-21
- **Decision (director):** instead of smooth realistic turning, cars behave as if there were only 32 views of the car around 360° (simulated sprites). Steering left or right on a straight should visibly turn the car a bit, not only in corners.
- **Implementation:**
  - `game.gd` snaps each car's yaw *relative to the camera view* to steps of 11.25° (`SPRITE_ANGLES` = 32), so the car pops between views like a pre-rendered sprite set. This covers the player (steer, drift and crash spin) and traffic.
  - Full steer adds 0.3 rad of nose turn (`STEER_YAW`, about 1.5 steps). It used to be 0.08 rad, which was below one sprite step.
  - Body roll is removed, since a sprite can't lean. Pitch still follows the hills.
- **Status:** Accepted (prototype)

### D-093 — Turbo Run music: the five CodeManu "action" loops
- **Date:** 2026-11-21
- **Decision (director):** the `bgm_action*` tracks (CodeManu, CC BY 3.0, confirmed by the director) are the right music for Turbo Run. They were already in the repo as `assets/audio/music/racer/codemanu_action_1..5.ogg` (D-033), but only `action_1` played and attract mode used the menu loop.
- **Implementation:**
  - Attract plays `action_5`.
  - Each race starts on the next action track in turn, and every checkpoint (new stage) fades to the following one.
  - `codemanu_menu.ogg` stays in the repo but is no longer used by the racer.
- **Status:** Accepted

### D-094 — Turbo Run: no hillsides across the road
- **Date:** 2026-11-21
- **Problem (director):** at some point a green hill went across the track.
- **Cause:** the ground strip reaches 140 m to each side and rises away from the road. On the inside of tight curves (radius ~75 m) it folded back over the road. Long curve sections could also turn up to ~320°, so the road looped back and one stretch's hillside landed on another.
- **Fix:**
  - **Track:** a curve section turns at most 110°, and the overall heading stays within 80° of the start direction. If a curve would pass that, it turns the other way or is shortened. The road always makes forward progress and never doubles back.
  - **View:** on the inside of a curve the ground stops at 0.75 × radius, with a floor at the kerb plus 4 m.
  - **Test:** for 3 seeds over 30 km each, the heading stays within the limit and no stretch comes within 160 m of road 400 m or more earlier.
- **Status:** Accepted

### D-095 — Turbo Run music starts on action_3 (amends D-093)
- **Date:** 2026-11-21
- **Decision (director):** attract and the first race play `codemanu_action_3`. Later races and checkpoints step on from there (4, 5, 1, 2, …).
- **Status:** Accepted

### D-096 — UI rule: blinking and changing elements never move their neighbours
- **Date:** 2026-11-21
- **Problem (director):** in Turbo Run's attract screen, the flashing PRESS START made the instructions below it move up and down. That is bad UX: changes in one UI element must not make others dance.
- **Cause:** the blink toggled `visible`, and a hidden Control collapses in its VBoxContainer. Tilt Breaker's attract screen had the same bug.
- **Rule:** blink with `modulate.a`, which keeps the layout space. Elements whose text changes length inside a container get a fixed minimum size or their own anchored slot.
- **Status:** Accepted

### D-097 — Turbo Run nitro is a bar that drains while held and refills over time (supersedes D-089's charges)
- **Date:** 2026-11-21
- **Decision (director):** instead of hold 2 s, then fire a charge, nitro is a bar.
  - **Drain:** holding both flippers burns it for as long as they are held.
  - **Refill:** it recovers over time when not in use.
- **Tuning:**
  - Both flippers must be held 0.15 s before it burns, so a stray double tap doesn't fire it.
  - A full bar lasts 4 s.
  - It refills from empty in 14 s, starting 1 s after the last burn.
  - Drifting adds 6 % per second, and each checkpoint adds 30 %.
  - Emptying the bar or crashing stops the burn until both flippers are released.
- **HUD:** one 300 px bar replaces the 3 pips and the hold-progress bar. It flickers white while burning and dims when low.
- **Sounds and strings:** the hold-charge and +1 sounds and the `RC_NITRO_PLUS` string are removed.
- **Exhaust flames:** they are now children of the car body (they used to be on the road frame), so they follow its yaw, drift and sprite steps. They sit on the model's exhaust pipes (x ±0.57 m, 0.28 m up, at the rear bumper), which are lower and wider than before. The cone is thinner (0.1 m radius).
- **Status:** Accepted (tuning pending playtest)

### D-098 — Turbo Run: roll-over crashes, stepped crash animation, low camera, nitro gauge
- **Date:** 2026-11-21
- **Decisions (director):**
  - **Roll-over crash:** hitting a big roadside obstacle (palm, rock or lamp) flips the car over sideways. `sim.flipping` and `flip_dir` make it roll away from the obstacle, the crash lasts 2.0 s (`FLIP_TIME`) and speed drops to 10 m/s or less. Chevron signs and traffic still cause a spin-out.
  - **Sprite-like crash animation:** fewer animation steps, to simulate sprites. Crash animations advance on 10 fps steps (`ANIM_FPS`). A roll-over is a hop of 1.6 m with one full sideways roll shown in 8 poses (45° each), around the body's middle. Spin-outs are stepped too. Yaw stays snapped to the 32 views (D-092).
  - **Camera:** lower and closer to the road (2.3 m, was 3.6 m), with the car kept at the same height on screen. The camera pitches so the car sits 15.9° below the screen centre (`CAM_CAR_DEG`, the old framing). The horizon now sits just above the car.
  - **Nitro gauge:** the bar becomes a half-dial gauge (`games/racer/nitro_gauge.gd`): 14 lit segments, a needle and a percentage in a fixed-width slot. It starts at 100 %. The old bar's background stretched wider than its fill, so a full bar looked partly empty.
- **Status:** Accepted (prototype)

### D-099 — Turbo Run traffic: both directions, trucks
- **Date:** 2026-11-21
- **Decision (director):** add the director's `truck.glb` to the road, and have cars drive in the correct lane directions. Some traffic is caught up from behind, and some comes from the front.
- **Lanes:** right-hand traffic.
  - The two right lanes (x > 0) drive our way and are caught up from behind.
  - The two left lanes are oncoming (`v < 0`). They spawn further out (560–810 m), because they close fast.
  - Trucks and 40 % of cars keep to the outer, slow lane of their side.
- **Mix:**
  - 40 % of spawns are oncoming.
  - 25 % are trucks, with at most 3 on the road at once.
  - Trucks are 10 m × 2.66 m and drive at 20–26 m/s (18–24 m/s oncoming).
  - The traffic target is min(4 + checkpoints, 11).
- **Collisions:**
  - Checks use each vehicle's own length and width.
  - Any hit with oncoming traffic is a crash.
  - Hitting a truck (head-on, or rear-ending it at more than 22 m/s) rolls the car over, since trucks are big obstacles (D-098).
  - Bumping a truck doesn't speed it up.
  - Near misses and passes score in both directions.
  - The autopilot looks further ahead for oncoming traffic.
- **View:**
  - Pooled nodes per kind: 10 cars and 3 trucks.
  - Oncoming vehicles face the camera, also snapped to the 32 sprite views.
  - Trucks aren't hue-shifted.
- **Truck model:** the full 11k-tri mesh is kept and scaled to 10 m (2.66 m wide, 3.28 m tall), with a 512 px texture because it is big on screen. `prepare_racer_car.py` gained a length argument.
- **Status:** Accepted (prototype)

### D-100 — Silent test runs; own tyre-smoke puffs
- **Date:** 2026-11-21
- **Silent runs (director):** mute the game when testing. `scripts/dev_run.sh` passes `--audio-driver Dummy` by default, and `PINGAMES_DEV_SOUND=1` keeps sound.
- **Tyre smoke:** the `CPUParticles3D` rear-wheel emitters sometimes drew a pure-black puff fixed at the emitter, at the start of drifts. It happened with cel shading on and off, and disappeared with the smoke off. They are replaced by our own pooled billboard puffs: one MultiMesh with up to 192 puffs, spawned every 16 ms per wheel and fading over 0.6 s. This gives full control over each puff.
- **Status:** Accepted

### D-101 — Turbo Run harder: more traffic, longer stages, crashes stop the car, 90° roll-over
- **Date:** 2026-11-21
- **Decision (director):** the race is too easy.
  - **Traffic:** the target is now min(7 + 2 × checkpoints, 16), up from min(4 + n, 11). Trucks go up to 4 at once, and the view pools are 16 cars and 4 trucks.
  - **Checkpoints:** every 2.3 km, up from 1.8 km. The time bonus is unchanged, so each stage is tighter.
  - **Crash stop:** every crash ends with the car stopped dead for 1.5 s (`CRASH_STOP`) while the clock keeps running. `sim.crash_progress()` drives the animation and `sim.stalled()` covers the stop. There is no smoke or squeal while stopped.
  - **Big crash** (roll-over, D-098): the car first slews 90° across the road (first 25 % of the 2 s animation), then hops and rolls one full turn about its own length, so it tumbles towards the front of the road (to 80 %). It lies still, and in the last 0.4 s of the stop it turns back to face the road. Everything is stepped like sprite frames.
  - **Spin-out:** now two full turns, so it ends nose-forward before the stop.
  - **Smoke:** puffs come less often at low speed, so they don't pile up into one opaque cloud.
- **Status:** Accepted (tuning pending playtest)

### D-102 — Tilt Breaker: losing a life refills the power bar
- **Date:** 2026-11-21
- **Decision (director):** after losing a life (ball drained or ship destroyed), the blast power bar resets to 100 % (3 cells).
- **Status:** Accepted

### D-103 — Turbo Run: gears, nitro pick-ups, dashboard dials, checkpoint on momentum (supersedes D-097, and D-098's nitro gauge)
- **Date:** 2026-11-21
- **Decisions (director):**
  - **Checkpoint on momentum:** after TIME UP the car coasts (7 m/s² decel, still steerable, no auto-brake). If it reaches the next checkpoint before stopping, the time is added, JUST MADE IT! shows and the race goes on. The game only ends once the car stops short.
  - **Nitro is a pick-up:** the bar is replaced by canisters on the road, every 0.7–1.2 km in any lane (the first on the start straight). Driving through one gives 5 s of boost, up to 100 m/s; another canister restarts the 5 s. A crash ends the boost. Canisters are glowing cyan bottles at 1.8× scale, cel-outlined, spinning and bobbing on stepped 10 fps frames.
  - **Gears L and H:** both flippers held 0.5 s shifts. Holding on doesn't shift again; release both first. L pulls 1.25 × ACCEL but tops out at 50 m/s (180 km/h, the rev limiter). H pulls 0.3 × at 0 rpm, rising to 1.05 × at 60 % rpm, and tops out at 80 m/s. L is much faster off the line, and the best shift point is near the redline (rpm ≥ 0.88). The autopilot shifts by itself, and the race starts in L.
  - **TABLE dashboard:** the director's reference icon style for all dials (`games/racer/dial.gd`): a segmented arc from thin dashes to thick blocks, lit to the value, with a needle and a ring hub. Bottom row: a tachometer (0–8 × 1000 rpm, red from 7), a GEAR box (L yellow, H white) with a blinking SHIFT light and a nitro timer strip, and a speedometer (0–360 km/h, digital readout under the hub). Everything has fixed-size slots (D-096). `nitro_gauge.gd` is removed.
  - **DMD dashboard:** `Dmd.show_custom(callable)` is a new API for game-drawn frames, called with the Painter each frame, with flashes still drawn over it. The racer draws a segmented speed dial with a needle, digital speed and KM/H, the score, a gear box, the clock, and a 13-cell horizontal tachometer bar (green, yellow, red from 7/8) that blinks red when it's time to shift.
- **Strings:** the DMD TIME and SPEED keys and NO NITRO are removed. New keys: RC_SHIFT_HINT, RC_GEAR, RC_GEAR_L, RC_GEAR_H, RC_GEAR_FLASH, RC_SHIFT, RC_RPM and RC_JUST_MADE_IT.
- **Status:** Accepted (tuning pending playtest)

### D-104 — Turbo Run attract music: "Maximum Overdrive" by Bogart VGM
- **Date:** 2026-11-21
- **Decision (director):** Turbo Run's attract mode plays "Maximum Overdrive" by Bogart VGM (https://opengameart.org/content/maximum-overdrive, CC BY 3.0, as stated by the director; the page refuses automated reads, so the license wasn't re-checked by tool).
- **File:** `assets/audio/music/racer/bogart_maximum_overdrive.ogg`, converted from the director's MP3 (Vorbis q5, 3:30) and looped by `Audio.play_music`.
- **Races:** they still use the CodeManu action loops, starting on action_3 (D-093, D-095).
- **Status:** Accepted

### D-105 — Turbo Run: TIME UP slide, high beams, music per 4 stages, faster rolling crash
- **Date:** 2026-11-21
- **Decisions (director):**
  - **TIME UP slide:** when time runs out, the car swings 90° (6 stepped frames over 0.6 s, nose towards the inside of the bend) and slides to a stop sideways with tyre smoke and squeal. It turns back if a checkpoint reached on momentum saves it (D-103).
  - **High beams:** an oncoming car flashes its high beams (flash-flash-pause) while you drive at it in its lane: 8–170 m ahead with lateral overlap under 2.6 m. It honks once, two tones with an echo. The flares are additive pixel-puff billboards at each model's headlights (car 0.95 m, truck 1.3 m), and the sim exposes `traffic.flash`.
  - **Music:** the race song stays the same through stages 1–4, changes at stage 5, then every 4 stages (`MUSIC_STAGES`). Each race still starts on the next song (D-095).
  - **Rolling crash:** 1.5× faster (`FLIP_TIME` is now 1.33 s, was 2.0). The car keeps tumbling down the road: speed is capped at 30 m/s and drops evenly to 0 by the end of the roll (about 20 m). A head-on with oncoming traffic stops the car on the spot instead, so it doesn't tumble through the other vehicle.
- **Status:** Accepted

### D-106 — Turbo Run: stage 1 always plays action_3; rolled car slides to a stop
- **Date:** 2026-11-22
- **Music (director):** stage 1 had gone back to the song the director doesn't like, because each new race moved on one song (D-093), so by the third race it was action_1 again. Now every race starts on action_3 (`FIRST_TRACK`), and songs change only at stage 5, 9, … (D-105). This supersedes D-093's "next song each race".
- **Rolled-car slide (director: "stops like a dead stone"):** a roll-over now goes roll → slide → stop.
  - **Roll:** the car rolls at up to 30 m/s, slowing at only 6 m/s².
  - **Slide:** it lands on its side and keeps sliding, smoking, at 11 m/s² until it stops (`sim.crash_slide`).
  - **Stop:** only then does the 1.5 s `CRASH_STOP` start.
  - **Distance:** about 50 m from the hit to the stop, up from about 20 m.
- **Status:** Accepted

### D-107 — Turbo Run art direction: pixel renderer, painted sky, sprite palms/bushes/signs (supersedes D-091's ink outlines)
- **Date:** 2026-11-22
- **Target (director):** the director's pixel-art mock-up: a 16-bit sunset highway with a red sports car, traffic and trucks. The director's notes: no guardrails; add signs, super-scaler style bushes and road signs; sprite-based palms; ignore car lights; no thick outlines.
- **Pixel renderer:** the 3D world renders in its own 360 × 640 SubViewport (1/3 of the TABLE), shown full-screen with nearest upscaling and `pixel_post.gdshader` (24 levels per channel, 4 × 4 Bayer dither, +12 % saturation). The HUD stays at full resolution on top. Ink outlines are thinned to about 1 low-res pixel (`outline.gdshader` width 0.03).
- **Sky:** a Qwen-Image pixel-art sunset panorama (sun, clouds, stars, purple mountains) on a 2000 m ring that follows the camera (`sky_panorama.gdshader`). The image covers half the ring, is mirrored for the other half, and its sun faces the start direction. The procedural sky takes the image's top colour, and fog takes the mountains' colour. The procedural mountains shader and the light's sky sun are removed.
- **Sprites** (`games/racer/sprites.gd`, `assets/sprites/racer/`): unshaded, alpha-scissor, nearest, Y-billboard quads in the chunk MultiMeshes.
  - **Palms:** 2 variants, 9.5–11 m.
  - **Bushes:** 2 variants. They line both sides densely, 70 % per side every 9–16 m, as scenery only (no collision, so leaving the road is unchanged).
  - **Curve warning signs:** they replace the 3D chevrons, mirrored for left turns.
  - **Green direction signs:** on straights every 350–650 m.
  - **Overhead gantries:** spanning the road about every 1.4 km on straights, facing the road rather than billboarded.
  - Rocks and lamps stay low-poly 3D.
- **Track:** new object kinds `bush`, `sign` and `gantry`. The objects are re-sorted by s after each section is placed, because `objects_between` binary-searches them.
- **Art pipeline:** `scripts/tools/comfy_qwen.py` (Qwen-Image 2.1 through the local ComfyUI API) generates the art, and `scripts/tools/prepare_racer_sprites.py` cuts out the white background, removes grey-framed holes (the gantry truss) and does a whole-factor nearest downscale with hard alpha. Originals are kept in `assets/source/racer/gen/`. Passing the director's mock-up as a reference image made Qwen redraw the whole scene, so prompts describe the style in words instead.
- **Next:** road dressing to match the highway look (the kerbs and sand are still the race-track style), lighting tuning, speed streaks, sparks.
- **Status:** Accepted (in progress)

### D-108 — Tilt Breaker uses its 2-screen backglass everywhere; new logos
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Tilt Breaker backglass:** the `_2screen` backglass art (framed with room for the DMD, D-080) is used on 3-screen cabinets too, in game and on the shell screens (`backglass` info key → `backglass_on_2screen.png`). The 3-screen textures are removed; their originals stay in `assets/source/breakout/`.
  - **Tilt Breaker logo:** the updated `tilt_breaker_logo_horiz.png` (the i is now dotted with a plasma orb) gives a new DMD logo.
  - **Turbo Run logo:** the director's `turborun_logo.png` is the picker logo and the DMD logo (79 × 32). It also appears on the attract screen and the backglass, replacing the styled text title. The backglass shows the game's sunset sky with the logo until there's real backglass art. The PROTOTYPE label is gone.
- **Pending:** the updated `breaker_lights_off_2screen.png` has the orb-dotted i, but `breaker_lights_on_2screen.png` in the asset folder is still the old lit art without it. Pairing them would make the logo change shape when it lights, so the backglass light textures wait for a matching lit version.
- **Status:** Accepted

### D-109 — Turbo Run backglass art with lights; Tilt Breaker lit logo updated
- **Date:** 2026-11-22
- **Turbo Run:** the director's `turborun-backglass_{off,on}` pair replaces the sky-and-logo placeholder (D-108). `scripts/tools/prepare_racer_backglass.py` differences the pair into two light groups: the logo (top-right box, `backglass_mask_logo.png`) and lights (R channel: headlights, truck lights, sparks, stars). It reuses Tilt Breaker's lit-backglass shader.
  - **Attract:** the logo blinks slowly and the lights stay on.
  - **Race:** both groups are on. Checkpoints, nitro and near misses flash them, and a crash makes the lights flicker out for 0.8 s.
  - **Game over:** only the logo stays lit.
  - The info key `backglass` points at the lit art for the shell screens.
- **Tilt Breaker:** the director re-saved `breaker_lights_on_2screen.png` with the orb-dotted i, matching the off art, so the 2-screen light textures are rebuilt (engines 3, shots 5, impacts 8, logo 2 regions). This resolves D-108's pending item.
- **Status:** Accepted

### D-110 — Turbo Run gear indicator is a lever in an H/L gate
- **Date:** 2026-11-22
- **Decision (director):** the TABLE gear indicator becomes a shift lever with L and H positions, instead of a letter in a box.
- **Implementation:** `games/racer/gear_lever.gd` draws a top-down shift gate with a slot, H at the top and L at the bottom. The knob is yellow in L and white in H, and the lit position's letter is bright. On a shift the knob slides between the two positions in 3 stepped frames over 0.12 s (sprite-like, D-098). The plate is a fixed 150 × 210 slot, so nothing else moves (D-096). The DMD gear box is unchanged.
- **Status:** Accepted

### D-111 — Turbo Run: Maximum Overdrive for stages 1–5
- **Date:** 2026-11-22
- **Decision (director):** stages 1–5 play "Maximum Overdrive" (Bogart VGM, D-104), carried on seamlessly from attract mode. Stage 6 switches to the CodeManu action songs, starting on action_3, and they change every 4 stages after that (stages 10, 14, …). This supersedes the stage-1 song in D-106 and the stage-5 switch in D-105.
- **Status:** Accepted

### D-112 — Turbo Run: shift effects, revving on the grid, crash downshift, new sounds
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Downshift:** puffs of tyre smoke from the rear wheels for 0.5 s, plus a short tyre chirp. No chirp during a crash.
  - **Upshift:** a short exhaust flame from both pipes (0.25 s, half the nitro flame's length, base kept on the pipe) and a backfire crackle.
  - **Revving on the grid:** during the countdown, holding a flipper revs the engine. rpm rises at 2.2/s and falls at 1.4/s; the tachometer and engine sound follow, and the rev limiter bounces the pitch at the top. The car doesn't move.
  - **Crash downshift:** every crash shifts to L by itself, so the car pulls away again properly.
  - **Sounds:** the timer, drift-points and nitro beeps are replaced with richer 16/32-bit style effects. The timer is a woodblock tock. Banking drift points plays a bell cascade with an octave-down shadow, coin shimmer, echo and reverb. Nitro is a turbo whoosh with a growl, a sub-bass boom and a shimmering tail in a big reverb.
- **Status:** Accepted

### D-113 — Turbo Run: night from stage 5, with faked car and lamp lights
- **Date:** 2026-11-22
- **Decision (director):** stage 5 transitions to night. Low beams come on for every car, and the lights from cars and lamp posts are simulated with transparent flat polygons.
- **Fade:** from stage 5 the scene fades to night over 8 s and stays night. Attract mode is always day.
  - **Backdrop:** the sky keeps the clouds' shapes in deep blues, and the sun turns into a pale moon. The plain sky above it is graded the same way, in linear colour.
  - **Lighting:** ambient light, the sun (now moonlight) and fog turn moonlit blue. The pre-lit sprites are tinted towards (0.3, 0.34, 0.58).
- **Lights** (`games/racer/night.gd`): additive, unshaded flat polygons with vertex-colour gradients, sharing materials whose alpha follows the night level.
  - **Cars, player and traffic:** a 22 m low-beam strip on the road ahead, small headlight glows and red tail lights. The player's lights hide during a roll-over.
  - **Lamp posts:** a light pool on the road under the head (pitched with the road), a faint vertical cone of light from the head, and a glow at the head. They are one MultiMesh per chunk.
- **Dev flag:** `--rc-night` forces night from the start.
- **Status:** Accepted

### D-114 — Turbo Run: off-road crash recovery, TRN plate, steering delay
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Off-road crash recovery:** a crash that ends off the road puts the car back on it. During the 1.5 s stop, the car slides over to the outer lane (`RECOVER_X`, ±5.6 m) and arrives as the stop ends.
  - **Number plate:** the hero car has a rear plate reading TRN (`RC_PLATE`): a pale 0.56 × 0.15 m plate with dark PinPixel letters on the rear bumper.
  - **Steering delay:** the nose only turns once steering has been held for 0.15 s (`STEER_DELAY`), then eases in. Short flipper taps still steer the car, but no longer flick the sprite angle back and forth.
- **Status:** Accepted

### D-115 — Turbo Run: DMD event animations, nitrous tank pick-up
- **Date:** 2026-11-22
- **DMD animations (director: small animations for near miss, nitro, gear shift, crash, etc.):** `games/racer/dmd_anims.gd` holds pixel animations played with `Dmd.play`. They replace the plain text flashes.
  - **Near miss:** another car whooshes past ours with sparks.
  - **Nitro:** the car lunges forward on a flickering flame through speed lines.
  - **Shift:** the knob jumps across an H/L gate in stepped frames. It isn't shown for a crash's own downshift.
  - **Crash:** an impact burst, a car tumbling through 4 poses and a shaking CRASH!.
  - **Checkpoint:** a waving chequered flag and the time bonus.
  - **Drift:** the banked points rise out of a ring of sparkles.
- **Nitro pick-up:** a Qwen-Image 16-bit nitrous tank sprite (a blue bottle with a big red N) replaces the cyan 3D canister. It is a 2.6 m camera-facing billboard bobbing on stepped frames, and it is untinted at night so it stays readable.
- **Status:** Accepted

### D-116 — Turbo Run: perfect shift, SHIFT warning, rev flames, engine and sound pass, California plate
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Perfect shift:** a green band on the tachometer (TABLE dial and DMD bar) covers rpm 0.78–0.87, just below the red. Upshifting inside it gives +3 m/s, 0.8 s of extra pull (+0.6 × ACCEL) and 2,000 points, with PERFECT SHIFT! on the TABLE, a DMD animation, a sting and a backglass flash.
  - **SHIFT warning:** after 3 s at the redline in L, a big blinking SHIFT appears mid-screen in the timer's font (PinPixel 144, red).
  - **Exhaust flames:** the upshift flame is shorter (0.16 s, a third of the length) and yellow. Nitro still burns blue. Revving on the grid spits short yellow flames with a backfire while held high, and once as the revs drop.
  - **Engine:** three layers mixed by rpm and speed, 16/32-bit rather than realistic. A firing-pulse body with uneven cylinders and a sub tone; a harmonic whine that rises with the revs; filtered wind noise with speed. Revving on the grid is louder, and the rev limiter bounces.
  - **Sound effects:** the chiptune beeps are replaced with racing-style ones. Soft start-light tones; GO over a brass stab; a brass fanfare with a timpani boom for checkpoints; a falling brass phrase for time up; a Doppler pass for near misses; a mechanical clunk for gear changes; a thud and clank for bumps; boom, metal crunch and breaking glass for crashes.
  - **Number plate:** California style, drawn once into a 192 × 96 viewport texture. A cream plate, red CALIFORNIA, orange stripes and sun, bold navy TRN and an orange THE GOLDEN STATE, all as translation keys. It is oversized (0.6 × 0.3 m) so TRN reads at pixel scale.
  - **Finale:** the distance uses the score's styled font, tinted cyan.
- **Status:** Accepted

### D-117 — Turbo Run: wider perfect-shift band, exhaust blast, shorter steering delay
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Perfect-shift band:** twice as wide, rpm 0.69–0.87 (was 0.78–0.87).
  - **No centre message:** PERFECT SHIFT! no longer appears in the middle of the TABLE. The DMD animation, sting, backglass flash and the tachometer band stay.
  - **Exhaust blast:** the boost is made visible with a long orange flame for its whole 0.8 s push, plus a backfire, a small camera shake and +5° of FOV.
  - **Steering delay:** halved, from 0.15 s to 0.075 s (D-114).
- **Status:** Accepted

### D-118 — Turbo Run: perfect start; debug cheat to freeze the clock
- **Date:** 2026-11-22
- **Perfect start (director):** if the revs are inside the perfect-shift band (rpm 0.69–0.87, D-117) at the moment of GO, the car launches at 12 m/s with 1.5 s of extra pull and 2,000 points. A PERFECT START! DMD animation, the sting, a backfire, the orange exhaust blast and a backglass flash go with it. Over-revving into the red, or not revving, gives a normal start.
- **Debug cheat (director):** in debug builds, F (DebugTools' game-specific `debug_action`, D-057) toggles `sim.freeze_time`, which stops the race clock. It persists across races in the session and shows DEBUG: TIME FROZEN under the timer. Exported release builds ignore DebugTools, so cabinets are unaffected.
- **Status:** Accepted

### D-119 — Turbo Run: speed-scaled steering, no small SHIFT label, crash portraits
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Steering:** sideways movement scales with speed. Authority is clamp(v / 40, 0.06, 1) × STEER (it was clamp(v / 25, 0.3, 1)), so a slow car barely moves across the road and full authority comes from 144 km/h.
  - **SHIFT label:** the small blinking SHIFT above the gear lever is removed. The big SHIFT nag after 3 s at the redline (D-116) stays.
  - **Crash animation:** after a short impact burst, the DMD shows original pixel portraits. A blond passenger in a pink top yells at the driver: angry brows, a mouth snapping open and shut, a shaking head, an anger mark and shout lines. The driver, in a red jacket and black sunglasses, sits there with a sweat drop sliding down. CRASH! blinks on the left. The animation runs 2.0 s.
- **Status:** Accepted

### D-120 — Turbo Run: gear-dependent handling; car lamps light their own texture
- **Date:** 2026-11-22
- **Handling (director):** in H the car slides wider in bends (centrifugal push × 1.3). In L it grips (push × 0.85, steering authority × 1.3), so you downshift to hold the inside line.
- **Car lamps (director: the red circles were misplaced; light up the car's texture instead):** `car.gdshader` adds emission to the model's own tail-light and headlight texels. They are picked by model-space boxes (rear |x| 0.2–0.7, y 0.7–0.9; front |x| 0.45–0.82, y 0.55–0.8) and scaled by texel brightness. Instance uniforms: `lamps` (night level) and `brake`. The hero car's brake lights come on when braking, auto-braking or coasting out after TIME UP. Traffic cars get `lamps` at night. The billboard glow dots are dropped for cars; trucks, a different model, keep them.
- **Status:** Accepted

### D-121 — Turbo Run: second truck model, S skip-to-night cheat, nitro/drift/perfect sounds
- **Date:** 2026-11-22
- **Second truck (director):** `truck2.glb`, a US-style tractor with a striped trailer, mixes with the first truck. The full 35.8k-tri mesh is kept and scaled to 10 m (2.89 m wide, 3.18 m tall), so the sim's truck size still fits. The model is fixed per vehicle (odd traffic ids get truck2), with a pool of 4 per model.
- **Debug S (director):** DebugTools' new S key (debug builds only) emits `skip_stage`. Turbo Run jumps to stage 5: the checkpoint count is set, the next checkpoint is moved one stage ahead, and the clock gets at least 60 s, so night falls.
- **Sounds (director: nitro and drift still beeped):**
  - **Nitro:** an ignition "fwoomp" (noise burst falling through a low-pass, a growling roar and a sub boom).
  - **Drift points:** a short brass stab over a tyre-release swoosh.
  - **Perfect shift/start:** a rising brass stab with a turbo whoosh.
  - None of them has a tonal chiptune lead any more.
- **Status:** Accepted

### D-122 — Turbo Run: car select showroom with easy / normal / hard cars
- **Date:** 2026-11-22
- **Decision (director):** when the game starts, three cars (red, yellow, blue) rotate in a showcase and the player chooses one. Top speed and cornering make them easy, normal and hard, following the director's order. Their stats show under the cars and on the DMD.
- **Cars** (`Sim.CARS`): `top` is the H-gear top speed (L tops out at 62.5 % of it, nitro adds 20 m/s). `grip` multiplies steering authority and divides the bend push.
  - **Red EASY:** 72 m/s (259 km/h), grip 1.25.
  - **Yellow NORMAL:** 80 m/s (288 km/h), grip 1.0. This is the default and keeps the earlier tuning.
  - **Blue HARD:** 88 m/s (317 km/h), grip 0.8.
  - All three are the same model, recoloured with the car shader's hue.
- **Showroom** (`games/racer/showroom.gd`): a new select phase between attract and the race. The cars are stacked down the portrait TABLE on turntables, through an orthographic camera looking down from the front, rendered at the pixel resolution with the palette/dither pass (keep-alpha mode over the sunset sky backdrop). They spin in 32 stepped angles. The chosen car spins faster, bobs, and has a glowing yellow ring; the others are dimmed.
  - **Stats:** under each car on a dark panel: difficulty name in green/yellow/red, TOP SPEED in km/h, and CORNERING as 1–5 pips from grip.
  - **Controls:** flippers move the selection, Launch/Start confirms, and 15 s auto-confirms. A hint with the countdown sits at the bottom.
  - **DMD:** the car in its colour, its name, TOP km/h and GRIP pips, with arrows to the other choices.
- **In the race:** the hero car takes the chosen colour.
- **Dev flag:** `--rc-car=N` picks the car directly (e.g. with `--rc-skip-intro`).
- **Status:** Accepted (tuning pending playtest)

### D-123 — Turbo Run showroom: only the chosen car turns, no bounce
- **Date:** 2026-11-22
- **Decision (director):** the selected car no longer bounces, and only the selected car rotates (1.2 rad/s, stepped through 32 angles). The other two hold their pose. This amends D-122.
- **Status:** Accepted

### D-124 — Turbo Run: no more "sliding on ice": sideways speed eases in, the nose follows travel
- **Date:** 2026-11-22
- **Problem (director):** at lower speeds and on straights the car felt like it was sliding on ice.
- **Cause:** sideways movement had no inertia: full sideways speed the instant a flipper was pressed. Meanwhile the nose only turned a fixed, delayed amount, so the car often crab-walked across the road pointing straight ahead. This was worst at low speed, where the sideways speed is large next to the forward speed.
- **Fix:**
  - **Sideways speed:** the sim keeps `lat_v`, which eases towards the steering/bend target at 30 m/s² (×1.6 while drifting; set directly during crashes).
  - **Nose angle:** the view points the nose along the actual direction of travel, atan(lat_v / v), clamped to ±0.45 rad; drifts keep their own angle. The car always faces where it goes.
  - **Taps:** short taps build so little sideways speed that the nose stays within one sprite step. The steering-delay workaround (D-114, D-117) and `STEER_YAW` are removed.
- **Status:** Accepted

### D-125 — Turbo Run: car crash animation on the DMD; 3 s of immunity after a crash
- **Date:** 2026-11-22
- **Crash animation (director: remove the blond-passenger animation, show the car crashing):** the side-view car races in with speed lines, hits a rock with a burst, cartwheels through the air on a ballistic arc in 4 stepped poses shedding debris, lands on its roof and smokes, while CRASH! shakes and blinks (1.9 s). The portraits from D-119 are removed.
- **Immunity (director):** when the car starts moving again after a crash, it is immune to traffic for 3 s (`CRASH_GRACE`), so an oncoming car can't hit it straight away. Roadside objects still count. The hero car blinks while immune.
- **Status:** Accepted

### D-126 — Turbo Run: 5 s of immunity after a crash
- **Date:** 2026-11-22
- **Decision (director):** the traffic immunity after a crash lasts 5 s (was 3 s, D-125).
- **Status:** Accepted

### D-127 — Turbo Run: tunnels; smaller, higher number plate
- **Date:** 2026-11-22
- **Tunnels (director):** cars turn their lights on inside, even in day stages; car noises get reverb; the walls are on the limits of the road.
  - **Track:** gentle sections (|curvature| < 1/260) after 900 m become tunnels 220–520 m long, with a 35 % chance and at least 1.2 km between them. They stay clear of checkpoint gates (60 m either side), and no roadside objects are placed inside (`Track.tunnels`, `in_tunnel()`).
  - **Walls:** they stand on the road's edges (`TUNNEL_HALF` = 7.8 m). Inside, the car is held between them and scrapes along them (−9 m/s² and a scrape event); driving in off the road hits the portal and rolls the car.
  - **Look** (`games/racer/tunnel.gd`): pre-lit concrete walls and roof with panel seams, a yellow guide stripe and grime, following the road's curve and hills. Sodium ceiling lamps every 12 m cast orange pools of light on the road (flat additive polygons). A concrete face surrounds each portal.
  - **Inside:** the scene's light dims by 85 %. All car lights come on (hero car beam and lamp texels; traffic lamps when that car is inside), via `_lamps` = max(night, tunnel). Lamp-post pools follow the same level.
  - **Reverb:** an `AudioEffectReverb` on the SFX bus fades to 45 % wet inside, so engine, tyres and effects echo off the walls. It is removed from the bus when the game ends.
- **Number plate (director):** 15 % smaller (0.51 × 0.255 m) and raised 6 cm, so it no longer touches the bumper's bottom edge.
- **Status:** Accepted

### D-128 — Turbo Run: easier perfect start; no sideways snap at GO
- **Date:** 2026-11-22
- **Perfect start (director: a bit easier):** the start has its own wider window, rpm 0.58–0.93 (the shift window stays 0.69–0.87), and the grid revs move slower (up 1.5/s, down 1.0/s; was 2.2/1.4), so the needle is easier to hold in the band. During the countdown, the tachometer and the DMD bar show the start window.
- **Snap at GO (director: holding a flipper as the car pulls away shifted its angle harshly):** at standstill the sideways speed was large compared with the forward speed, so the nose jumped to the clamp at once. Now steering authority starts at 0 when stopped (the 0.06 floor is gone), the travel angle fades in with speed up to 15 m/s, and the nose angle eases at 1.8 rad/s.
- **Status:** Accepted

### D-129 — Turbo Run: "Dreamstate" at nightfall; music credits on the attract DMD
- **Date:** 2026-11-22
- **Music (director):** at stage 5, as the lights go down, the music crossfades (6 s) from Maximum Overdrive to "Dreamstate" by Bogart VGM (`bogart_dreamstate.ogg`, converted from the director's MP3, 3:48, looped). Maximum Overdrive now covers stages 1–4, and Dreamstate stages 5–9. The CodeManu action songs start at stage 10 (action_3 first) and change every 4 stages. This amends D-111.
- **License:** the director named the author but not the license. It is assumed CC BY 3.0 like the same author's Maximum Overdrive and flagged in CREDITS.md to confirm.
- **Attribution (director):** the attract DMD cycle now has 6 pages of 3 s: logo, hint, "MUSIC BY / BOGART VGM", high score, "BOGART VGM / FACEBOOK.COM/BOGARTVGM" (marquee), "MUSIC BY / CODEMANU". CREDITS.md links Bogart VGM to https://www.facebook.com/BogartVGM/.
- **Status:** Accepted (license to confirm)

### D-130 — Bogart VGM music is CC BY 3.0
- **Date:** 2026-11-22
- **Decision (director):** all Bogart VGM songs are CC BY 3.0. Dreamstate's license is confirmed, which resolves D-129's open item. Future Bogart VGM tracks the director supplies are cleared as CC BY 3.0 and need attribution, linked to https://www.facebook.com/BogartVGM/.
- **Status:** Accepted

### D-131 — Turbo Run: a flipper held to rev doesn't steer at GO
- **Date:** 2026-11-22
- **Problem (director):** the car still turned hard when the flippers were pressed to hit the perfect rev start.
- **Cause:** the flipper held for revving was still down at GO, so it became a full steering input just as the perfect launch put the car at speed.
- **Fix:** any flipper held at the moment of GO is ignored for steering (and shifting) until it is released. Pressing it again steers normally. A test holds a flipper straight through GO and checks the car stays in its lane.
- **Status:** Accepted

### D-132 — Turbo Run: a tunnel always comes before stage 3
- **Date:** 2026-11-22
- **Decision (director):** add a tunnel before stage 3.
- **Implementation:** if no tunnel has been generated by the middle of stage 2 (1.25 × the checkpoint spacing), the track lays a gentle straight section with a tunnel there. It ends well before the stage-3 checkpoint and respects the usual 60 m clearance from gates. Random tunnels continue after that (D-127). Tests check four seeds, including the game's seed 7.
- **Status:** Accepted

### D-133 — Turbo Run: half as many tunnel lights
- **Date:** 2026-11-22
- **Decision (director):** 50 % fewer tunnel lights. The ceiling lamps and their pools on the road are now every 24 m (was 12 m, D-127).
- **Status:** Accepted

### D-134 — Turbo Run: Doppler engine noise from passing traffic
- **Date:** 2026-11-22
- **Decision (director):** add Doppler-effect engine noises when passing nearby cars.
- **Implementation:** two looping "buzz" engine voices (a saw at 110 Hz plus harmonics and a sub, with a little noise) follow the two nearest vehicles within 45 m.
  - **Pitch:** classic Doppler on the closing speed, f × c / (c − v_closing), with an exaggerated c = 110 m/s so the drop is obvious. It rises as a car approaches, drops as you pass it, and drops hard for oncoming traffic.
  - **Base pitch:** trucks sit lower (0.55 against 0.85 for cars).
  - **Volume:** −6 dB close, falling to −36 dB at 45 m.
  - Both are on the SFX bus, so they echo in tunnels (D-127).
- **Not done:** left/right panning, which would need a 3D or per-voice bus setup.
- **Status:** Accepted

### D-135 — Turbo Run: speed cameras, radar detector, police chases and fines
- **Date:** 2026-11-22
- **Decision (director):** speed traps beside the road (after stage 3), a radar detector, and a police car with sirens and flashers that tries to T-bone the hero car when it is caught speeding. A bust (slowing down or crashing) stops the police beside the player, plays a FINE animation on the DMD and deducts points, on top of the time lost.
- **Speed cameras:** a Qwen-Image pixel sprite on a 4.2 m pole on the right verge, on straights and never in tunnels. They start after stage 3 (`TRAPS_FROM_STAGE`) and come every 1.2–2 km. They are solid (r 0.4).
- **Radar detector:** `sim.radar` (0–1) rises over the last 450 m to the next camera. The view beeps (a short double chirp) with gaps shrinking from 1.1 s to 0.09 s, and a red LED lights with each beep. The LED is in a little RADAR box above the gear lever and as a dot on the DMD dashboard.
- **Caught:** passing a camera faster than 1.5 × the car's L-gear limit (270 km/h on the normal car) spawns a police car 140 m behind, if none is active.
- **Chase:** the police car closes at up to +14 m/s (capped near your nitro speed), lines up 2.6 m beside you, then swerves in. Contact is a crash (the T-bone), respecting the post-crash immunity.
- **Bust:** crashing, or dropping below 22 m/s (79 km/h), with the police within 40 m. The player is held for 3.5 s (plus any crash time) and the police pulls up beside you (backing up if it overshot). The fine is 25,000, capped at the score. Then it drives off.
- **Escape:** after 22 s of chase, or 260 m behind, it gives up. ESCAPED! and +10,000 (a small bonus I added).
- **View:** the director's police car with a light bar of alternating red and blue additive glows. A looping two-tone siren with Doppler pitch and distance volume. The nose turns towards the player when swerving in. POLICE!, BUSTED! and ESCAPED! messages.
- **DMD FINE animation:** the police car rolls up behind ours with its bar flashing, BUSTED! appears, then a ticket slides up showing FINE −amount.
- **Note:** the police model has a crest badge and "911" lettering that echo a real car brand. It is used as supplied; the director may want those details changed.
- **Status:** Accepted (tuning pending playtest)

### D-136 — Turbo Run: hatchback in the traffic mix
- **Date:** 2026-11-22
- **Decision (director):** the director's `hatchback.glb` joins the car traffic. It is processed like the other models: full 56.5k-tri mesh, 4.0 m long, 256 px texture. Two in five traffic cars use it, fixed per vehicle, recoloured with the same per-car hue and lit at night and in tunnels. The pool is 8.
- **Status:** Accepted

### D-137 — Turbo Run: police stays with the player; launch lock; radar light bar; police screen wash; bigger speed cameras
- **Date:** 2026-11-22
- **Bug (director): sharp turn after a perfect rev.** Holding a flipper through GO was already ignored (D-131), but re-pressing one right after GO, while chasing the revs, still threw the car sideways at launch speed. Now no flipper steers for the first 1.0 s after GO (`LAUNCH_LOCK`).
- **Bug (director): the police drove past the player.** It chased a target speed and carried its momentum past. It now keeps position relative to the player (`_police_follow`: the player's speed plus a capped correction towards a target gap).
  - **Chasing:** it runs down the player's line, then holds alongside about 1 m behind and 2.8 m to one side.
  - **Ram:** after 1.2 s it swerves in to slam the player. If it misses, it lines up again, switching sides if the player is near that edge.
  - **Bust:** it brakes hard (90 m/s²), backs up if it overshot, and parks right beside the stopped player.
  - Tests check that it never gets more than 4 m ahead, and that it parks within 3 m after ramming at full speed.
- **Radar detector (director):** moved to the top of the screen under the clock, styled as a police light bar (`radar_bar.gd`): 5 blue balls, a black centre block, 5 red balls. They light from the centre outwards as the camera gets closer, and flash brighter with each beep. The RADAR box by the gear lever is gone.
- **Police lights on screen (director):** while the police is within about 125 m, red and blue glows wash in from the left and right screen edges in time with its light bar, up to 45 % within 25 m (additive, under the HUD).
- **Speed cameras visible (director):** they were drawn, but at 4.2 m by 1 m they vanished next to the 11 m palms. They are now 8 m tall, oversized like the other sprites, and 1.6 m from the kerb.
- **Status:** Accepted

### D-138 — Debug O: spawn a police car
- **Date:** 2026-11-22
- **Decision (director):** a debug cheat to spawn the police. The director first asked for P, which is already the global pause key (D-057), then chose another letter. DebugTools' O ("officer") emits `spawn_police` (debug builds only). Turbo Run starts a chase straight away, with the police 140 m behind and POLICE! shown, if a race is running and no police car is active.
- **Status:** Accepted

### D-139 — Turbo Run: police arrives, swings across and parks on a bust; full-width radar bar
- **Date:** 2026-11-22
- **Bug (director):** on a bust the police only appeared at the very end and vanished as soon as it stopped.
  - **Arriving late:** while busted it approached at the player's speed plus at most 12 m/s, so with the player stopped it took most of the 3.5 s hold to arrive.
  - **Vanishing:** the "leave" step stopped a police car that was even slightly behind the player and deleted it immediately.
- **Fix:**
  - **Arrival:** the bust approach closes at up to 30 m/s.
  - **Park:** the player is held until the police has stood parked beside them for `PARK_HOLD` (1.5 s), on top of the 3.5 s bust time.
  - **Swing:** as it stops, the view swings it 90° across in 4 stepped frames, and it straightens again as it leaves.
  - **Leave:** it drives off forwards, overtaking up the road, and is only removed beyond 350 m.
  - **Test:** it stays parked for at least 1.5 s, then drives off ahead.
- **Radar bar (director):** no background housing. It spans the full width at the very top of the TABLE: the black block in the middle, 5 balls spread evenly out to each screen edge, radius 24. The score/time/stage row moves down to y = 62 to sit below it.
- **Status:** Accepted

### D-140 — Turbo Run: new police car model (not based on a real car)
- **Date:** 2026-11-22
- **Decision (director):** `police2.glb` replaces the first police model. It mixes several cars, so it doesn't resemble any specific real car (resolving the D-135 note).
- **Processing:** full 32.9k-tri mesh, 4.7 m long, the same orientation and light-bar position. It uses a 512 px texture, because at 256 px the POLICE lettering broke up.
- **Removed:** the old model, its texture and its source are removed from the repo, so they don't ship.
- **Note:** the new texture still carries "911" door lettering. It is used as supplied.
- **Status:** Accepted

### D-141 — "911" on the police car is the emergency number
- **Date:** 2026-11-22
- **Clarification (director):** the "911" lettering on the police car is the US emergency phone number, a normal police livery detail, not a car model badge. It stays. This closes the notes in D-135 and D-140.
- **Status:** Accepted

### D-142 — Turbo Run: police aims at you, gets hit in three goes, can be outrun with nitro; no CHECKPOINT notice; showroom start angle
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Aim:** while chasing, the police car's nose points at the hero car (atan of the sideways gap over the distance ahead, clamped to ±0.9 rad, still snapped to the sprite angles).
  - **Speed:** its top speed is 1.06 × the player car's own top. Normal driving can't shake it, but nitro (+20 m/s) outruns it.
  - **Hits:** a police hit no longer stops the player at once. Each hit keeps 78 % of the speed and shoves the player 9 m/s sideways, away from the police car. The police bounces the other way and drops below the player's speed, and there's a 0.8 s cooldown between hits. The third hit spins the player out, which leads to a bust. Each hit shakes the camera and flickers the backglass.
  - **Police collisions:** traffic slows the police to 55 % and shoves it aside; tunnel walls hold it in and slow it.
  - **Checkpoints:** CHECKPOINT no longer shows mid-TABLE; the gate, DMD animation and sound remain. JUST MADE IT! still shows when a checkpoint saves the race.
  - **Showroom:** all three cars start at the same rotation angle.
- **Status:** Accepted

### D-143 — Turbo Run: turning wheels, dawn at stage 10, pixel radar balls, steep hills
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Wheels:** the car's wheels are part of its single mesh and can't rotate, so `car.gdshader` fakes it on the hero car (`spin` instance uniform). Around each axle (model z = ±1.2 m, 0.33 m up, radius 0.32 m, outer faces only, non-red texels), the rims get 5 spoke streaks driven by `wheel_phase` (road speed ÷ wheel radius, stepped). They blend into a smooth grey disc as speed rises (`wheel_blur`, from 6 to 26 m/s). From the chase camera this shows mostly in turns and drifts.
  - **Dawn:** night covers stages 5–9; from stage 10 the scene fades back to the dawn/sunset look (`Night.DAWN_STAGE`). The CodeManu songs also start at stage 10 (D-129).
  - **Radar balls:** a 16-bit look. They are drawn in chunky 4 px pixels with a dark outline, three shade bands and a highlight; lit balls brighten on each beep.
  - **Steep hills:** 17 % of sections (after the start) are short steep climbs or drops, at a 14–22 % average grade (about 30 % at the steepest point). Normal hills stay at ±10 %. Tunnels aren't laid on sections steeper than 6 % (tested).
- **Status:** Accepted

### D-144 — Turbo Run: hatchbacks light their own lamps
- **Date:** 2026-11-22
- **Bug (director):** hatchbacks didn't light up in the dark. The car shader's lamp boxes were measured on the red car, and the hatchback's lamps sit elsewhere.
- **Fix:** lamp boxes are now per model (`LAMP_BOXES`, applied to each model's shared material). The hatchback uses a tail box with `tail_red_only`: its body is blue, so only the red lens texels glow. Its headlight box is set from its own lights. The red car keeps the shader defaults.
- **Status:** Accepted

### D-145 — Turbo Run: an escaped police car gives up, lights off
- **Date:** 2026-11-22
- **Bug (director):** after ESCAPED! the police car passed the player with its lights still on.
- **Cause:** escaping reused the post-bust "leave" step, which speeds up and overtakes, and the view always flashed the light bar.
- **Fix:** escaping now puts the police in a new "giveup" state: it eases to half the player's speed and drops behind, and is removed 300 m back. `sim.police_lights()` is true only while chasing or busting, and it drives the light bar, the siren and the screen wash. After a bust it still drives off ahead, but dark. A test checks that it never gets ahead of the player after giving up.
- **Status:** Accepted

### D-146 — Turbo Run: drift points under the score
- **Date:** 2026-11-22
- **Decision (director):** the drift points readout moves from mid-TABLE to under the score, top left, centred in the score column at 36 px. It still fades by alpha, so its slot is fixed and nothing moves (D-096).
- **Status:** Accepted

### D-147 — Turbo Run: mph on screen with realistic numbers; light-bar sides; police lights off once fined; bust swing towards you
- **Date:** 2026-11-22
- **Speeds shown (director):** the numbers were unrealistic, and with California plates they should be mph. Only the displayed numbers change; the game's real speeds stay as they were (the director confirmed this).
  - **Scale:** `Sim.MPH` = 2.237 × (270 / 3.6) / 88 converts game m/s to displayed mph, so the fastest car's flat-out top (88 m/s) reads 168 mph / 270 km/h. The three cars read 137 / 152 / 168 mph; nitro on the fastest car reads about 206.
  - **Where:** the speedometer (0–220 mph, labels every 40), its digital readout, the DMD dashboard, the car-select stats and the finale distance (miles). The strings say MPH and MI.
- **Light bar (director: screen colours were on the opposite sides from the car's):** a render from behind shows the model's painted bar is blue on the left and red on the right. The flashing glows were the wrong way round. They now sit over the paint, and the screen wash is blue on the left and red on the right to match.
- **Police lights after a fine (director):** `police_lights()` is true only while chasing. Once you're fined, the light bar, the siren and the screen wash go off.
- **Bust swing (director: the police still turned away):** the 90° swing on a bust used the wrong side. It now turns towards the hero car, with the same sign as the chase aim.
- **Status:** Accepted

### D-148 — Windowed layout: TABLE centred, backglass and DMD on the left
- **Date:** 2026-11-22
- **Decision (director):** when the game opens in the windowed (dev) layout, the TABLE window sits centred on the monitor, and the BACKGLASS (with the DMD below it, or inside it on 2-screen settings) stacks to its left, sized to fit the space there. Cabinet layouts are unchanged.
- **Status:** Accepted

### D-149 — Turbo Run dashboard: plain gear lever, equal dials
- **Date:** 2026-11-22
- **Decision (director):** the gear lever loses its background plate and the GEAR label. Only the outlined slot, the H/L marks and the knob remain. The tachometer and speedometer are now the same size (radius 150, `DIAL_R`).
- **Status:** Accepted

### D-150 — Turbo Run: "THE COPS!"; radar balls glow like lamps
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Message:** the police chase message reads THE COPS! instead of POLICE!.
  - **Radar lamps:** lit radar balls look like real lights. A dithered pixel glow halo spills around each lit ball (wider and stronger on each beep), and the ball burns from a white core through a light tint to the full colour, with a hot rim instead of the dark outline. Unlit balls stay dark glass. Still chunky 4 px pixels.
- **Status:** Accepted

### D-151 — Turbo Run: animated shifter beside the SHIFT warning
- **Date:** 2026-11-22
- **Decision (director):** the big SHIFT warning (D-116) shows an animation of the shifter next to it. A second gear-lever widget sits to the right of the word, in the same centred row, which is a fixed layout (the word blinks by alpha, D-096). While the warning is up, the lever loops: in L for 0.5 s, the knob steps up to H, holds, then snaps back.
- **Status:** Accepted

### D-152 — Turbo Run: side-swipes bump instead of crashing
- **Date:** 2026-11-22
- **Decision (director):** hitting other cars from the side shouldn't crash. Both cars slow a little and bump apart.
- **Side contact:** the cars already overlapped along the road on the previous frame, so the contact came from moving sideways. Approaching nose-to-tail or head-on is still judged as before: a crash for head-ons, rear-ending at speed or a truck rolling you; otherwise a bump.
- **Side-swipe:** the player keeps 93 % of their speed and is shoved 7 m/s away. The traffic vehicle gets a sideways `shove` offset (1.6 m for a car, 0.8 m for a truck) that eases back into its lane at 2 m/s. There's a 0.4 s cooldown per vehicle. It counts as a bump (sound), not a crash.
- **Tests:** the crash tests now approach from outside contact, as in play.
- **Status:** Accepted

### D-153 — Turbo Run: tunnel lamps light the cars passing under them
- **Date:** 2026-11-22
- **Problem (director):** the tunnel lights didn't seem to affect the car going under them. The lamps and their pools are flat painted polygons and light nothing.
- **Fix:** `car.gdshader` gets an `overhead` instance uniform that adds sodium-orange emission over the car's own colours, strongest on the roof and upper body. The view sets it per car (hero, traffic) from its distance to the nearest ceiling lamp (`Tunnel.LIGHT_EVERY` grid): 1 directly underneath, fading over 6 m, 0 outside tunnels. Cars visibly brighten as they pass under each lamp.
- **Status:** Accepted

### D-154 — Turbo Run: REV UP! with a live tacho on the DMD during the countdown
- **Date:** 2026-11-22
- **Decision (director):** the countdown's GET READY DMD message becomes REV UP! with a tacho animation. The custom frame shows REV UP! blinking and the count on the left. On the right is a pixel half-dial whose arc marks the perfect-start window in green and the over-rev zone in red. Its needle follows the player's live revs (green while in the window) and wobbles at idle. The `RC_GET_READY` string is removed.
- **Status:** Accepted

### D-155 — Turbo Run: LOST THEM!; SHIFT hint only shows the upshift
- **Date:** 2026-11-22
- **Decisions (director):**
  - **Message:** the police escape message reads LOST THEM! instead of ESCAPED!.
  - **SHIFT hint:** the shifter next to SHIFT (D-151) looked like it was asking for a downshift when the knob slid back. It now only shows L → H: at the end of each loop the knob jumps straight back to L with no travel (`GearLever.snap_low`).
- **Status:** Accepted

### D-156 — Turbo Run: speed cameras trigger over 100 mph
- **Date:** 2026-11-22
- **Decision (director):** any speed over 100 mph (as shown, D-147) at a speed camera calls the police, for every car. This replaces the "1.5 × the L-gear limit" rule from D-135. In game terms it is 52.5 m/s: just above the normal car's L-gear limit, so in H you need to slow down for cameras. Tests check 99 mph passes and 101 mph is caught.
- **Status:** Accepted

### D-157 — Turbo Run: bust only when the police is right on you
- **Date:** 2026-11-22
- **Decision (director):** BUSTED shouldn't happen until the police car is closer. The bust range (`BUST_NEAR`) is now 12 m, down from 40 m. Crashing or dropping below 22 m/s only busts you with the police on your bumper or alongside. Tests: 20 m back is no bust, 8 m is.
- **Status:** Accepted

### D-158 — Turbo Run: rising SHIFT warning; THE COPS! flashes red and blue
- **Date:** 2026-11-22
- **Decisions (director):**
  - **SHIFT:** the word rises 36 px in 4 stepped frames and loops twice a second. It moves inside its own fixed slot, sized from the label once laid out, so the shifter beside it stays put (D-096).
  - **THE COPS!:** the centre message flashes alternately red and blue, about 4 times a second, like the light bar. It is a tint over the styled title font.
- **Status:** Accepted

### D-159 — Turbo Run: NITRO notice above the speedometer
- **Date:** 2026-11-22
- **Decision (director):** the nitro pick-up notice moves from mid-TABLE to just above the speedometer and gets smaller: the styled title font at scale 1 (the centre message used scale 4). It flickers for 0.8 s on each pick-up, by alpha in a fixed spot (D-096).
- **Status:** Accepted

### D-160 — Turbo Run: SHIFT warning only the first time after the start or a crash
- **Date:** 2026-11-22
- **Decision (director):** the big SHIFT warning (with its shifter animation) shows only the first time the player sits at the redline in L after the race starts or after a crash. Once it has shown and the player shifts or the revs drop, it stays off until the next crash re-arms it.
- **Status:** Accepted

### D-161 — Turbo Run: on a bust the police blocks the road in front
- **Date:** 2026-11-22
- **Decision (director):** after a bust the police car drives round the player and stops in front, blocking the way, instead of parking alongside. It passes on one side (3.4 m out), cuts in to the player's line `BLOCK_AHEAD` (6.5 m) ahead, stops, and swings 90° across the lane in stepped frames. The swing direction is fixed at the moment of the bust (`police.swing`), so it can't flicker. The 1.5 s parked hold (D-139) now counts at that blocking spot. A test checks it ends up 6.5 m ahead in the player's lane.
- **Status:** Accepted

### D-162 — Turbo Run: the cops' distance on the DMD during a chase
- **Date:** 2026-11-22
- **Decision (director):** while the police chase (lights on), the DMD dashboard gives way to a side-view chase animation.
  - **Scene:** our car (in the chosen colour) at the right; the police car behind it at a gap that maps the real distance (0–150 m) across the DMD, with its light bar flashing red/blue and speed lines; road dashes scroll with our speed.
  - **Readouts:** the distance in feet top left, blinking red under 30 m (98 ft), and our speed in mph top right. The radar LED still shows.
- **Status:** Accepted

### D-163 — Turbo Run: traffic pulls over for the police, indicating
- **Date:** 2026-11-22
- **Decision (director):** when the police is coming, other traffic moves to the sides with its blinkers on.
- **Who:** while the police chases with its lights on, any vehicle from 40 m behind it to 350 m ahead of it yields. That covers both directions.
- **How:** each vehicle eases to its own right-hand edge, so our-way traffic goes to the right kerb and oncoming traffic to theirs (the left side as we see it). It stops weaving and slows to 60 % of its cruise speed. When the police has passed or the chase ends, it pulls back into its lane and speeds up again.
- **Blinkers:** amber pixel glows at the vehicle's own right front and rear corners, set per model (`BLINKERS`), flash at about 1.4 Hz while yielding.
- **Test:** a car and an oncoming car both reach their edges, slow down and indicate.
- **Status:** Accepted

### D-164 — VR cabinet layout (prototype, branch `vr-cabinet`)
- **Date:** 2026-11-22
- **Decision (director):** port the games to VR as a 3D pinball machine with the screens in the right places, built in Godot. PC VR first, with a placeholder cabinet; standalone Quest can follow.
- **Design:** a new screen layout, `--layout=vr` (`core/vr_cabinet.gd`). The games are untouched and keep drawing into the Screens viewports.
  - **Screens:** the cabinet shows the TABLE on a 43" playfield screen (0.95 × 0.535 m) under the glass, tilted 6.5°. The head carries the BACKGLASS on a 32" screen and the DMD as a 3D dot-matrix panel below it (`dmd_dots_3d.gdshader`).
  - **Placeholder cabinet:** built from boxes in real-world metres: body, legs, chrome lockdown bar and rails, head, flipper and magna buttons on the sides, and a launch button on the front. It can be replaced by a director-made model.
  - **TABLE resolution:** full 1080 × 1920, since it is read up close.
- **OpenXR:** Godot's built-in OpenXR. `xr/openxr/enabled` stays false so normal runs never start a VR runtime. `scripts/run_vr.ps1` passes `--xr-mode on`. `xr/shaders/enabled` is true for stereo rendering.
  - **With a runtime:** an XROrigin3D puts the player 0.42 m in front of the cabinet, centred on the headset.
  - **Controllers** (default OpenXR action map) are fed in as InputEventActions, so the games see normal cabinet actions: triggers = flippers (with a haptic tick), grips = magna saves, right A = launch, left X = start, left Y = coin, right B = exit.
  - **Without a runtime:** the layout falls back to a fixed player's-eye desktop camera, used for previews and screenshots.
- **Not yet:** headset testing (none here), a real cabinet model, the operator-menu entry for the layout, nudging, standalone Quest export, and checking text legibility at arm's length.
- **Status:** Prototype

### D-165 — VR cabinet can be moved
- **Date:** 2026-11-22
- **Decision (director):** the VR prototype works; the cabinet position needs to be adjustable.
- **Controls (in VR):** the left stick slides the cabinet across the floor relative to where the player looks (0.6 m/s). On the right stick, up/down changes the height (±0.5 m) and left/right turns it (45°/s). Clicking the left stick puts it straight in front of the player, facing them.
- **Implementation:** the cabinet meshes live under their own node; the XR origin, floor and lights stay put.
- **Saving:** the placement is saved to the config (`display.vr_cabinet` = x, height, z, yaw) 0.6 s after it stops moving and restored next time. The desktop preview ignores it.
- **Status:** Accepted (prototype)

### D-166 — VR: the director's cabinet model with the screens on its pink areas; an arcade room
- **Date:** 2026-11-22
- **Decision (director):** use the director's `pinball_cabinet.glb`, whose three screen areas are painted pink, and add a basic room.
- **Pipeline (no hand placement):**
  1. `scripts/tools/prepare_vr_cabinet.py` (headless Blender) bakes the transforms, puts the feet on the floor and the front edge at z = 0, scales the texture to 2048 and writes it as a PNG. The glb's embedded JPEG doesn't import, as with the car.
  2. `scripts/tools/measure_vr_cabinet.gd` (headless Godot) measures the screens in Godot's own space. It finds the pink triangles in the imported mesh and splits them: the playfield is tilted upward-facing pink in the lower part; the backglass and DMD are front-facing pink in the head, split into height bands, with the biggest band as the backglass and the second as the DMD. For each it takes the area-weighted plane, and then the tightest-fitting rectangle at the screen's own rotation within that plane. It writes `pinball_cabinet_screens.json` and a clean texture with the pink turned to black glass.
- **In game** (`core/vr_cabinet.gd`): the model and screens sit in a holder turned so the playfield points straight at the player and is centred. The live TABLE, BACKGLASS and DMD (dot-matrix shader) are laid on the measured rectangles. The box cabinet stays as a fallback when the model is missing.
- **Why it took several tries:** the first passes assumed each screen rectangle was square to the world axes. The model sits about 6° turned, so the boxes never fitted. Also, Blender's cached face normals were stale after transforming, and Godot winds triangles the other way. Measuring each rectangle's own rotation in Godot space settled it. The playfield came out at 0.578 × 0.997 m, exactly the TABLE's 9:16.
- **Room:** 5 × 5 × 2.9 m. Arcade carpet (generated pixel pattern), dark walls, pink and cyan neon strips near the ceiling with coloured fill lights, two ceiling light panels, and the two games' backglass art as wall posters. Glow is on. The cabinet stands in front of the back wall.
- **Future models:** a separate flat mesh per screen named `playfield`, `backglass` and `dmd`, with 0–1 UVs, and the cabinet square to the axes, would make placement exact with no measuring. Pink areas keep working.
- **Status:** Accepted (prototype)

### D-167 — VR: screens fitted to the visible openings, not cut
- **Date:** 2026-11-22
- **Problem (director):** the playfield and DMD rendered too big, and the UI was cut at the edges.
- **Cause:** the screens were laid on the pink area's average plane, but the pink surface rises about 1–2 cm at its edges. Those raised edges, now black glass, poked through the screen and hid the picture's border.
- **Fix** (`measure_vr_cabinet.gd`):
  - **Lift:** each screen is lifted just above the highest point of its pink area, capped at 25 mm, because the backglass band also contains some deeper faces.
  - **Opening:** the visible opening is measured from non-pink geometry standing up to 5 cm above the screen near each edge. Corners are ignored, so a rail along one side can't cut the ends.
  - **Aspect:** the game fits each picture into its opening at its own aspect ratio (TABLE 9:16, backglass 16:9, DMD 4:1), so nothing is cut and any difference shows as black.
- **Status:** Accepted

### D-168 — VR: the cabinet stays put, the player moves (supersedes D-165)
- **Date:** 2026-11-22
- **Decision (director):** the sticks move the player around the room, not the cabinet, which stands fixed in the middle of the room.
- **Room:** `ROOM_BACK` moves to −3.2, so the 5 × 5 m room is centred on the cabinet.
- **Controls:** the left stick walks relative to where the player looks (1.4 m/s, kept 0.3 m inside the walls). The right stick snap-turns 45° per push, about the player's head. Clicking the left stick returns the player to the front of the cabinet, facing it.
- **Config:** the saved cabinet placement (`display.vr_cabinet`) is removed.
- **Status:** Accepted (prototype)

### D-169 — VR: right stick sets the player's height
- **Date:** 2026-11-22
- **Decision (director):** the right stick changes the player's height, not their rotation. Up/down raises or lowers the play space at 0.4 m/s, from −0.8 to +0.6 m, for example to play seated. Snap turning is removed; players turn physically. Recentring (left stick click) keeps the chosen height. This amends D-168.
- **Status:** Accepted

### D-170 — Quest build (sideload APK)
- **Date:** 2026-11-22
- **Decision (director):** make a Quest APK to sideload.
- **Toolchain** (no editor; script `scripts/build_quest.ps1`):
  - **Export templates:** Godot 4.7.2 Android export templates, extracted from the official release package (only the Android files) into `%APPDATA%\Godot\export_templates\4.7.2.stable`.
  - **Android tools:** the existing Android SDK and JDK 17, already set in Godot's editor settings, and Godot's debug keystore.
  - **OpenXR plugin:** the official Godot OpenXR Vendors plugin 5.2.0 (GodotVR, MIT; needs Godot ≥ 4.6) in `addons/godotopenxrvendors`, Android and Windows binaries only, in Git LFS. Its Khronos and Meta OpenXR loaders are Apache-2.0. The Meta SDK parts are under Meta's SDK licence, which is fine for sideloading but needs a check before any store release.
  - **Build:** the plugin ships AARs, so the export uses the Gradle build. The `android/` build template is installed by the script and git-ignored.
- **Project:**
  - **OpenXR:** `xr/openxr/enabled.android=true`, so desktop runs never start OpenXR.
  - **Layout:** `Config.layout()` returns `vr` on Android, and the VR layout skips desktop window setup there.
  - **Textures:** ETC2/ASTC compression is enabled, which Android requires.
- **Export preset "Quest"** (`export_presets.cfg`): arm64 only, XR mode OpenXR, Meta plugin enabled, package `org.pingames.vr`, debug-signed, output `exports/PinGames-quest.apk`. Source assets, tests, scripts, docs and the Windows plugin binaries are excluded from the APK.
- **Install:** `adb install -r exports\PinGames-quest.apk` (developer mode on), or SideQuest.
- **Status:** Prototype

### D-171 — Exported builds load the imported translation
- **Date:** 2026-11-22
- **Bug (director):** on the Quest, texts showed as keys (RC_…), because no translations were loaded.
- **Cause:** `core/i18n.gd` parses the raw `strings.csv` at runtime, but an export only packs the imported version (`strings.en.translation`). Godot replaces imported sources with their imports even when an include filter names them.
- **Fix:** when no CSV is found, I18n loads the `.translation` files from `res://core/locale`. Desktop runs still read the CSV, including `user://locale` overrides. A test checks that the imported translation loads with the game texts.
- **Status:** Accepted

### D-172 — Quest: level files in the export; anti-aliased VR DMD; export audit
- **Date:** 2026-11-22
- **Bugs (director):**
  - **No bricks or side walls in Tilt Breaker:** its levels are plain `.txt` files read with FileAccess, and the "all resources" export skips non-resource files. The Quest preset now has `include_filter="*.txt"`. The side walls only flash as an energy shield on rebounds, so they came back with the levels.
  - **DMD grid flicker:** the VR DMD's dots are smaller than a headset pixel at that distance and aliased into a shimmering grid. `dmd_dots_3d.gdshader` now softens each dot's edge by its on-screen size (fwidth) and fades the dot pattern into its average brightness when dots get too small to resolve.
- **Audit:** every runtime file read was checked. Only the levels (`.txt`), the translations (D-171) and JSON (title fonts, cabinet screens; JSON is a resource and ships) read raw files.
- **Export test:** the exported Quest package (`--export-pack`) was run on the desktop with `--main-pack`, outside the project folder. Both games run with all content, texts and levels. Only the deliberately excluded Windows XR library is missing there.
- **Test:** the Quest preset must include `*.txt`.
- **Status:** Accepted

### D-173 — Browser version, served at web.phoenixfox.net/pingames/
- **Date:** 2026-11-22
- **Decision (director):** a web browser version of the flat-screen prototype, served under a subpath of the existing NAS web server.
- **Layout `web`** (`Screens._setup_web`): a browser has one canvas, so the TABLE fills the left at full height, the BACKGLASS and the dot-matrix DMD stack on the right (the DMD sits in an AspectRatioContainer so the dot shader stays on the panel), and the keyboard controls are listed under them (`WEB_CONTROLS`). `Config.layout()` picks it on the web feature. On the desktop, `--web-preview` shows it in a browser-sized window.
- **Renderer:** browsers use Godot's Compatibility (WebGL 2) renderer. Both games were checked on the desktop under `--rendering-method gl_compatibility` and render correctly.
- **Export preset "Web":** the non-threaded template, so no COOP/COEP headers are needed and any static server works. It includes `*.txt` (levels, D-172) and excludes sources, tests, scripts, docs, the XR addon and the VR cabinet model. Output is about 104 MB of game data plus a 40 MB engine file.
- **Hosting:** the HeroAR stack's NGINX (Portainer stack `heroar`, see that repo's docs/DEPLOYMENT.md) serves `K:\heroar\www` statically, with `.wasm` as application/wasm. The build goes in `K:\heroar\www\pingames\`, so it's at https://web.phoenixfox.net/pingames/ (LAN: http://192.168.1.150:8086/pingames/). The HeroAR client deploy copies with `robocopy /E` and never deletes, so the folder survives it. No HeroAR config change and no restart were needed. `scripts/deploy_web.ps1` builds and mirrors it.
- **Possible improvement:** NGINX doesn't gzip `.wasm` or `.pck` (its `gzip_types` leaves them out), so the first load is about 145 MB. That's fine on the LAN, but adding them to HeroAR's nginx.conf would cut it a lot. It's left untouched for now.
- **Status:** Accepted

### D-174 — Web build served pre-compressed
- **Date:** 2026-11-22
- **Decision (director):** add NGINX compression for the web build and restart the container, making whatever HeroAR changes are needed.
- **NGINX:** `location ^~ /pingames/` with `gzip_static on`, MIME types and `no-cache`, plus `application/wasm` in `gzip_types` (HeroAR DEC-0275, committed there).
- **Deploy:** `scripts/deploy_web.ps1` writes `.gz` copies of `index.wasm`, `index.pck` and `index.js` before mirroring.
- **Rollout:** the config was validated with `nginx -t` inside the running container through Portainer's API before `heroar-web` was restarted. The HeroHold site and `/healthz` were fine afterwards.
- **Result:** the engine downloads as 10 MB instead of 40 MB. The 104 MB game data hardly compresses, because its textures and music are already compressed formats.
- **Status:** Accepted

### D-175 — Browser build fixes: loading screen, sound, per-object shader values, web debug keys, URL options
- **Date:** 2026-11-22
- **Context:** the director tested the browser build (D-173) and reported four problems: it stuttered while assets loaded, the car textures were black, there was no sound, and every hero car was red while every hatchback was blue. They also asked for the debug keys in the browser.
- **Loading screen** (`shell/modes/game_mode.gd`): before a game's first start, everything in its folders (`games/<id>`, `assets/{models,sprites,textures,audio/music,audio/sfx}/<id>`) is loaded behind a progress bar on the TABLE, with LOADING on the DMD. The results stay cached for the session. The game then renders about 20 frames behind the bar, which compiles most of its shaders out of sight. Loading yields to draw only about every 100 ms, because a slow browser gets few frames. This applies to every layout, so cabinets get a short bar on the first start of each game too.
- **Per-object shader values:** in WebGL, Godot's Compatibility renderer didn't deliver `instance uniform` values; they read as their defaults. Every car got hue 0, and `bright` 0 made the cars black. Lamps, brake lights, wheel spin and the breakout bricks, explosions, ion beam and wormhole were affected too. The shaders now declare these through an `INST` macro, which is `instance` normally and empty when `CURRENT_RENDERER == RENDERER_COMPATIBILITY`. Scripts set them only through `core/util/inst_param.gd` `set_param()`: desktop and Quest keep instance parameters on one shared material, and under Compatibility each object gets its own copy of the material. Never call `set_instance_shader_parameter` directly.
- **Sound:** single-threaded web builds default to "Sample" playback, which can't play the racer's live engine sound or apply bus effects such as the tunnel reverb. Now `audio/general/default_playback_type.web = Stream` uses the normal mixer. This was checked in Chrome by measuring the page's audio output, which went from silent to music peaks of about 0.14–0.34.
- **Debug keys:** enabled on the `web` feature as well as in debug builds.
- **URL options:** on the web, the page's query string is added to the command-line options (`?game=racer&rc-skip-intro` gives `--game=racer --rc-skip-intro`), for direct links and test runs.
- **Deploy script:** it waits for the export files to stop growing and then stops Godot, which sometimes doesn't exit after a headless export.
- **Status:** Accepted

### D-176 — Touch controls in the browser build
- **Date:** 2026-11-22
- **Decision (director):** touch controls for the web version, with a button to hide and show them.
- **Buttons** (`core/touch_controls.gd`): on touch screens (or with `?touch` / `--touch`), a strip at the bottom has big LEFT and RIGHT flipper buttons at the outer edges, with EXIT, START and LAUNCH between them. They press the same CabinetInput actions as the keys, so every game works unchanged (D-007). The TABLE's left and right halves are flipper pads too. Each finger is tracked separately, so both flippers can be held at once (gear shift), and a finger sliding off a button releases it. Mouse clicks drive the strip too, but emulated mouse events from touch are ignored, so a tap never counts twice.
- **Taps:** CabinetInput polls actions once per frame, and the picker acts on release, so a quick tap could press and release unseen. A touch press now lasts at least two frames, and the strip processes before CabinetInput (`process_priority = -100`), so CabinetInput sees the delayed release in the frame it happens.
- **Hide/show:** a small HIDE / SHOW BUTTONS button sits at the end of the strip, and stays at the bottom right while the strip is hidden. The choice is saved as `display.touch_controls` (in the browser's storage on the web). A hidden strip ignores all input, including the TABLE pads.
- **Layout:** the web page now rebuilds when it switches between landscape and portrait. In landscape the layout is as in D-173, plus the strip. In portrait (phones), the DMD sits above the TABLE and the BACKGLASS is left out. `--web-portrait` previews portrait on the desktop.
- **Web quits:** the picker's quit confirm is off in the browser, because a page can't quit and would freeze.
- **HTTPS only:** Godot's web build requires a secure context, so the plain-HTTP LAN address (`http://192.168.1.150:8086/pingames/`) shows an error. Use https://web.phoenixfox.net/pingames/. This corrects D-173 and D-175, which listed the LAN address as working.
- **Dev:** `--press=click:X.Y` clicks the mouse at window pixel X,Y. `--vr-cam=x,y,z` places the VR desktop-preview camera (for screenshots).
- **Status:** Accepted

### D-177 — Touch buttons at the sides; browser build installable as an app
- **Date:** 2026-11-22
- **Decision (director):** put the touch buttons beside the game area instead of under it, split to both sides on vertical layouts. They also asked for the web version to be installable as an app (Edge didn't offer it).
- **Side columns** (supersedes D-176's bottom strip): `core/touch_controls.gd` builds two columns that the web layout places at the left and right edges, in landscape and portrait, so the screens keep their full height. Left column: EXIT above a big LEFT. Right column: START and LAUNCH above a big RIGHT. The flippers are low, under the thumbs. Column width is 17% of the window's short side (64–240 px). The HIDE / SHOW BUTTONS toggle floats in the top-right corner over a small space at the top of the right column. Everything else from D-176 stays: multi-touch, TABLE halves as flipper pads, the two-frame minimum press and the saved setting.
- **Install as an app:** the Web preset's PWA option is on. The export adds `index.manifest.json` (name PinGames, standalone, black background, icons 144/180/512), `index.service.worker.js` (offline cache of the build) and `index.offline.html`. Edge and Chrome offer "Install" only for a page with a manifest and an active service worker, both of which it now has (checked in Chrome: worker active for `/pingames/`, manifest parsed). The HeroAR NGINX block needed `.json` in its MIME list (HeroAR DEC-0276, applied with `nginx -t` + `nginx -s reload`).
- **Icon:** a placeholder ("PIN" / "GAMES" in PinPixel on a dark neon-bordered tile), from `scripts/tools/gen_app_icon.py`, to be replaced when the director has art. It is also the project icon (`config/icon`), so the Quest APK and the page's favicon use it.
- **Status:** Accepted

### D-178 — Browser: pause on focus loss; draw everything once while loading
- **Date:** 2026-11-22
- **Decision (director):** stop the game when it loses focus. Also fix the noticeable pauses that remained when something appeared for the first time.
- **Focus pause** (`shell/focus_pause.gd`, browser build only, or `--pause-on-blur`): on focus loss the tree pauses, the master bus is muted, and PAUSED shows on the TABLE and DMD. On return, "PRESS ANY BUTTON OR TAP TO CONTINUE" appears, and the next key, tap, click or pad button resumes. That press is swallowed (`CabinetInput.mute_until_release`), so it doesn't act in the game. Cabinets are excluded, because a frontend or a Windows prompt can take focus there (D-069). It doesn't stack with the debug P pause.
- **First-time stalls:** files were already loaded by the D-175 loading screen. The remaining pauses were the first *draw* of each shader, material variant and texture, which in WebGL compiles and uploads synchronously. During the loading screen's warm-up frames, hidden behind the bar, `GameMode` now draws:
  - every loaded model, spatial shader and texture in front of the game's camera, and every texture and canvas shader on the TABLE;
  - one copy of every mesh/material pair in the game's tree, hidden ones included (pooled traffic, police, night lights, flashers), up to 300;
  - whatever the game's optional `warmup_nodes()` hook returns, for effects built only when they happen. Tilt Breaker returns a brick blast with debris, a power-up capsule, an enemy with its wormhole, an extra ball, an ion beam and the ghost ship. Turbo Run returns the tunnel wall, portal and lamp.
- **Checked:** on the desktop under the Compatibility renderer with the new `--log-spikes` (`?log-spikes`), which logs frames over 80 ms. Tilt Breaker's mid-game stall at its first brick break (126 ms) is gone, and Turbo Run's autopilot ran about 50 s with no slow frame after loading. Turbo Run's remaining slow frames came only from the debug stage-skip key, which rebuilds the track at once. The browser itself couldn't be measured this session, because Chrome throttled the background window to 1–3 fps.
- **Dev:** `--press` gained `blur` / `focus` steps (fake focus loss and return).
- **Status:** Accepted

### D-179 — Browser stalls traced to shader compiles; warm-up fixed
- **Date:** 2026-11-22
- **Context:** Tilt Breaker still stuttered in the browser when a level loaded, when the ball was lost and when the first portal appeared. A Chrome performance trace (headless Edge) showed every stall was WebGL compiling and linking shader programs.
- **Three causes, three fixes** (in `shell/modes/game_mode.gd`):
  1. **The warm-up missed the 3D worlds.** Games add them to the TABLE and BACKGLASS viewports (`add_to_table`), not under the game node, so the warm-up found no camera and no effects. It now searches the game node plus everything in its `_owned` list.
  2. **Godot frees a standard material's generated shader along with the last material that uses it.** So an effect that makes a fresh material each time (the ball-loss fireball) recompiled every time. From the warm-up until the game ends, one material per feature set (switches, modes, filled texture slots) is kept, static per game, so a second play keeps them too.
  3. **Lit materials compile a variant per combination of light types touching them.** The warm-up now cycles four phases (no extra light, point light, point + spot, spot) over 24 frames.
- **Also:** particles, multimeshes, labels and sprites are warmed as running copies of the real nodes, not as plain meshes. Tilt Breaker's `warmup_nodes()` adds the ball trail (built on the fly, so empty otherwise) and the ball-loss fireball.
- **Result:** in headless Edge, a scripted Tilt Breaker run (serves, lost balls, a portal, a level clear, the outro, the next level) has no frame over 80 ms after the loading screen. Before, there were stalls at every one of those moments. Only a few single compiles remain, each under 80 ms.
- **Tools kept:** `scripts/web_spikes.sh "<query>" [seconds]` builds, serves and runs the web build in headless Edge and prints slow frames next to game events (`DebugTools.mark`). `?log-shaders` logs every WebGL shader compiled, with its `#define` lines and material uniforms (a small page script in the Web preset's head include). `?no-focus-pause` turns off the focus pause for headless runs. Slow sound starts and DMD frames are logged too.
- **Stopped here (director):** the web build isn't the main platform. Turbo Run benefits from the same general fixes but wasn't measured this way.
- **Status:** Accepted

### D-180 — Flat-screen Android APK
- **Date:** 2026-11-22
- **Decision (director):** an Android APK of the flat-screen version.
- **Quest vs flat:** until now any Android build meant the Quest: `openxr/enabled.android` and `Config.layout()` returned "vr". Both now key on a custom `quest` feature tag, which only the Quest preset carries (`openxr/enabled.quest=true`). A new "Android" preset (`[preset.2]`) has no XR (`xr_mode=0`, no Meta plugin), package `org.pingames.flat`, arm64, Gradle, debug-signed. It excludes the addons and the VR cabinet model, and includes `*.txt` (levels).
- **Flat Android behaves like the browser build:** the single-canvas `web` layout (D-173), the touch buttons at the sides on touch screens (D-177), and the focus pause when the app is switched away (D-178). The picker's quit still works there, because an app can close. The screen follows the device orientation (`display/window/handheld/orientation=6`, sensor; the Quest ignores it), and the layout switches between landscape and portrait.
- **Build:** `scripts/build_android.ps1` waits for the APK to stop growing, then stops Godot, which may not exit after a headless export. The first build gave a 187 MB APK with only Godot's own libraries, no OpenXR loader, all 10 level files, and no VR model.
- **Test:** the export test now checks every preset for `*.txt`, and that only the preset with the `quest` feature uses OpenXR mode.
- **Note:** the existing Quest APK predates the `quest` tag, so rebuild it with `scripts/build_quest.ps1` before the next sideload.
- **Status:** Accepted

### D-181 — The Android APK is served from web.phoenixfox.net
- **Date:** 2026-11-22
- **Decision (director):** serve the flat-screen APK (D-180) through web.phoenixfox.net.
- **Where:** https://web.phoenixfox.net/pingames-apk/PinGames-android.apk (`K:\heroar\www\pingames-apk\`). It has its own folder because `deploy_web.ps1` mirrors `www\pingames` with `/MIR` and would delete it.
- **NGINX:** HeroAR's config had no `.apk` type, so the file went out as `application/octet-stream`. A `location ^~ /pingames-apk/` block now serves it as `application/vnd.android.package-archive` (`no-cache`), so an Android browser offers to install it (HeroAR DEC-0277). Applied with `nginx -t` and `nginx -s reload` through Portainer, with no restart.
- **Publishing:** `scripts/build_android.ps1 -Deploy` builds and copies it there.
- **Note:** it is debug-signed, so Android asks to allow installs from the browser ("unknown sources") the first time.
- **Status:** Accepted

### D-182 — Tilt Breaker difficulty levels
- **Date:** 2026-11-22
- **Decision (director):** three difficulty levels with different base ball speeds and more or fewer lives. The numbers below are Claude's proposal, for the director to tune.
- **Values** (`Sim.DIFFICULTIES`): Easy 6.8 → 11.5 u/s, operator balls + 2. Normal 8.5 → 13.5 u/s (the original tuning), operator balls. Hard 10.0 → 15.5 u/s, operator balls − 1 (at least 1). With the default 3 balls that gives 5 / 3 / 2 lives. The speed-up per ship hit (+0.25) is the same for all; extra balls from the Bounce power-up start at the difficulty's speed.
- **Choosing (2+1 buttons, D-007):** PRESS START now opens a DIFFICULTY screen on the TABLE: three rows with the ball speed and lives. The flippers (or magna saves) move, and LAUNCH / START confirm. The DMD shows the choice and its lives. Thirty idle seconds go back to attract. The choice is saved (`breakout.difficulty`) and preselected next time, except during scripted `--press` runs, which mustn't write `user://`. `--tb-difficulty=easy|normal|hard` sets it for dev runs, including `--tb-skip-intro`.
- **DMD status:** the life dots count the game's starting lives (`sim.balls_total`), no longer the operator setting.
- **Not changed:** one high-score table for all difficulties.
- **Tests:** lives 5/3/2, speeds and caps rising with difficulty, Normal equal to the original constants, Hard never below one life, and a later pick keeping the level.
- **Status:** Accepted

### D-183 — Turbo Run cars set the clock
- **Date:** 2026-11-22
- **Decision (director):** the three cars also make the game easier or harder through the time on the clock. The numbers are Claude's proposal, for the director to tune.
- **Values** (`Sim.CARS`: `time` and `bonus`):
  - **EASY (red):** 55 s to start; checkpoints +6 s (+40 falling to +26).
  - **NORMAL (yellow):** 45 s; +34 falling to +20 (unchanged).
  - **HARD (blue):** 40 s; checkpoints −4 s (+30 falling to +16).
  - The fall of 2 s per checkpoint is unchanged. The hard car is also the fastest, so it reaches checkpoints sooner, which partly makes up for its shorter clock.
- **Where:** `Sim.start_time()` and `checkpoint_bonus()` read the chosen car. `_new_sim()` sets the clock after the car is applied, and `--rc-time` still overrides it. The car select panels gain a "START TIME 55 S" line between top speed and cornering.
- **Tests:** start clock, checkpoint time and floor all ordered easy > normal > hard, and the normal car keeps the original numbers.
- **Status:** Accepted

### D-184 — Sky Striker hidden for now
- **Date:** 2026-11-22
- **Decision (director):** hide Sky Striker until there is something to show.
- **How:** `Registry.HIDDEN` lists games that `Registry.ids()` leaves out, so they're missing from the picker, the attract loop and the operator menu. `Registry.all_ids()` and `has()` still include them, so `--game=shmup` opens it for development. Remove "shmup" from `HIDDEN` to bring it back.
- **Status:** Accepted

### D-185 — Turbo Run car select: stats cards beside the cars
- **Date:** 2026-11-22
- **Decision (director):** improve how the three cars' stats are shown. The panels under the cars overlapped the next turntable and were plain grey boxes.
- **Layout:** the turntables move left of centre (`CAR_X` −1.9 m). Each car gets a card on the right half of the TABLE (x 662, 384 px wide), centred on its own row, so nothing overlaps.
- **Card:** a dark panel with a 4 px border and a soft glow in the car's colour (green EASY, yellow NORMAL, red HARD). The name sits at the top, then TOP SPEED, CORNERING and TIME, each a bar of 5 rounded segments with its value (mph, start seconds). Speed maps 72–88 m/s to 2–5 segments, time 40–55 s to 2–5, and cornering keeps its grip mapping. The chosen card is full colour; the others are darkened (modulate), not made see-through, so the sunset doesn't wash them out.
- **Status:** Accepted

### D-186 — Shell text in styled fonts
- **Date:** 2026-11-22
- **Decision (director):** the main attract mode's text, other than the logos, looked too simple and unappealing; use the better fonts.
- **Two shell styles**, made by `gen_title_fonts.py` like the game titles (D-062):
  - `marquee`: gold chrome with a light band and a red-brown 3D drop, for titles and prompts.
  - `chrome`: silver-blue chrome split at the horizon, for headings, scores and status.
  - Use them as `UI.SHELL_TITLE_FONT` / `UI.SHELL_TEXT_FONT`. One scale step is about 47 px.
- **Picker:** PINGAMES in marquee ×3, SELECT GAME / PLAY AGAIN and the high-score line in chrome ×1, the credits status in marquee ×1, the backglass fallback title in marquee ×4, and the quit confirm in marquee / chrome. The small button hint and the Windows warnings stay in PinPixel.
- **Attract:**
  - **Title page:** PINGAMES in marquee ×3, then the games as their logos (no longer coloured text). PRESS START is in marquee ×2 and blinks (modulate.a, D-096); the credits are in chrome. The backglass shows PINGAMES in marquee ×5.
  - **High-score pages:** the game's logo, HIGH SCORES in marquee ×2, the leader in gold, and the rest in chrome. A game without backglass art shows its title in its own styled font.
- **Status:** Accepted

### D-187 — Easy car gets +10 s per checkpoint
- **Date:** 2026-11-22
- **Decision (director):** apply Claude's suggestion. The EASY car's checkpoint bonus goes from +6 s to +10 s over NORMAL (+44 s falling to +30 s). Its 55 s start and the HARD car (−4 s) are unchanged until the director has played them.
- **Why:** `scripts/tools/racer_balance.gd` (autopilot, 8 track seeds, 8 checkpoints) put the EASY car 4.2 s per section slower than NORMAL. +6 s left only about 2 s of net help per checkpoint; +10 s gives about 6 s. HARD sits about 3.7 s per checkpoint behind NORMAL.
- **Status:** Accepted (amends D-183)

### D-188 — Radar lamps look like unlit lamps when off
- **Date:** 2026-11-22
- **Decision (director):** the radar bar's lights should look like real lamps switched off, not dark circles (reference: a sealed-beam lamp with a metal bezel and a clear ribbed lens).
- **Off lamp** (`radar_bar.gd` `_off_pixel`, the same chunky 4 px pixels as D-143), from the outside in:
  - a grey metal bezel, lighter top-left and darker bottom-right;
  - a dark inner lip;
  - a pale glass lens tinted only 16 % by its colour (blue or red), with alternating vertical ribs, slightly darker towards the reflector's centre and across the middle;
  - a small white glint top-left.
- **Lit lamps:** unchanged (glow halo, hot core).
- **Status:** Accepted

### D-189 — Turbo Run 4-button layout: shifter + brake
- **Date:** 2026-11-22
- **Decision (director):** the 4-button layout is left/right + shifter + brake. The throttle stays automatic as with 2 buttons, the shifter is a button instead of L+R, and the flippers rev on the grid. Update the on-screen text to match. (Supersedes the manual gas/brake of D-089 for 4+1.)
- **Buttons:**
  - Flippers: steer, and rev during the countdown.
  - Magna R: the shifter. Each press flips L ↔ H in the race (`sim.shift_request`). Presses on the grid or after time-up are dropped. Holding both flippers no longer shifts in this mode.
  - Magna L: brake. There's no auto-brake in this mode, because the player has a brake, and brake + steer still flicks into a drift.
  - Perfect shifts work with the button as they did with L+R.
- **Detection:** as before. The first magna press switches it on when `operator.cabinet_buttons` = auto, and it's always on with 4. It now stays on for the rest of the session's races (`_seen_magna`) instead of resetting each race.
- **Text:**
  - The attract how-to line has a 4-button version (`RC_HOW_TO_4`), now wrapped at 900 px with margins.
  - The DMD attract hint reads "RIGHT MAGNA: SHIFT" (`RC_SHIFT_HINT_4`).
  - The detection flash reads "SHIFTER + BRAKE".
  - The HUD tag shows "2 BUTTONS" / "4 BUTTONS" instead of AUTO / MANUAL, since both layouts now have automatic throttle.
  - The touch controls and the web hint are unchanged: touch is 2-button, and the keyboard's Ctrl keys are the magna saves.
- **Tests:** in 4-button mode the throttle is automatic, the left magna brakes, the shifter flips the gear once, both flippers don't shift, and a shifter press on the grid is dropped.
- **Status:** Accepted

### D-190 — Turbo Run sky: no lighter circle at the top
- **Date:** 2026-11-22
- **Problem (director, with a night screenshot):** a lighter circle or arc showed at the top of the sky.
- **Cause:** the sunset panorama is painted on an open ring 2000 m across that follows the camera. Its top rim is about 3040 m from the camera, but the camera's far plane was 2600 m, so the ring's upper part was cut off. Above that cut, the plain sky colour showed (graded for night separately), as a lighter arc when the camera tilted up on hills and crests.
- **Fix:**
  - **Far plane:** the camera's far plane is now 3200 m, so the whole ring is drawn.
  - **Lid:** a lid closes the ring's top. It uses the same panorama shader with `cap` on, so it takes the image's top row at each angle and gets the same night grade (kept in step with the ring). From below, the ring top and the lid read as one colour.
- **Dev:** `--rc-look-up=<deg>` tilts the race camera up, to check the sky's top.
- **Status:** Accepted

### D-191 — Turbo Run time of day: day 1–3, sunset 4–5, night 6–9
- **Date:** 2026-11-22
- **Decision (director):** stages 1–3 are daylight, 4–5 sunset, 6–9 night. Dawn stays from stage 10 (D-143).
- **Daylight**, with no new art: the sky shader grades the sunset painting (`day` uniform, 0..1):
  - a blue sky graded by height (deep at the top, pale at the horizon);
  - white clouds: a pixel is cloud where its brightness stands out from its row's average (8 samples), which catches both the bright upper clouds and the darker lower ones, and it must be 2+ pixels wide so the stars drop out;
  - a warm white sun with a slight glow;
  - blue-grey mountains shaded by their brightness.
  The lid (D-190) gets the same grade.
- **Lighting in daylight:** whiter sun (energy 1.3), brighter bluish ambient (0.85) and light blue fog. Night grades from the sunset values, and day and night never overlap.
- **Fades:** day → sunset over `Night.FADE` (8 s) when stage 4 starts (`Night.SUNSET_STAGE`); sunset → night when stage 6 starts (`Night.NIGHT_STAGE` 6, was 5). The attract demo is in daylight.
- **Music:** Dreamstate now crossfades in at stage 6 with the night (`OPENING_STAGES` 5, `NIGHT_STAGES` 4); the CodeManu songs still start at stage 10.
- **Dev:** `--rc-sunset` forces the sunset look; `--rc-night` forces night.
- **Status:** Accepted (amends D-113, D-129)

### D-192 — Turbo Run: hero engine 10% lower, noticeable passing Doppler
- **Date:** 2026-11-22
- **Decision (director):** the hero car's sound 10% lower; the passing cars' Doppler noticeable.
- **Hero engine:** both engine layers get `ENGINE_GAIN_DB` −0.92 dB (0.9× amplitude).
- **Why the passes were lost:** their loop was a low buzz (55–220 Hz) under the hero's engine, at most −6 dB and only within 45 m, and the wind covered it at speed.
- **Fix:**
  - The traffic loop is brighter, with 440 and 660 Hz partials.
  - Passes are louder (−2 dB up close, falling 30 dB over the range) and heard from 70 m (`PASS_RANGE`).
  - The Doppler is stronger: `SOUND_SPEED` is 85 m/s (was 110), which also affects the siren. The pitch follows faster (lerp 0.5), so it drops sharply at the moment of passing.
  - While the nearest car is within 15 m, the hero's engine and the wind duck by up to 4 dB (`PASS_DUCK_DB`).
  - Oncoming cars close at about 100 m/s and get the biggest shift.
- **Not checked by ear:** Claude can't listen; the director should judge it.
- **Status:** Accepted (amends D-134)

### D-193 — Turbo Run: procedural sky with a moving sun
- **Date:** 2026-11-22
- **Decision (director):** rebuild the sky to be realistic and to move from day to night (colour palette and sun movement). The graded painting showed two suns at the horizon (it was mirrored round the ring), and at hill crests the bottom of the sky dome showed brown.
- **Replaced:** the painted panorama ring (D-107), its lid and longer far plane (D-190), and the daylight grade (D-191) are gone, along with `sky_panorama.gdshader`. The painting stays only as the car-select backdrop.
- **New sky** (`games/racer/shaders/sky.gdshader`, a Godot sky shader drawn at infinity, so it has no edges):
  - a zenith-to-horizon gradient, plus a glow towards the sun that is strongest at the horizon;
  - one sun disc with a halo;
  - a moon (pale disc with seas) and twinkling stars at night;
  - fbm clouds on a flat layer, drifting and lit between shade and lit colours by the sun;
  - two mountain ridges (fbm on a circle, so no seam), hazy far and darker near;
  - below the horizon, haze in the fog colour, so crests look over a seamless horizon.
  The hash is sine-free; `sin()` of large numbers gave blocky square cloud edges on the GPU.
- **Time of day** (`games/racer/sky.gd`, pure functions):
  - Race progress (stages played plus the fraction of this one) maps to an hour: stage 1 13:00, stage 4 16:24, stage 6 18:18, stage 10 05:36, stage 11 06:36, then +1.2 h per stage.
  - The sun's elevation is 50°·sin(π(h−6)/12) and its azimuth runs from behind (sunrise) to the right (noon) to ahead of the road's start (sunset). It's fixed in the world, so it swings as the road turns.
  - The moon rides ahead-left, up to about 30°.
  - Six palette keyframes by sun elevation (45°, 15°, 3°, −3°, −9°, −20°) set the sky colours, cloud colours, ridges, the light's colour and energy, and the ambient light. The fog is the horizon colour mixed with the far ridge.
  - The directional light follows the sun, and the moon once the sun is below −4°.
  - `night_level` (−8°..2°) drives the headlights, lamps and night sprites.
- **Dev:** `--rc-tod=<progress>` picks a time; `--rc-sunset` and `--rc-night` still work.
- **Tests:** day for stages 1–3, low sun in 4–5, set by the end of 5, night 6–9, sun up in 10, one sun setting ahead, the moon up at midnight, and a smooth palette.
- **Status:** Accepted (supersedes D-107's backdrop, D-190 and D-191's grade; D-191's stage plan stands)

### D-194 — Turbo Run: softer pixelation
- **Date:** 2026-11-22
- **Decision (director):** soften the pixelation on the cars and the road a bit.
- **Resolution:** the race world renders at 480×854 instead of 360×640, so each game pixel is 2.25 TABLE pixels instead of 3, still upscaled nearest-neighbour.
- **Post pass:** 32 colour levels instead of 24, and dither 0.45 instead of 0.6, for gentler shading bands.
- **Unchanged:** the 16-bit look, the HUD, and the car-select showroom (its own 360×640 pass).
- **Cost:** about 1.8× the pixels to render.
- **Status:** Accepted (amends D-107)

### D-195 — Turbo Run HD / RETRO graphics setting
- **Date:** 2026-11-22
- **Decision (director):** an HD / RETRO setting before choosing cars. HD renders the game at native resolution with high-res sprites and textures; RETRO is the current look.
- **Choosing:** PRESS START opens a GRAPHICS screen over the attract demo, then the car select.
  - The left flipper (or magna) picks RETRO and the right picks HD; the road behind switches live.
  - Launch / Start confirms, and the screen confirms by itself after 15 s.
  - The choice is saved as `racer.graphics` (not during `--press` runs) and preselected next time. RETRO is the default.
  - `--rc-gfx=hd|retro` sets it for dev runs.
- **RETRO:** unchanged. The world renders at 480×854 through the palette/dither pass (D-107, D-194).
- **HD** (`_apply_gfx`):
  - Render: the world viewport takes the TABLE's own size with 4× MSAA, and the pixel pass is off (view filter linear).
  - Sprites: the HD cut-outs from `sprites/racer/hd/`, made by `prepare_racer_sprites.py --hd` from the Qwen originals at up to 1024 px, Lanczos-scaled with soft alpha. `Sprites.set_hd` swaps textures on the meshes already made.
  - Cars: `car.gdshader` samples `tex_hd`, the model's original high-res texture with linear, mipmapped, anisotropic filtering (`HD_TEXTURES`; the 4 K/2 K glb textures and the police car's 2 K original copied to `police2_albedo_hd.png`). All five share the retro textures' UV layout (checked: mean difference ≈ 0).
  - Road: `road.gdshader` `hd` drops the 25 cm texels.
  - Every other nearest-filtered material in the world (scenery atlas, tunnel, lights, smoke…) turns linear-mipmapped. Pieces added later get the same through `node_added`, and RETRO restores exactly the flipped ones.
  - The car-select showroom renders at 1080×1920 without the pixel pass, with an HD backdrop (`hd/sky.png`, 2048 px).
- **Notes:** the HD sprites come from pixel-art-styled generations, so they're crisp and detailed but keep a slight pixel character; painterly art would mean new generations. HD costs far more GPU than RETRO (about 4.5× the pixels plus MSAA), which is why RETRO is the default for phones and the web.
- **Tests:** HD cut-outs exist for every sprite kind, and HD textures for all five car models.
- **Status:** Accepted

### D-196 — Turbo Run: repainted plants and signs; RETRO sprites by shader
- **Date:** 2026-11-23
- **Decision (director):** regenerate the plants and signs, then make the RETRO versions with a shader.
- **New art:** both palms, both bushes, the curve sign, the green direction sign and the gantry, regenerated with Qwen-Image 2.1 on the local ComfyUI (approved, D-035). They're in a clean hand-painted style (no pixel art), on white for the cut-out, with the same compositions as before.
  - `scripts/tools/gen_racer_props_hd.py` makes two candidates each into `assets/source/racer/gen_hd/`. The picks are copied to `<name>.png`: palm_1 #2, palm_2 #1, bush_1 #2, bush_2 #1, sign_curve #2 (a single right curve; #1 was an S-curve), sign_green #1, gantry #2.
  - `prepare_racer_sprites.py --hd` cuts them out at up to 1024 px, Lanczos-scaled with soft alpha, and on plants clears the pale grey ground halo. Nitro and the speed trap keep their earlier art.
- **One texture per sprite:** `sprites/racer/hd/<name>.png` is used by both modes. The nearest-downscaled pixel sprites are deleted, and the script's default run now only writes the car-select sky.
- **Sprite shader** (`games/racer/shaders/sprite.gdshader`, replacing the StandardMaterial):
  - unshaded, alpha-scissored at 0.5, with a Y-billboard that keeps the node's scale;
  - mirroring (left curve sign) and the night tint as uniforms.
  - **HD:** samples the art with linear, mipmapped, anisotropic filtering.
  - **RETRO:** snaps the UVs to a coarse grid at each kind's old pixel-sprite height (palms 294/224 texels, bushes 91/77, signs 134/113, gantry 151, nitro and speed trap 126). Each cell reads the average colour from the matching mip level, then is banded to 12 levels per channel with a hard alpha edge.
  - `Sprites.set_hd` and `set_night` set shader parameters.
- **Status:** Accepted (amends D-107, D-195)

### D-197 — Window placement, first nitro, shift lamp, REV! hint, ground skirts
- **Date:** 2026-11-23
- **Decisions (director):**
  - **Window placement:** in the windowed layout the BACKGLASS and DMD sit to the right of the centred TABLE (D-148 had them on the left).
  - **First nitro:** the race's first canister (300 m in) sits in the player's path, on the start line's centre, so players pick it up and learn what it does. Later canisters still take random lanes.
  - **Shift lamp:** a round red lamp in the tachometer, between the 4, the 6 and the hub, in a chrome ring. It's dark red glass when off and lights red with a glow when the revs are in the perfect band: for a perfect shift in L during the race, and in the start band on the grid.
  - **REV! hint:** during the countdown, a hand to the right of the tachometer points left at its green start band, bobbing, with REV! above it in the race's "sunset" title font. The hand (`assets/textures/racer/rev_hand.png`, `scripts/tools/gen_rev_hand.py`) follows the director's line-icon reference, mirrored, in the same gradient and outline as that font. It disappears at GO.
- **Fix (director's screenshot of stage 3):** the ground strip beside the road ended in mid-air, so on hills its far edge showed as a raised green wave with sky under it; the old painted backdrop had hidden this. Each outer edge now hangs a skirt 400 m further out and 250 m lower, a gentle slope into the haze (a steeper one read as a grey wall).
- **Tests:** the first nitro sits in front of the car. The low-gear test now clears pickups, because the first canister is in its path.
- **Status:** Accepted (amends D-148, D-115)

### D-198 — Turbo Run police: hitting it slows it, ram streaks, night lights, siren light; tail lights
- **Date:** 2026-11-23
- **Decisions (director):**
  - **Hitting the police car slows it:** running into it from behind (the police car ahead) no longer counts as a police ram. It keeps 55 % of its speed and is shoved aside; the player keeps 92 % and bounces off a little. The same applies while it gives up or drives off. Contact from the side or from behind is still the police ramming the player.
  - **Ram streaks:** the 3 rams that bust the player must come close together. The count clears when more than `HIT_STREAK` (6 s) passes since the last ram, or when the player gets `HIT_RESET_GAP` (40 m) ahead of it. The DMD flashes SHOOK THEM OFF.
  - **Police lights at night:** the police car never received the night value, so it ran dark. It now gets head and tail lamps and the headlight beam at night, like every other car.
  - **Siren light:** while the light bar flashes, a red and a blue point light (14 m range) and an additive glow pool on the road (11 m) alternate with the flashers. They're faint by day (0.7 / 18 %) and strong at night (2.6 / 70 %), lighting the road and nearby cars.
  - **Tail lights:**
    - The lamps run dim at night (0.3) and go full when braking, with a hot core, instead of one flat level.
    - At night every car, including the hero, traffic cars, hatchbacks and the police car, has a soft red glow at each rear lamp (`TAIL_AT` per model), as the trucks already did.
    - The hero's glows grow while braking (1.6×).
- **Tests:** rams far apart don't add up, getting away clears the count, and running into the police car slows it without counting as a ram.
- **Status:** Accepted (amends D-137, D-142, D-120)

### D-199 — Tail lights: soft lamp light, glows on the lamps
- **Date:** 2026-11-23
- **Problem (director, with a screenshot):** the red tint round the hero's tail lamps was hard-edged, and the new glow circles weren't on the lamps.
- **Soft lamp light:** `car.gdshader` lights the tail and head lamp areas through `soft_box`, which fades out over 6 cm (5 cm for the head lamps) instead of a hard box. The light spills softly onto the body.
- **Glows on the lamps:** the glows from D-198 were placed in the car node's space by estimate. `_place_tails` now moves them onto the body mesh, in the model's own space, at the centre of the lamp area the shader lights (`LAMP_BOXES`, else the shader's defaults), 4 cm behind the mesh's rear surface. This is done for the hero, traffic cars, hatchbacks and the police car. They follow the night-lights holder's visibility.
- **Size:** 0.6× when running and 0.95× when braking, at 60 % strength, so they read as a halo, not a solid disc.
- **Status:** Accepted (amends D-198)

### D-200 — Losing the police takes distance held over time
- **Date:** 2026-11-23
- **Decision (director):** to lose the cop car you must be more than X away from it for Y time. It must not be possible to lose a cop who's right behind you, however long you've been running.
- **Before:** it gave up after 22 s of chase (`POLICE_GIVE_UP`) wherever it was, or at once at 260 m behind (`POLICE_LOST`). Both are removed.
- **Now:** while chasing, `police.lose_t` counts up while the player is more than `ESCAPE_GAP` (120 m) ahead and drops to 0 whenever it's closer. At `ESCAPE_TIME` (4 s) it gives up as before: it falls back, lights and siren go off, and the escape bonus and LOST THEM! show. The chase's length no longer matters.
- **Tests:** a police car 30 m behind through 10 s of chase (500 s in) never gives up, and staying more than 120 m ahead loses it after 4 s, not sooner.
- **Status:** Accepted (supersedes D-145's give-up rule)

### D-201 — Flat out, every car keeps away from the police
- **Date:** 2026-11-23
- **Decision (director):** at each car's top speed the player should be able to keep away from the cop car.
- **Change:** the police car's top speed is 95 % of the chosen car's top speed (`POLICE_TOP`, was 106 %, which only nitro could beat). Flat out in H the player gains about 3.6–4.4 m/s on it, depending on the car. Slowing for bends, traffic or a crash lets it close in, and nitro still gets away fastest.
- **Escaping:** from close behind it takes roughly 30 s flat out to open the 120 m gap, then 4 s held, to lose it (D-200).
- **Tests:** each of the three cars, held at its top speed, pulls more than 40 m ahead of a chasing police car within 10 s.
- **Status:** Accepted (amends D-142)

### D-202 — Turbo Run car colours: easy blue, normal red, hard orange
- **Date:** 2026-11-23
- **Decision (director):** the easy car is blue, the normal car red and the hard car orange.
- **Change:** the hue rotations in `Sim.CARS` (the cars are the red model recoloured) are 0.62 (blue), 0.0 (red, the model's own) and 0.08 (orange). Before, they were red, yellow and blue. The DMD's car icon colours (`CAR_COLS`) follow. The car-select cards keep their difficulty colours (green, yellow, red).
- **Status:** Accepted (amends D-122)

### D-203 — Police catch-up phase: flat out at 105 %, can't be lost
- **Date:** 2026-11-23
- **Problem (director):** after D-200/D-201 it was too easy to lose the cops; they went out of range almost at once. The police appears 140 m behind (`POLICE_BEHIND`), already past the 120 m escape gap, so the 4 s escape count started straight away, and at 95 % it couldn't close in.
- **Decision (director):** a period at the start where they go flat out at 105 % of the player and can't be lost.
- **Catch-up:** a new chase starts with the police capped at `POLICE_CATCH_TOP` (105 %) of the car's top speed, closing at up to 16 m/s over the player (`CHASE_CLOSE`), and the escape count held at 0. It ends (`police.caught`) the first time the police gets within `CAUGHT_GAP` (25 m), or after `CATCH_UP_MAX` (25 s) so a long nitro run can't make it unshakeable. After that D-201 applies: 95 % top speed, and 120 m held for 4 s loses it (D-200).
- **Tests:** a fresh chase on a car flat out isn't lost in 8 s and the police gains more than 10 m. The escape test starts with a police car that has already caught up.
- **Status:** Accepted (amends D-200, D-201)

### D-204 — Turbo Run beach stage (stage 1) and stage 2 trees
- **Date:** 2026-11-23
- **Decision (director):** a beach stage: sand and sea on one side with moving waves, a flat-ish road, small buildings on the other side, palm trees. Then: the beach is stage 1, before the change to grass fields, and stage 2 gets different trees.
- **Beach weight:** `Track.beach_w(s)` is 0..1 per stage in `BEACH_STAGES` (`[1]`). Stage 1 starts at 1, and the beach blends out over the last 200 m (`BEACH_BLEND`). Other beach stages would blend in and out at both ends.
- **Ground:** `Track.ground_rise(s, x)` replaces the plain embankment in `point()`. On the beach the left side dips from the kerb to the sea (`SEA_LEVEL` −1.6 m, reached at `SHORE` 30.7 m from the centre) and the right side keeps a quarter of the embankment. The left skirt stays flat at sea level, so the sea runs to the horizon.
- **Road:** sections that touch the beach get gentle grades (±1.5 %), no steep hills and no tunnels.
- **Water** (`road.gdshader`, beach weight in UV2.x): sand, then wet sand, then a sea from shallow turquoise to deep blue over 60 m. Foam lines roll in, broken up along the shore, the waterline washes in and out (±0.9 m), there's surf at the edge and glints on the water. The right side is sand, then sandy grass.
- **Dressing:** palms on the sand by the road; a lifeguard tower near the water now and then; on the right, small buildings (blue cottage, pink villa, surf shop) at 16–26 m from the edge with palms between; lamps along the promenade. No bushes on the sand, and fewer on the right.
- **Stage 2:** palms become oaks and cypresses, mixing in over its first 300 m.
- **Art:** the 4 beach sprites and 2 trees, from Qwen-Image 2.1 in the D-196 painted style (two candidates each, picks copied to `gen_hd/<name>.png`), cut by `prepare_racer_sprites.py --hd` and drawn by `sprite.gdshader` (HD, or RETRO pixelated).
- **Dev:** `--rc-stage=N` starts the race at the beginning of stage N.
- **Status:** Accepted

### D-205 — Turbo Run: the hot hatch is the easy car, and in traffic
- **Date:** 2026-11-23
- **Decision (director):** the new `hothatch.glb` replaces the easy car's model and joins the traffic. It has two exhausts together on its left side, and its lights sit differently from the red car's.
- **Model:** run through `prepare_racer_car.py` like the others: full 39k-tri mesh, 4.1 m long, 256 px albedo for RETRO, and the original texture for HD (`HD_TEXTURES`, now six models). Nose +Z like the red car.
- **Per-model settings:** `scripts/tools/measure_racer_car.gd` reports a model's lamp texels, low rear geometry and wheel areas, and orthographic Blender renders check them.
  - `CAR_MODELS` gives the player's model per car (easy = hot hatch).
  - `EXHAUSTS` places the nitro and backfire flames per model: the hot hatch's are at x +0.42 / +0.53, 0.26 m up, which is its left.
  - `PLATES` places the TRN plate over its own plate (0.43 m up).
  - `LAMP_BOXES` and `TAIL_AT` hold its tail and head lamps, for the night glow spots and lamp shading.
- **Build:** `_build_body(model)` builds the player's body (model, night lights, tail glows, plate, flames). It runs at race start for the chosen car, and rebuilds only when the model changes. The showroom shows each car's own model.
- **Colour:** it keeps the easy car's blue (D-202) through the usual hue recolour; its texture is red like the red car's.
- **Traffic:** one in five cars is a hot hatch (`id % 5 == 4`), from a pool of 6, with the same per-car hue and night lights as the others.
- **Status:** Accepted

### D-206 — Turbo Run: double roll-over at 100+ mph; the hot hatch is red
- **Date:** 2026-11-23
- **Decision (director):** a car that hits a big obstacle at over 100 mph does 2 sideways flips. The hot hatch is red.
- **Double roll:** in `Sim._crash`, a roll-over (`FLIP_KINDS`: palm, rock, lamp, truck, wall) at a shown speed of `DOUBLE_FLIP_MPH` (100) or more sets `flip_turns = 2`.
  - The animation runs `DOUBLE_FLIP_TIME` 2.1 s instead of 1.33 s.
  - The view rolls twice, with twice as many stepped poses, and hops 60 % higher.
  - Below 100 mph it is the one roll of D-098.
- **Colour:** the easy car's hue is 0.0, so the hot hatch keeps its own red paint. This supersedes D-202's blue. The normal car is red too: the two are told apart by their model.
- **Status:** Accepted

### D-207 — Turbo Run graphics: 8-BIT mode; RETRO renamed 16-BIT
- **Date:** 2026-11-23
- **Decision (director):** rename the RETRO option to 16-BIT, and add an 8-BIT option that renders the game in the NES style: a limited colour palette on top of the pixel shader.
- **Options:** 8-BIT, 16-BIT, HD, in that order. The flippers step left and right through them, the road behind switches live, and Launch confirms. The 16-BIT id stays `retro`, so saved settings carry over; 8-BIT is `nes`. Dev: `--rc-gfx=nes|retro|hd`.
- **8-BIT:** the world renders at `NES_RES` 270×480 (16-BIT is 480×854). `pixel_post.gdshader` with `nes` on dithers each pixel (4×4 Bayer, ±0.045) and snaps it to the nearest of 54 fixed colours, using weighted RGB distance (2, 4, 3).
- **Palette:** 12 hues every 30° starting at blue, in 4 brightness rows (HSL lightness 0.30 / 0.50 / 0.72 / 0.88), plus 6 greys from black to white. We generated it ourselves in the style of the 8-bit consoles' palettes; it is not a copy of one.
- **Showroom:** in 8-BIT it uses the same palette, at 0.75 of its resolution.
- **Status:** Accepted

### D-208 — Turbo Run: animation steps per graphics mode; nitro texels
- **Date:** 2026-11-23
- **Decision (director):** 16-BIT doubles the number of frames and positions for the car's turning and other animations. HD is completely smooth. Check whether the nitro pickups are pixelated.
- **Steps:** `_anim_mult` is 1 in 8-BIT (the D-092/D-098 counts), 2 in 16-BIT, and 0 in HD (no stepping). It scales:
  - the sprite-style car angles: 32 views, or 64 in 16-BIT;
  - the crash animation frame rate: 10 fps, or 20;
  - the roll-over poses: 8 per turn, or 16;
  - the TIME UP slide: 6 steps, or 12;
  - the wheel spin and the nitro bob;
  - the showroom turntable: 32 or 64 angles.
- **HD:** all of the above are smooth.
- **Nitro:** it was pixelated in 8-BIT and 16-BIT, but at 126 texels for 2.6 m (48/m), much finer than the other sprites (25–37/m), so it looked sharp beside them. It is now 80 texels (31/m).
- **Status:** Accepted

### D-209 — Turbo Run REV! hint: smaller hand, further out, 3 pokes
- **Date:** 2026-11-23
- **Decision (director):** make the REV! hand smaller, move it a bit further outside the tacho, and only blink 3 times.
- **Size:** the hand is redrawn at 79×47 px (`gen_rev_hand.py` `PIX` 7, was 5; 111×66), still shown at 2×. That is about 70 % of the old size, with even pixels.
- **Place:** at rest the fingertip is `REV_HAND_GAP` 44 px outside the green start band (was 10–20 px).
- **Motion:** it pokes towards the band `REV_POKES` 3 times (about 2 s), then holds still until GO. Before, it bobbed for the whole countdown. The hint itself stays on screen until GO.
- **Status:** Accepted

### D-210 — Turbo Run: supercar is the hard car; the medium car is green
- **Date:** 2026-11-23
- **Decision (director):** the new `supercar.glb` is the hard car, and the medium car is green.
- **Model:** run through `prepare_racer_car.py` at 4.5 m with the full 36k-tri mesh. Its texture atlas is in thousands of tiny pieces, and at the usual 256 px it turned to mush, so it gets a 1024 px albedo for 8-BIT and 16-BIT (still nearest-sampled; the screen pass does the pixelation). HD uses the 8K original downscaled to 4096 (`supercar_albedo_hd.jpg`).
- **Per-model settings** (from orthographic renders):
  - 4 exhaust flames, two each side at x ±0.52 / ±0.64, 0.27 m up;
  - plate at 0.43 m;
  - tail lamps |x| 0.45–0.85, y 0.66–0.9; head lamps |x| 0.45–0.75, y 0.52–0.7;
  - night spot keys `supercar`.
  - `MODEL_TEXTURES` and `MODEL_LIGHTS` replace the hot-hatch special cases in `_build_body` and the showroom.
- **Colours:** car hues rotate each model's own paint. Easy is 0 (the hot hatch's red). Normal is 0.36 (the red car turned green). Hard is 0 (the supercar's own yellow; was 0.08 orange on the red car, D-202).
- **Traffic:** the supercar is not added to traffic (not asked).
- **Status:** Accepted

### D-211 — Turbo Run: the car bounces after a roll-over
- **Date:** 2026-11-23
- **Decision (director):** make the car bounce a bit after the side flips.
- **Bounce:** when the roll-over lands, the car bounces on its wheels every `LAND_PERIOD` 0.26 s, starting `LAND_HEIGHT` 0.45 m high (40 % higher after a double roll), dying away exponentially over `LAND_TIME` 1 s. It also rocks side to side by up to `LAND_ROCK` 0.12 rad.
- **Timing:** the view times it with its own timer, so it plays out whether the car is still sliding or already stopped.
- **Steps:** it follows the graphics mode's animation steps (D-208): 20 frames/s in 8-BIT, 40 in 16-BIT, smooth in HD.
- **Status:** Accepted

### D-212 — Turbo Run: plates fitted on the hot hatch and supercar; smooth radar lamps in HD
- **Date:** 2026-11-23
- **Bug (director):** the number plates on the easy and hard cars were placed wrong.
  - **Cause:** both used the red car's oversized plate (0.51 × 0.255 m), which is bigger than their real plates. On the supercar its top edge reached into the bulging bumper above (rear surface −2.25 m at 0.53 m up), so the paint stripes covered it. On the hot hatch it spilled over the bumper.
  - **Fix:** `PLATES` now holds a centre and a size per model, fitted to the model's own plate (from renders), just in front of its rear surface (measured from the mesh). Hot hatch: 0.37 × 0.185 at y 0.415, z −2.025. Supercar: 0.34 × 0.17 at y 0.43, z −2.215. The red car is unchanged.
- **Bug (director):** the radar lights looked pixelated in HD.
  - **Fix:** `radar_bar.gd` gets `smooth`, set from the HD mode. It draws the same lamp in antialiased circle layers instead of 4 px blocks:
    - **Off:** a bezel lit top-left, a dark lip, pale tinted glass darkening into the bowl, and a glint.
    - **On:** a soft glow halo, a hot rim, the colour, and a white core.
  - 8-BIT and 16-BIT keep the pixel lamps.
- **Status:** Accepted

### D-213 — Turbo Run: realistic oncoming horns
- **Date:** 2026-11-23
- **Decision (director):** make the oncoming traffic's horns more realistic. Before, they were a chiptune beep: two square waves (392 and 494 Hz), 0.18 s, with an echo.
- **Sound:** a dual-tone electric car horn synthesised at load (`_horn_wav`).
  - **Tones:** a low and a high tone, 415 and 500 Hz, a dissonant interval apart like real horn pairs.
  - **Timbre:** each is a buzzy diaphragm tone (harmonics at 1/k up to 11 kHz), boosted around a nasal resonance at 2 kHz. It is read from a 512-sample single-cycle wavetable, so building it is cheap.
  - **Each press:** starts about 4 % flat and settles in 25 ms (the diaphragm scoop), with a slight pitch jitter, an 8 ms attack, a 35 ms release and soft clipping for grit.
- **Patterns:** "beep-beeep", one long blast, or "beep-beep-beeep", picked at random per honk.
- **From the car:** it plays from the honking car.
  - **Pitch:** Doppler from the car's closing speed against `HORN_SOUND_SPEED` 300 game m/s. That is near the real speed of sound in game units (about 400), so a head-on pass is roughly +30 % pitch, dropping as it goes by. The engine buzz keeps its exaggerated 85 (D-192).
  - **Volume:** falls 6 dB per doubling of distance past 15 m.
- **Test:** the three patterns synthesise in under 1.5 s and are audible.
- **Status:** Accepted

### D-214 — Turbo Run horns: a clear BEEP BEEP, audible from afar
- **Date:** 2026-11-23
- **Bug (director):** with the D-213 horns you couldn't tell when a driver was honking at you. It should be BEEP BEEP.
- **Cause:** honks start up to 170 m away (`HIGHBEAM_RANGE`), where D-213's 6 dB-per-doubling falloff left them at about −24 dB, under the engine. The random patterns (one long blast, a triple) didn't read as a honk at you either.
- **Fix:**
  - **Pattern:** always two equal 0.3 s presses with a 0.15 s gap.
  - **Falloff:** about 2.4 dB per doubling past 15 m, so a honk is about −9 dB at 170 m and 0 dB close.
  - **Ducking:** while it sounds, the engine and wind dip by `HORN_DUCK_DB` 6 dB.
  - The tone, Doppler and synthesis are unchanged.
- **Status:** Accepted

### D-215 — Turbo Run radar: no black block; dry beeps in tunnels
- **Date:** 2026-11-23
- **Decision (director):** remove the radar's black square. The radar beeps shouldn't get the tunnel reverb, because the detector is inside the car.
- **Bar:** the black block between the blue and red balls is gone (supersedes that part of D-137/D-139). The balls keep their spacing, leaving a gap in the middle.
- **Beep:** it plays on its own player on an `SFXDry` bus, which sends straight to Master and copies the SFX bus's volume and mute at each beep. The tunnel reverb sits on the SFX bus (D-127), so it no longer touches the beep. `Audio.sfx` isn't used for it, so the shared player pool keeps its buses.
- **Status:** Accepted

### D-216 — Turbo Run areas: city, desert, forest, snowy mountain; start-stage picker
- **Date:** 2026-11-23
- **Decision (director):** after the beach and fields, new areas change every 2 stages: a city with tall buildings and junctions to drive through, a desert, a forest and a snowy mountain, each with its own scenery. (Weather is in a later slice.) The director also asked for stage selection at the game start, for testing.
- **Schedule:** `Track.stage_area(k)`: stage 1 beach, 2 fields, 3–4 city, 5–6 desert, 7–8 forest, 9–10 snow, then the four repeat from the city.
  - `areas(s)` gives weights that cross-fade into the next stage's area over its last `AREA_BLEND` 200 m.
  - The beach (D-204) now runs through this; `beach_w` is the beach's weight.
- **Ground:** `ground_rise` blends a profile per area:
  - city: flat;
  - desert: half the embankment plus low dunes;
  - forest: ×1.3;
  - snow: ×3.2, steep mountainsides.
- **Road:** sections touching the city are flat-ish (±1.5 %), the desert has long gentle grades (±5 %), and the snowy mountain climbs and drops more often (45 % of sections, grade 10–22 %). There are no tunnels in the city.
- **Ground shader:** `road.gdshader` gets the area weights per vertex (UV2 = beach, city; COLOR = desert, forest, snow).
  - City: grey kerbs, a paved sidewalk with 1.5 m slabs, darker plazas.
  - Desert: orange sand with wind ripples.
  - Forest: dark grass with needle patches.
  - Snow: white and blue, with dusted road edges.
- **City** (`city.gd`):
  - **Buildings:** one MultiMesh of unit boxes per chunk, scaled per building: 12–26 m wide, 14–24 m deep, 16–70 m tall, and 15 % are 1.6× taller. They stand in a row each side at 5 m behind the kerb. `building.gdshader` draws 6 facade styles procedurally: glass tower, sandstone, brick, concrete strip windows, white, dark glass. Each has floors of windows, a shopfront ground floor, a parapet and a flat roof. Windows are lit at random at night (`night` = `Night.level`).
  - **Junctions:** every 260–420 m on straight-ish road. The buildings leave a gap, and a cross-street strip (`junction.gdshader`) draws asphalt with a dashed centre line and zebra crossings over the main road.
  - **Traffic lights:** one each side, on a pole with an arm over the road. Their lamps cycle green 7 s, amber 1.6 s, red 5 s (visual only).
  - **Street lamps:** both sides every 30 m.
  - **No trees or bushes.**
  - **Sidewalk barrier:** `Track.side_wall` / `CITY_WALL` (2.6 m past the kerb). The sim holds the car there and it scrapes along, like a tunnel wall but with no portal crash.
- **Props per area:** the view maps the track's generic kinds by area. During a cross-fade it picks by area weight per object, so the change is gradual.
  - Trees: beach palms, field oaks/cypresses, desert saguaros, forest pines/spruces, snow spruces.
  - Bushes: desert shrubs, forest ferns, snowy boulders.
  - Rocks: snowy boulders on the snow.
  - Desert: cacti (saguaro / prickly pear), and buttes 70–130 m out.
  - Forest and snow: trees close and thick (every 9–15 m both sides).
  - Bushes: none in the city, sparse in the desert and on the snow.
- **Art:** 9 sprites from Qwen-Image 2.1 in the D-196 painted style (two candidates each, one picked), cut by `prepare_racer_sprites.py --hd`.
- **Start stage (testing):** after GRAPHICS, a START STAGE (TEST) screen. Flippers pick 1–10, the area's name shows, Launch confirms (or the timer). It isn't saved, and every game starts the picker at 1. The race starts at that stage's beginning, with its clock and checkpoint count (as `--rc-stage`).
- **Tests:** the area order, the city barrier, and that the city has buildings and junctions.
- **Status:** Accepted

### D-217 — Turbo Run weather: rain with reflecting puddles, fog, haze, snow
- **Date:** 2026-11-23
- **Decision (director):** add weather effects that trigger on different stages. Rain makes puddles with fake reflections.
- **Schedule:** `Track.stage_weather(k)`: clear on stages 1–3, then per 8-stage round of the areas: city clear / rain, desert clear / haze, forest fog / rain, snow / snow.
  - So rain is on 4 and 8, haze on 6, fog on 7 and snow on 9–10.
  - `Track.weather(s)` gives the weight: it sets in over 300 m and clears 200 m before a stage whose weather differs.
  - The view smooths it further (0.6 per s).
  - `--rc-weather=rain|snow|fog|haze` forces one for screenshots.
- **Sky and light:**
  - **Overcast** (rain, snow; fog at 80 %): sky and clouds turn grey and darker, clouds thicken (cloud cover 0.56 → 0.12), the sun disc and glow fade, and sunlight dims by up to 55 %.
  - **Haze:** sky, clouds and fog take a sandy tint.
  - **Fog depth** at full strength (begin–end m): rain 90–430, snow 45–320, fog 12–160, haze 60–380. Clear is 250–850.
- **Rain:**
  - **Particles:** 1,400 world-space CPU streaks (an X of thin quads aligned to their velocity), emitted in a box ahead of the camera, so the car drives through them.
  - **Sound:** a noise hiss whose volume follows the rain.
  - **Wet road:** `road.gdshader` `wet` darkens it by 32 % and makes it glossy (roughness 0.92 → 0.35).
  - **Puddles:** `puddles.gdshader`, as the road material's `next_pass`. A value-noise mask in road metres, out to the sidewalk, grows with the rain. Inside it, the screen is sampled mirrored about the horizon line (a far level point ahead, projected), which is the fake reflection. Raindrop rings ripple it, and it is tinted grey-blue. At night it reflects the lit windows, lamps and lights.
- **Snow:** 2,200 billboard flakes falling slowly with drift.
- **Fog / haze:** fog and sky only.
- **Tunnels:** nothing falls inside, and the hiss drops 10 dB.
- **Warm-up fix:** the web warm-up (D-195) started copied particle emitters out of the scene tree, which errored for world-space emitters. Its copies are now local-space.
- **Gameplay:** no grip change; it is visual only.
- **Tests:** the weather order, and that rain sets in gradually.
- **Status:** Accepted

### D-218 — Turbo Run forest: tall lines of trees on both sides
- **Date:** 2026-11-23
- **Decision (director):** the forest should have tall lines of trees on both sides.
- **Placement:** `Track._place_forest` replaces the forest's scattered trees (D-216) with `FOREST_ROWS` 3 rows per side, at 3.6, 8.4 and 13.5 m past the kerb (±0.7 m). They repeat every `FOREST_STEP` 6 m, with odd rows staggered by half a step and ±1.2 m jitter. 10 % of trees are skipped, so the line isn't a fence.
- **Size:** pines are drawn 1.05–1.45× (was 0.85–1.2×), +10 % per row further back, so the walls rise away from the road.
- **Collisions:** the trees keep their normal radius, so leaving the road in the forest means hitting the tree line.
- **Unchanged:** the snowy mountain keeps its scattered spruces.
- **Status:** Accepted

### D-219 — Turbo Run: random weather spells; BRAKE and SHIFT touch buttons
- **Date:** 2026-11-23
- **Decision (director):** weather should start at a random place with a random kind, then last a minimum duration. Add shifter and brake buttons for Android.
- **Weather** (supersedes D-217's fixed schedule; the looks are unchanged):
  - **Spells:** `Track.spells`, generated on demand from `weather_seed`. The first starts 500–3,500 m in. Each lasts `WEATHER_MIN` 1,400 m (about 35 s at speed) to 3,000 m, with clear gaps of 1,200–3,500 m between. They fade in and out over 300 m inside the spell.
  - **Kind:** picked at random from `AREA_WEATHER` for the area at the spell's middle:
    - beach, fields, city, forest: rain or fog;
    - desert: haze;
    - snow: snow or fog.
  - **Fit:** the weight is scaled by how much of the area at s suits the kind, so snow stops as the mountain ends.
  - **Per race:** the game sets a random `weather_seed` for every race. `--rc-wseed=N` repeats one; `--rc-weather` still forces a kind.
  - **Test:** spells are at least `WEATHER_MIN` long, suit their area, are clear before they start, and differ between seeds.
- **Touch buttons** (`core/touch_controls.gd`, web and Android):
  - The magna saves get a button each: magna_l in the left column above LEFT, magna_r in the right column above LAUNCH.
  - Their default label is MAGNA. A game renames them through the `touch_controls` group (`set_labels`): the racer shows BRAKE and SHIFT, and restores the defaults when it exits.
  - Pressing either one switches the racer into its 4-button mode on the spot (D-189).
- **Status:** Accepted

### D-220 — Touch controls: matching columns
- **Date:** 2026-11-23
- **Decision (director):** the LEFT and RIGHT buttons should be the same size, and the two magna buttons the same size and position as each other.
- **Fix:** both columns now have the same slots with the same stretch ratios:
  - left: top space (as tall as the HIDE toggle's), EXIT 1, empty 1.3, MAGNA/BRAKE 1.3, LEFT 3;
  - right: toggle space, START 1, LAUNCH 1.3, MAGNA/SHIFT 1.3, RIGHT 3.
  - LAUNCH and the right magna swapped places, so the magnas sit level directly above the flippers.
- **Status:** Accepted

### D-221 — Turbo Run: finish line at the end of stage 10
- **Date:** 2026-11-23
- **Decision (director):** the end of level 10 is the finish line.
- **Sim:**
  - **Crossing:** the 10th checkpoint (`FINISH_STAGE`) calls `_finish()` instead of a checkpoint. No time is added.
  - **Bonuses:** `FINISH_BONUS` 100,000, plus `TIME_BONUS_PER_S` 2,000 for every second left (`time_bonus`).
  - **After the line:** `finished` is set and the car coasts out (State OVER). A later gate can't restart the race, and `done` follows once it stops.
  - It also works if the line is reached on momentum after TIME UP.
- **View:**
  - **Gate:** the last gate reads FINISH! with a chequered beam, and a chequered stripe crosses the road. There are no gates after it.
  - **Event `finish`:** a fanfare, a FINISH! centre message and DMD flash, and a screen flash. The HUD stage label reads FINISH!.
  - **No slide:** the TIME UP sideways slide (D-105) is skipped when finished.
  - **Results screen:** titled FINISH! (yellow on the DMD) instead of GAME OVER, with a TIME BONUS line.
- **After the line:** the track goes on behind it (back into the city), only as run-off.
- **Test:** crossing the end of stage 10 finishes the race with both bonuses and ends it.
- **Status:** Accepted

### D-222 — Turbo Run: drift-brake after the finish line
- **Date:** 2026-11-23
- **Decision (director):** the car should slide sideways in a drift-brake after the finish line.
- **Change:** past the line, the car uses the TIME UP slide (D-105), which D-221 had skipped. It swings `FINISH_DRIFT` 0.83 of 90° (about 75°) towards the inside of the bend, in stepped frames, with tyre smoke and the skid squeal. It brakes at `FINISH_DECEL` 15 m/s² (coasting out after TIME UP is 7), so it stops in about 3 s, sideways.
- **Status:** Accepted

### D-223 — Turbo Run: gentler traffic, soft slow crashes, traffic waits behind a crash, finish banner
- **Date:** 2026-11-23
- **Decisions (director):**
  - By stage 6 the traffic is unbearable.
  - Slow crashes should only slow the car, not spin it.
  - Vehicles behind should stop and wait when you crash.
  - No cars should spawn past the finish line.
  - The finish banner is red with big yellow letters.
- **Traffic:** `traffic_target` is `min(7 + checkpoints, 11)`, which is 7, 8, 9, 10, 11 from stage 1, and 11 from stage 5 on. It was `min(7 + 2n, 16)` (D-101), already at 15 on stage 5.
- **Soft crashes:** below `SOFT_CRASH_MPH` 55 (shown), hitting traffic (rear-end or head-on) or a roadside object is a knock (`_soft_bump`). The car keeps 45 % of its speed and bounces aside, with no spin or roll-over. It still drops out of a drift, and the bump sound plays.
- **Waiting traffic:** while the car is crashed (`spin_t`), same-direction traffic up to 140 m behind and in line with it brakes (up to 16 m/s²) to stop 5 m behind. It pulls away again once the car is going.
- **Finish:** no traffic spawns past the finish line.
- **Banner:** the finish beam is a deep red, 3.4 m tall, with big yellow FINISH! letters (pixel size 0.0145, dark red outline). The chequered stripe stays on the road (supersedes D-221's chequered beam).
- **Tests:** a slow knock into a truck only slows the car; traffic behind a crash stops and waits; nothing spawns past the finish; at most 11 cars.
- **Status:** Accepted

### D-224 — Operator menu: reset all high scores, easier to find
- **Date:** 2026-11-23
- **Decision (director):** add an option in the operator's menu to reset all high scores.
- **Finding:** it already existed (RESET HIGH SCORES → ALL GAMES, press twice; `HighScores.reset("")` clears every game's tables, the hidden ones too). But it was last in the list and showed no value, unlike the per-game RESET entries.
- **Change:** ALL GAMES is now first in RESET HIGH SCORES and shows RESET (then PRESS AGAIN) like the others.
- **Access:** the operator menu opens by holding EXIT (or START + EXIT) in the attract screen or the game picker, including on the touch EXIT button.
- **Status:** Accepted

### D-225 — Turbo Run: new stage order and times; night city; screen-space rain reflections
- **Date:** 2026-11-23
- **Decisions (director):**
  - Stages: beach, beach, forest, forest, desert, city, city, fields, snowy, snowy.
  - Time of day: day, day, day, sunset, sunset, night, night, night, dawn, dawn.
  - Darken the city's buildings but add lit rooms to the skyscrapers, and traffic lights: a night-time city mood (photo reference).
  - The rain reflections must be screen-space-reflection style, showing cars driving over, street lamps and road signs.
- **Stage order:** `Track.STAGE_AREAS` lists stages 1–10 (supersedes D-216's cycle); past the finish the last area goes on.
  - The guaranteed tunnel (D-132) moves to the second half of `TUNNEL_STAGE` 3 (the forest), since stage 2 is now beach.
- **Time of day:** `sky.gd` `PROGRESS_HOURS`: day through stage 3, sun low at 4, set by 6, first light at the start of 9 (04:54), sunrise in 9, morning in 10.
  - The night music now plays for 3 stages, and the CodeManu songs start at stage 9.
- **City at night:**
  - **Facades:** darker by day, and 60 % darker at night, so only the rooms glow.
  - **Rooms:** 62 % of windows lit, in warm tungsten, cool office white or TV blue. Each is brighter towards its ceiling, and 30 % have blinds. The glass towers light whole floors in runs of four bays. Shopfronts are almost all lit.
  - **Brightness:** emission at 2.4 so the bloom picks them up; a dim scattering stays on by day.
- **Traffic lights:** the lamps are emissive (5× when on), with an additive glow halo of 1.6 m that is stronger at night.
- **Street lamps:** every lamp's night glow gains a starburst (4 thin rays out of the head).
- **Rain reflections** (`puddles.gdshader`): replace the D-217 horizon mirror with a ray march.
  - **March:** the view ray is reflected off the water, whose normal is tilted a little by the raindrop rings. It is marched in view space, 24 steps growing ×1.32 from 0.25 m, against the depth buffer: a hit is a point just behind the visible surface. Each hit is refined with 5 bisection steps, then the screen is sampled there, fading out towards the screen edges.
  - **Fallback:** a miss uses the mirrored sky.
  - **Both renderers:** depth is linearised with `CURRENT_RENDERER`, Compatibility (web) or Forward+. Which way up the screen is gets found per pixel from the fragment's own projection.
  - **Result:** cars driving over the puddles, lamps, signs and lit windows reflect in place, in HD and in the pixel modes.
  - **Puddles:** slightly larger.
- **Tests:** updated for the new area order, the tunnel in stage 3, night on 6–8 with dawn on 9–10, and the rock-flip test's search (the beach has no rocks).
- **Status:** Accepted

### D-226 — Turbo Run music: five Bogart VGM songs, one per two stages, crossfaded
- **Date:** 2026-11-23
- **Decision (director):** use all five Bogart VGM songs (CC BY 3.0), one for every two stages, crossfading between them, and stop using the others. Most of them start very quietly, so the crossfade goes 5–10 s into the next song, except at the start of the race.
- **New songs:** "Chillwave Nightdrive", "Retroracing One More Round" and "Retroracing Nightlife" (the director's MP3s), converted to OGG Vorbis q5 with ffmpeg.
- **Order** (`MUSIC_RACE`, picked by mood):
  - 1–2 Maximum Overdrive (also attract, carried on into the race);
  - 3–4 One More Round;
  - 5–6 Nightlife (sunset into the night city);
  - 7–8 Dreamstate;
  - 9–10 Chillwave Nightdrive (dawn, the finish).
  - Past the finish, the last one goes on.
- **Crossfade:** `Audio.crossfade_music(path, seconds, from)` overlaps two music players. The new song starts `from` s in and rises over `seconds` while the old one falls and stops (the old `play_music` faded out, then in). At each new pair of stages the next song comes in `MUSIC_SKIP` 7 s in, over `MUSIC_XFADE` 6 s. The race start plays its stage's song from the top: stage 1 carries on attract's song, and a later test start stage plays its own.
- **Retired:** the CodeManu "8-bit Music Pack" loops are removed from the project, along with their DMD credit; the attract DMD credits Bogart VGM. Supersedes the music parts of D-093, D-105, D-106, D-111, D-129 and D-191.
- **Status:** Accepted

### D-227 — Turbo Run music: crossfades without quiet gaps
- **Date:** 2026-11-23
- **Bug (director):** the change from song 1 to song 2 had 1–2 s of silence. Skip further into the next song, and keep crossfades away from quiet parts.
- **Cause:**
  - D-226's fixed 7 s skip landed inside "One More Round"'s quiet build-up, which only reaches full strength at about 17 s.
  - The crossfade was a linear tween in dB, so both songs sat around −20 dB at its midpoint.
- **Per-song start** (`MUSIC_SKIP`, measured with ffmpeg as RMS per 0.25 s against each song's typical level): Maximum Overdrive 0.5 s, One More Round 16.5 s, Nightlife 5.5 s, Dreamstate 31 s (it swells at 34 s), Chillwave Nightdrive 1 s.
- **Crossfade shape** (`Audio.crossfade_music`):
  - The new song starts at −30 dB and reaches full volume in 2.5 s (sine ease-out).
  - The old song holds full volume for 1.5 s, then falls to −60 dB over the rest of the 6 s (quadratic ease-in).
  - An offline render of the 1→2 change with these curves stays at −11 to −14 dB throughout.
- **Status:** Accepted

### D-228 — Turbo Run city: building windows no longer flicker
- **Date:** 2026-11-23
- **Bug (director):** the city buildings' textures flickered (speckled noise inside the windows and shopfronts).
- **Cause:** `building.gdshader` passed each building's seed and size through ordinary interpolated varyings. They arrived with tiny per-pixel differences, and the `sin()`-based hash, fed large arguments (about 40,000), turned those into random per-pixel values that changed from frame to frame.
- **Fix:** the per-building varyings (`cust`, `bsize`) are `flat`, and the hash is a sin-free one (Dave Hoskins' hash12), stable on every GPU. Windows, rooms, blinds and shopfronts are now solid and steady.
- **Status:** Accepted

### D-229 — Turbo Run: a small town at the finish, with spectators
- **Date:** 2026-11-23
- **Decision (director):** add a small town right before the finish line, with groups of people (sprites) on both sides watching the end of the race.
- **Town:** `Track.in_town(s)` covers `TOWN_BEFORE` 600 m before the finish to `TOWN_AFTER` 120 m after. `Track.FINISH_STAGE` is now the one source of the finish stage (`Sim.FINISH_STAGE` takes it).
  - **Road:** flat-ish through the town.
  - **Houses:** in place of the mountain's scattered trees, houses (`chalet`: two alpine chalets and a town house) stand 9–13 m past the kerb on both sides, more than half the time every 9 m.
  - **Lamps:** street lamps every 30 m.
  - **Left out:** no bushes, speed cameras, signs or gantries.
- **Spectators:** `crowd` groups stand 1.8–3.2 m past the kerb on both sides, every 9 m, with a second row (4–6 m out) 60 % of the time. They run from `CROWD_BEFORE` 260 m before the line to `CROWD_AFTER` 40 m after. They have no collision radius: the gap from the kerb keeps them clear, and the car scraping past doesn't hit them.
- **Art:** 6 sprites from Qwen-Image 2.1 in the D-196 painted style (two candidates each, one picked):
  - houses: a wooden chalet, a white alpine house, a pastel town house;
  - crowds: five cheering in colourful jackets, four fans with a chequered flag, a family with a child on a parent's shoulders.
- **Status:** Accepted

### D-230 — Turbo Run: REV! hand 25 % smaller; police lights stay on until the fine
- **Date:** 2026-11-23
- **Decisions (director):** make the REV! hand 25 % smaller. The police car should keep its lights on all the way until you're fined, then turn them off before it moves away.
- **Hand:** redrawn at 59×35 px (`gen_rev_hand.py` `PIX` 9.33, fractional now; was 79×47) and still shown at 2×, so exactly 75 % of D-209's size. The REV! label moves down to stay with it.
- **Police:**
  - The fine (`Sim._fine`, event `busted`) now comes once the police car has parked beside you (`PARK_HOLD`), not as the bust starts. The bust's start is the new event `bust_start`.
  - `police_lights()` is on while chasing and through the bust until the fine, then off.
  - The car sits dark for `LIGHTS_OFF_WAIT` 1 s, and the player is held until it starts to leave.
- **Test:** the lights stay on until the fine and go off before the car leaves.
- **Status:** Accepted

### D-231 — Turbo Run: half the slide when stopping at TIME UP or the finish
- **Date:** 2026-11-23
- **Decision (director):** when stopping at time out or the finish line, the drift distance should be half.
- **Change:** stopping distance is v²/2a, so the deceleration doubles: `COAST_OVER` 7 → 14 m/s² (TIME UP), `FINISH_DECEL` 15 → 30 m/s² (finish drift-brake).
- **Effect:** at 40 m/s the TIME UP slide is about 57 m (was about 114 m), and the finish slide about 27 m. Reaching a checkpoint on momentum after TIME UP (D-103) is correspondingly rarer.
- **Status:** Accepted

### D-232 — Dot-matrix lettering for the on-screen UI
- **Date:** 2026-11-23
- **Decision (director):** replace all the text in the simple retro font (PinPixel) with DMD-style lettering made of dots: single lines of dots, and a heavier density of dots for bigger text (reference: a red DMD with BOGEY MAN / SMASH WINDOWS). Asked: this applies to the on-screen UI text, not the DMD itself.
- **`core/ui/dot_text.gd`:** builds bitmap `FontFile`s at run time from the DMD's 5×7 dot font (`core/dmd/dot_font.gd`), cached per size. No font asset and no licence.
  - **Size:** the cap height is 72 % of the font size, and a glyph bit is `floor(cap / 7)` pixels. That is rounded down so text is never wider than PinPixel was, and layouts still fit.
  - **Small text:** one round dot per bit, so strokes are single lines of dots.
  - **From size 60:** 2×2 smaller dots per bit (heavier density).
  - **Outline:** each dot has a dark rim baked in. The label's font colour tints the dots and leaves the rim dark, so text reads over bright scenes (it replaces the outline).
  - **Characters:** lower case shows as capitals, accented letters fold to their base letter, and anything missing falls back to PinPixel.
  - **Low resolution:** `font(size, px)` also makes fonts for low-resolution canvases (`px` target pixels per base pixel), used by D-233.
- **`UI.label`:** uses it, so the shell, Tilt Breaker and Turbo Run UI text all change. Styled title fonts (D-062, D-186) and 3D `Label3D` world text (gate banners, Tilt Breaker's capsule letters) are unchanged.
- **Status:** Accepted

### D-233 — Turbo Run: the UI follows the graphics mode (low-resolution UI in 8-BIT/16-BIT)
- **Date:** 2026-11-23
- **Decision (director):** all UI should be affected by the HD/retro setting, with lower-resolution UI elements that are clean and legible. Asked: in 8-BIT and 16-BIT the HUD and menus are drawn at the game's low resolution, with fonts made for it.
- **UI layer:** all of Turbo Run's UI (HUD, gauges, banners, attract, GRAPHICS, START STAGE, the showroom, results, centre messages) now draws into `_ui_vp`. It is a transparent SubViewport laid out in TABLE base coordinates (1080×1920 via `size_2d_override`), shown over the 3D view. The police screen wash stays on the TABLE (additive) under it.
- **Resolution** (`_set_ui_res`, on every graphics change):
  - HD: full resolution, linear filtering.
  - 16-BIT: 480×854; 8-BIT: 270×480. Both use nearest upscaling and snapping to the pixel grid, so gauges, icons and text are real low-resolution pixel art, like the 3D view.
- **Fonts:** every dot-font label (`dot_size`, D-232) is rebuilt for the layer's resolution (`DotText.font(size, px)`), including labels created later.
  - At 1–2 target pixels per bit: crisp square pixels with a 1 px dark outline.
  - With more room: hard-edged dots.
  - Where even one pixel per bit would make the 5×7 oversized (cap under 6.3 target pixels: most 8-BIT labels), a new 3×5 pixel font (`DotText.MICRO`) is used, so the gauge numbers fit.
- **Status:** Accepted

### D-234 — Turbo Run: the race ends inside the village
- **Date:** 2026-11-23
- **Bug (director):** the race should finish inside the village, with buildings and people on both sides. The car drift-braked past it into an empty area.
- **Fix:** the finish town (D-229) now goes on `TOWN_AFTER` 700 m past the line (was 120), and the spectators line the run-out for `CROWD_AFTER` 160 m (was 40). So the car stops, and the view ahead stays, among houses and people.
- **Also:** the results screen removes the FINISH! centre banner when its own FINISH! title appears (both were showing).
- **Status:** Accepted

### D-235 — Turbo Run: attract mode is music only
- **Date:** 2026-11-23
- **Decision (director):** only music during the racing game's attract mode; no game sound effects.
- **Change:** while the attract demo drives (attract, and the GRAPHICS and START STAGE menus over it), the engine, wind, skid, traffic, siren and horn loops are held at −80 dB. They fade in from there when the race starts. Menu feedback sounds (choosing, confirming) still play.
- **Status:** Accepted

### D-236 — Turbo Run car select: no engine sound; magna buttons repaint the car
- **Date:** 2026-11-23
- **Decisions (director):** don't play the engine sound on the car select screen. The magna buttons on the select screen swap car colours.
- **Sound:** the car select screen joins attract, GRAPHICS and START STAGE in muting the demo's loops (D-235).
- **Paint:**
  - On car select, magna_l / magna_r step the highlighted car back and forth through `PAINTS`: 8 hue tints on top of the car's own paint (`CARS` hue), where 0 means as it comes.
  - The showroom car repaints at once (`Showroom.set_hue`), and the race uses the chosen paint (`_car_hue`).
  - Choices are kept for the session (static), not saved.
  - The hint reads FLIPPERS: CHOOSE  MAGNA: COLOUR  LAUNCH: GO.
  - As anywhere, pressing a magna turns on the 4-button controls (D-189).
- **Status:** Accepted

### D-237 — Desktop crash at 2× render scale: Mirillis Action, not D-236
- **Date:** 2026-11-23
- **Report (director):** Turbo Run crashed on desktop on the loading screen or at car select, and it seemed to start with D-236 (car colours).
- **Findings:**
  - A native segfault with no script error (the logs stop after "started game 'racer'").
  - Reproduced only at render scale 2× (the director's "auto" on a large monitor), which dev runs force to 1×.
  - D-236 was reverted for testing (`ab5ce6b`), then re-added (`ae16447`).
- **Cause:** the director identified Mirillis Action (screen capture, injects into Vulkan apps) running at the time. After re-adding D-236, repeated 2× runs to car select completed.
- **Note:** dev test runs use the Dummy audio driver and render scale 1.0. Run a check with `PINGAMES_DEV_SOUND=1` and `--display.render_scale=2.0` when a desktop-only problem is reported.
- **Status:** Accepted

### D-238 — Animated loading screens (TABLE and DMD)
- **Date:** 2026-11-23
- **Decision (director):** make the loading screens more attractive: a game-related animation on the DMD and a small animation on the TABLE, like PS2-era games.
- **TABLE** (`shell/loading_anim.gd`, a Control drawn with 2D shapes, so no assets are needed before loading): the game's logo at the top, a small looping scene, then LOADING.
  - **Turbo Run:** a retro side-view car in the game's accent colour drives a scrolling dusk road (dashes, kerbs, speed lines), bobbing, with spinning wheels and exhaust puffs. Progress is a track line with a mini car running to a chequered flag.
  - **Tilt Breaker:** in a framed arena, a plasma ball with a trail bounces off a paddle that follows it. The row of bricks empties as loading goes on, and a progress bar sits below.
  - **Other games:** a bouncing pinball and a bar.
- **DMD:** `LoadingAnim.dmd_anim(id)`, played with `Dmd.play` and stopped (new `Dmd.stop_anim`) when the game starts.
  - **Turbo Run:** a dot car drives across a dotted road under a blinking LOADING.
  - **Tilt Breaker:** a dot ball bounces between a row of coloured bricks, which disappear in turn, and a paddle.
- **Smoothness:** the loader now yields a frame every ~50 ms (was 100 ms), so the animations move smoothly. The old cyan bar is hidden.
- **Dev:** `--loading-hold=N` keeps the loading screen up N s, for screenshots.
- **Status:** Accepted

### D-239 — Turbo Run: cars sway apart after a side impact
- **Date:** 2026-11-23
- **Decision (director):** when bumping other cars (the police car and others) from the side, the cars should sway away from each other after the impact, turning a little.
- **Change:** a side contact now also gives both cars a yaw kick of `SWAY` 0.3 rad (about 17°), easing back at `SWAY_BACK` 0.8 rad/s (about 0.4 s). Each car's nose turns towards the side it was pushed: away from the other car, with oncoming cars accounted for.
  - **Side-swipes with traffic** (D-152): the player (`Sim.sway`) and the other car (`t.sway`).
  - **The police ramming you:** you turn the full amount, the police car 70 %.
  - **You hitting the police:** the police car turns the full amount, you 70 %.
- **View:** each car's drawn heading adds its sway (before the sprite-angle stepping, D-092/D-208).
- **Test:** a side-swipe turns both cars away from each other.
- **Status:** Accepted

### D-240 — Turbo Run loading: the driver walks to the red car (DMD graphics)
- **Date:** 2026-11-23
- **Decision (director):** the game's loading screen should show a guy walking towards the red car from the backglass, in DMD graphics.
- **Scene** (`LoadingAnim.racer_scene`): dot sprites on a 128×32 grid, looping every 6.5 s.
  1. The driver (a 5×9 sprite with two walk frames and a bob: dark hair, white jacket, blue jeans) walks in from the left to the red sports car.
  2. The door swings open, and he's in.
  3. The headlights and tail lights come on, with a beam.
  4. The car pulls away to the right, faster and faster, puffing exhaust.
- **DMD:** the scene with LOADING at the top left (replaces D-238's racer DMD animation).
- **TABLE:** the same scene as a big dot-matrix panel (128×32 dots at 7 px, unlit dots shown), between the logo and the track-to-flag progress bar (replaces D-238's road scene, which is kept in the code as `_draw_racer_road`).
- **Status:** Accepted

### D-241 — Turbo Run loading: the director's yellow car
- **Date:** 2026-11-23
- **Decision (director):** the guy walks to this car (the director's yellow supercar picture), DMD LED-styled.
- **Sprite:** `scripts/tools/gen_loading_car.py` turns the picture into a 46×14 dot sprite (`loading_car_dmd.png`). It masks the white background and the grey ground shadow, area-averages to 46 dots and brightens a little for LEDs.
- **Scene:** `racer_scene` draws the sprite dot by dot (replacing D-240's boxy red car). The lights come on at the nose and tail with a beam, the door opens about 20 dots in, and the puffs come from the back.
- **Status:** Accepted

### D-242 — Turbo Run loading: the driver to scale with the car
- **Date:** 2026-11-23
- **Decision (director):** the car was huge next to the person. Supercars are lower than a person, so make the car smaller or the person taller.
- **Change:** the driver is redrawn at 9×19 dots (was 5×9). A person is about 1.8 m and a supercar about 1.25 m, and the car is 14 dots tall. He has two walk frames (legs apart with arms swinging, then passing), his feet are on the kerb line, and he walks to the door.
- **Status:** Accepted

### D-243 — Turbo Run DMD animations draw the player's own car
- **Date:** 2026-11-23
- **Decision (director):** the cars in the DMD animations (police chases, crashes, etc.) should look like the player cars (the director's yellow supercar and red sports car pictures).
- **Sprites:** `gen_loading_car.py` now takes `src out width [--flip]`. The yellow supercar becomes a 22×7 dot sprite (`dmd_car_supercar.png`); 16 dots was too few to read.
- **Animations:** `DmdAnims.player_sprite`, set by the game at race start for the chosen car (`DMD_SPRITES`, by model), is drawn by `_player()`. It stands on the same ground row and is centred where the 13×5 dot car was. It's used in near miss, nitro, the crash approach, upright and upside-down crash poses, and the police fine; the police car stops a little further on, clear of it. The police car and other traffic keep their dot patterns.
- **Pending:** the red sports car picture (for Normal and Easy) didn't reach disk. Until the director saves it, those cars keep the 13×5 dot car. Adding it is one `DMD_SPRITES` line plus the converter (with `--flip`, since it faces left).
- **Status:** Accepted

### D-244 — Turbo Run DMD: the red sports car sprite, in each car's paint
- **Date:** 2026-11-23
- **Decision (director):** the red sports car picture for the DMD animations (completing D-243).
- **Sprite:** converted with `gen_loading_car.py ... 22 --flip` (it faces left) to `dmd_car_sports.png`, 22×7. It's used for Normal (the sports car) and Easy (the hot hatch, which has no side picture yet).
- **Paint:** the chosen car's sprite takes its in-game paint (`_painted`). Saturated dots get the same hue turn as the 3D car (`_car_hue`: the car's hue plus the paint picked on car select), while windows and tyres stay. So Normal shows green, Hard yellow, Easy red, or whatever was picked.
- **Status:** Accepted

### D-245 — Turbo Run DMD: the police distance indicator and BUSTED use car sprites
- **Date:** 2026-11-23
- **Decision (director):** the police distance indicator still used cars that don't look like the in-game cars, and the busted animation's police car didn't match the style of the rest.
- **Police sprite:** the police car's 3D model is rendered side-on in Blender with a transparent background (`scripts/tools/render_car_side.py`, orthographic, sun plus white world). It's converted to 22×7 by `gen_loading_car.py`, which now:
  - uses a picture's own transparency when it has one, so the car's white panels aren't taken for background;
  - takes `--contrast`, which snaps grey dots to a black-and-white livery (white, or a charcoal that stays visible on the black DMD).
- **Drawing:** `DmdAnims._police()` draws it like the player's sprite, with a 2-dot red and blue light bar flashing on its roof.
- **Chase indicator** (D-162): the player's own painted sprite (D-243/244) on the right, the police sprite behind at a gap that follows the real distance (up to 150 m), and speed lines behind it.
- **BUSTED:** the police car that rolls in is the sprite (it was a 13×5 dot pattern).
- **Status:** Accepted

### D-246 — Turbo Run: police wheels turn; DMD police sprite has wheels
- **Date:** 2026-11-23
- **Bugs (director):** the cop car's wheels don't turn (very noticeable), and the DMD cop car sprite has no wheels.
- **3D wheels:** the D-143 spin effect (spoke streaks blurring into a disc) needs each model's axle height, axle distance and wheel radius. Those were shader defaults sized for the red car, and the police car never had `spin` on.
  - **Measurements** (`measure_racer_car.gd`), now in `LAMP_BOXES`:
    - police: 0.38 m up, axles at 1.35 and 1.45 m (the shader takes one, 1.40), radius 0.36;
    - supercar: 0.36 / 1.29 / 0.35;
    - hot hatch: 0.37 / 1.30 / 0.35. D-205 had removed the hot hatch's values as unused, but they are these uniforms, so the player's hot hatch and supercar wheels now spin on their real axles too.
  - **Police spin:** the police car's own wheel phase follows its speed, stepped like the player's (D-208), with the same blur.
- **DMD sprite:** the converter's ground-shadow filter had removed the grey tyres from the transparent render, so it is skipped for pictures with their own transparency. A new `--wheels` option draws each run of tyre dots in light grey with a bright hub dot above its centre.
- **Dev:** `--rc-police` calls a police car right after GO (`Sim.call_police`).
- **Status:** Accepted

### D-247 — EXIT during a game's loading screen no longer leaves the TABLE stuck
- **Date:** 2026-11-23
- **Bug (director):** pressing EXIT while a game's loading screen was up left the TABLE on the loading screen, while the DMD showed the game start and the main menu come back.
- **Cause:** `GameMode._exit_tree` overrode the base mode's without calling it, so what the mode had put on the TABLE (the loading overlay) was never freed. EXIT during the warm-up just after loading (D-178) aborted the game mid-warm-up, before its own `queue_free` of the overlay.
- **Fix:**
  - `GameMode._exit_tree` calls `super`, so the overlay goes.
  - The DMD loading animation stops if the mode is left mid-load.
  - EXIT during the loading itself now goes back to the menu straight away (it used to be ignored until the game had started).
- **Status:** Accepted

### D-248 — Turbo Run: the police car's wheels visibly turn at speed
- **Date:** 2026-11-23
- **Bug (director):** the cop car's wheels look static while it drives next to you to ram you.
- **Cause:** at speed the D-143 effect blurs the spokes into a flat grey disc (`wheel_blur` 1 above ~26 m/s). From behind, on the player's car, that reads as speed; side-on, next to you, it reads as still.
- **Fix:** for the police car, the spoke pattern's turning is capped at `POLICE_WHEEL_MAX` 30 rad/s of phase (about one visible turn a second with 5 spokes, like film of a fast wheel), and the blur goes to 45 % at most. The spokes keep visibly spinning.
- **Status:** Accepted

### D-249 — Turbo Run: the wheels really turn
- **Date:** 2026-11-23
- **Bug (director):** the turning wheels looked like a faint texture over or under the wheel, not like wheels moving.
- **Cause:** D-143's effect painted spoke streaks (blurring to a grey disc) over the wheel texture in the fragment shader, so the model's own rims never moved.
- **Fix:** `car.gdshader`'s vertex stage rotates the wheels themselves. Every vertex inside a wheel's cylinder (|x| above `wheel_x` 0.66, within `wheel_r` of its axle, using the per-model axle data from D-246) turns about the axle by `wheel_phase`, normals too. The model's rims and tyres spin, texture and all. The painted streaks are removed.
- **Rate:** the turning is capped at `WHEEL_MAX` 25 rad/s, about 4 turns a second and under half a spoke per frame at 60 fps. Faster would strobe, so the wheels are always seen turning forwards. This applies to the player's car and the police car (replacing D-248's cap).
- **Dev:** `--rc-wheeltest` spins the wheels on the car-select turntables, to check them side-on.
- **Status:** Accepted

### D-250 — Turbo Run: turning rim pictures at each car's measured wheel centres (all cars and trucks)
- **Date:** 2026-11-23
- **Bug (director):** the turning wheels did weird things, as if not centred. Use a wheel texture from the side pictures of the cars; the fix is needed for all cars, and trucks.
- **Cause:** D-249 rotated mesh vertices about one shared axle setting per model. The real wheels sit at different places front and rear (the police car's are 1.29 and 1.38 m from the centre), and the cylinder caught non-wheel geometry, so wheels wobbled off-centre.
- **Fix:**
  - **Measured centres:** each model is rendered side-on (`render_car_side.py`), and every wheel's rim centre and radius is measured per axle from the bright rim. The cars were checked against overlays, and the trucks found as separate rim blobs, with the false hits (a fuel tank and two body panels) dropped. They're stored in `WHEELS` as up to 6 wheels per model.
  - **Rim pictures** (`gen_rims.py`):
    - from the director's pictures: the yellow car's 9-spoke (supercar, hot hatch), the red car's 5-spoke (sports car, traffic hatchback) and the director's wheel picture (police car);
    - for each truck, its own rim cropped from its render.
  - **Shader:** `car.gdshader` draws the rim picture over each wheel's rim circle on the outward-facing sides, turned by `wheel_phase`. The model's own tyre, wheel arch and body stay untouched. The D-249 vertex rotation is removed, along with the old axle uniforms.
  - **Who turns:** the player's car, the police car (D-246/248 rate) and now every traffic car and truck, each at its own speed (capped by `WHEEL_MAX`).
- **Status:** Accepted

### D-251 — Single-screen version (Android and PC), slice 1: layout
- **Date:** 2026-11-23
- **Decision (director):** a version for Android and PC on one screen (the TABLE, with the DMD at the top of the game area), gamepad support with analog controls, and an Android touch overlay.
- **Director's answers:**
  - Same codebase, as a new layout mode.
  - No backglass.
  - **Portrait:** the DMD side to side (no black bars), the game filling the rest, touch controls at the bottom.
  - **Landscape:** the game fills the monitor, the DMD centred at the top at about 50 % of a 16:9 screen, and the TABLE UI (timer, radar...) at the sides. On 32:9 screens the game fills the monitor but the UI stays within 16:9.
  - **Racer analog:** stick steers, R2 gas, L2 brake.
  - **Touch:** translucent buttons over the game.
- **Slices:**
  1. the layout (this entry);
  2. the game area taking the screen's shape (Turbo Run landscape-native, HUD at the sides);
  3. analog gamepad;
  4. the touch overlay finished.
- **Slice 1:**
  - **Layout:** `Screens` layout `single`. Android uses it; PC chooses SINGLE SCREEN in the operator menu (LAYOUT), or `--single-preview` (with `--single-portrait` for a tall window).
  - **Portrait:** the DMD across the full width (128:32), the TABLE in the rest.
  - **Landscape:** the DMD centred at the top at half of a 16:9 width, the TABLE in the rest.
  - **Fit:** the TABLE keeps its 9:16 shape for now, so it's fitted until slice 2.
  - **Touch:** the touch buttons are a translucent bar along the bottom of the screen over the game (`TouchControls.overlay`). They're hidden while a gamepad is connected, and the layout rebuilds when one is plugged in or out.
  - **Web:** the browser build keeps its `web` layout (D-173).
- **Status:** Accepted (slice 1 of 4)

### D-252 — Single-screen version, slice 3: analog gamepad
- **Date:** 2026-11-23
- **Decision (director):** gamepad analog controls. Racer: the stick steers, the triggers are gas and brake.
- **Input:** `CabinetInput.steer_axis()` reads the left stick's X from any connected pad (deadzone 0.18, rescaled). `trigger(left/right)` reads L2 and R2 (0..1).
- **Turbo Run:**
  - **Steering:** the stick steers proportionally (`Sim.steer_axis`; the flippers still work when the stick is centred).
  - **Brake:** L2 brakes.
  - **Accelerator:** once R2 is used in a race, it's a proportional accelerator (`gas_axis`; released, the car coasts). Until then the throttle stays automatic as before.
  - **Controls mode:** using a trigger switches to the 4-button controls (own brake and shifter, D-189), like a magna press.
- **Tilt Breaker:** the paddle follows the stick's tilt proportionally (`Sim.paddle_axis`).
- **Unchanged:** all buttons (L1/R1 flippers, Cross, Circle, Square) stay as mapped (D-019).
- **Test:** half stick steers less than full stick.
- **Status:** Accepted (slice 3 of 4)

### D-253 — Turbo Run: shadows for the cars and scenery
- **Date:** 2026-11-23
- **Decision (director):** add shadows for the cars and the scenery.
- **Sun shadows:** the sun (and the moon at night, which is the same light) casts shadows: `shadow_enabled`, 2 PSSM splits over `SHADOW_DISTANCE` 140 m, soft blur, bias tuned against acne on the road.
  - **Casters:** the 3D models, meaning the player's car, police, traffic, trucks, the city's buildings (`city.gd` now casts), lamps, rocks, gantries and gates.
  - **Receivers:** the road and ground; the car shader takes shadow through its own `light()` (ATTENUATION).
  - **Strength:** `shadow_opacity` follows the light: full by day (`SHADOW_STRENGTH` 0.75), a quarter by moonlight, none in tunnels, and weaker in rain, snow and fog.
- **Blob shadows:** flat sprite props (trees, palms, bushes, houses, spectators, signs) don't cast real shadows, since billboards would throw shadows that spin with the camera. Each gets a soft dark disc flat on the ground under it instead (`_add_blobs`), sized from its height (0.8–7 m across), one MultiMesh per kind per chunk. Its darkness follows the same light. Distant buttes get none.
- **Status:** Accepted

### D-254 — Single-screen version, slice 2: Turbo Run fills the screen
- **Date:** 2026-11-23
- **Decision (director):** the game area fills the screen.
  - **Portrait:** the DMD across the top, the game in the rest, no black bars.
  - **Landscape:** the game fills the monitor, the DMD centred at the top, the HUD (timer, radar...) at the sides.
  - **32:9:** the game fills the monitor but the UI stays within 16:9.
- **Flexible TABLE** (`Screens.set_flexible`):
  - In the single layout, a game that asks (Turbo Run) gets a TABLE in the exact shape of its area. Portrait: base 1080 wide, below the DMD. Landscape: base 1080 high, the whole window, with the DMD over its top centre. It renders at the area's own pixels (at most 2× base).
  - `table_shape_changed` tells the game. The TABLE's view redraws at the new shape (it only redrew on its own resize).
  - Only the module that asked releases it (a copy made just for `get_info` used to turn it off).
  - The shell and Tilt Breaker keep the 9:16 TABLE.
- **Turbo Run:**
  - **3D view:** renders at the TABLE's shape. HD is native; 16-BIT and 8-BIT keep 480 and 270 pixels on the short side. In landscape the camera keeps its vertical field of view, so wider screens show more to the sides.
  - **UI layer** (`_ui_base`), shown centred with its aspect kept:
    - portrait: the whole TABLE;
    - landscape: a 1920×1080 area, so at most 16:9 and centred on 21:9 and 32:9;
    - car select in landscape: a 1080×1920 panel, since its art is portrait.
  - **Landscape HUD** (`_hud_layout`):
    - the clock moves under the score, left-aligned on the left;
    - stage and buttons stay right-aligned on the right;
    - the tacho goes bottom left, gear and speedo bottom right;
    - the radar lights spread out to the sides, leaving the DMD's spot (the centre 1,040 px) clear.
- **Status:** Accepted (slice 2 of 4)

### D-255 — Single screen: every screen uses the screen's shape; smaller DMD in landscape
- **Date:** 2026-11-23
- **Bug (director):** the game still rendered with vertical intent: the menu and car select were vertical strips. Also, the DMD was too big and should be 50 % of its size.
- **Default:** in the single layout the TABLE takes its area's shape by default (D-254). Tilt Breaker, whose playfield is portrait, asks for 9:16 (`Screens.want_portrait_table`) and gives it back on exit. Turbo Run applies its layout at start, since the shape may already be landscape when it begins.
- **Shell:**
  - **Picker and attract title page:** they lay themselves out for any shape (`portrait_only = false`). In landscape the game logos sit side by side, spacing is tighter, the title is smaller and the content starts below the DMD (`Screens.dmd_cover()`). The picker rebuilds itself if the shape changes.
  - **Other modes** (operator menu, initials, the loading screen): built for 1080×1920, so `Mode.add_table` puts their nodes in a 1080×1920 frame, scaled to fit and centred.
- **Car select (landscape):** the showroom renders landscape. The three turntables sit side by side, each stats card under its car, and the title below the DMD. It's in the 16:9 UI area.
- **DMD (landscape):** a quarter of a 16:9 width, half its D-251 size. Portrait keeps it across the full width, as specified.
- **Status:** Accepted

### D-256 — Single screen: gamepad mapping
- **Date:** 2026-11-23
- **Decision (director):** for the one-screen PC landscape version, connect the gamepad properly:
  - D-pad and left stick move in menus and car select, X (Cross) accepts, Circle goes back;
  - in the race the left stick steers, R2 accelerates, L1 brakes. The request also put gear shifts on R2, which clashes with the accelerator; taken as **R1 shifts**.
- **Mapping:** with the layout `single`, `CabinetInput.SINGLE_PAD` replaces the pad bindings (keyboard keys stay):

  | Action | Pad input |
  |---|---|
  | flip_l / flip_r (menu moves; steering as buttons) | D-pad left/right (13/14) and left stick X (axis 0 −/+, past 0.5) |
  | launch (accept) | Cross (0) |
  | exit (back, quit confirm) | Circle (1) |
  | start | Start/Options (6) |
  | magna_l (brake; colour on car select) | L1 (9) |
  | magna_r (gear shift; colour on car select) | R1 (10) |
  | (nothing) | R2: no longer magna_r; it's the analog accelerator (D-252) |

- **Race:** the stick's analog steering (D-252) overrides the flipper actions it also drives. Using L1, R1 or R2 switches to the 4-button controls (own brake and shifter, D-189).
- **Cabinet layouts:** unchanged (D-019).
- **Status:** Accepted

### D-257 — Single screen gamepad: Start quits
- **Date:** 2026-11-23
- **Bug (director):** there was no way to quit the game; it should be Start.
- **Change:** in `SINGLE_PAD` the Start/Options button (6) is now on EXIT, alongside Circle.
  - In a game it quits to the menu.
  - On the menu it asks to quit the app (Cross confirms).
  - Held, it opens the operator menu, as EXIT does.
- **START action:** no pad button now. Cross plays from the menu, so nothing needs it.
- **Status:** Accepted

### D-258 — R2 revs the engine on the grid
- **Date:** 2026-11-23
- **Bug (director):** R2 didn't rev the car at the start (the D-pad did). With all the buttons available, the accelerator should rev.
- **Fix:** in the countdown, the accelerator (`gas_axis`, R2 once pressed, D-252) revs the engine in proportion: the revs rise to the trigger's position and fall when it's let off. So the needle can be held in the perfect-start window with the trigger (D-118). The flippers or D-pad still rev fully, as before.
- **Test:** 60 % R2 holds the needle near 0.6 on the grid.
- **Status:** Accepted

### D-259 — The loading screen stays 2 s after loading
- **Date:** 2026-11-23
- **Bug (director):** after a game loaded, two cars appeared in the air for a second. Delay showing the game by 2 seconds before changing from the loading screen.
- **Cause:** the shader warm-up (D-178) draws copies of the game's objects (cars included) behind the loading screen. The screen and the copies were freed in the same frame, so their last frame could show.
- **Fix:** the copies are freed first, then the loading screen stays `REVEAL_DELAY` 2 s more (with its animation, D-238) before the game shows. Game input waits until it's gone; EXIT still leaves.
- **Status:** Superseded by D-278 (the 2 s; the copies still go first)

### D-260 — Single screen gamepad: Circle is BACK; Start asks before quitting
- **Date:** 2026-11-23
- **Decision (director):** Circle should not be exit, just cancel in menus. To exit the game, press Start to show a confirmation (OK / Cancel), selected with X. Supersedes D-257's Circle-as-exit.
- **New action BACK** (`CabinetInput.ACTIONS`): Circle on the single-screen pad, Escape on the keyboard. It cancels and steps back, never quits:
  - in the operator menu, it steps back like EXIT;
  - on the menu, it cancels the quit-the-app question;
  - in the in-game quit dialog, it cancels.
- **EXIT on the pad:** Start only (`SINGLE_PAD`).
  - **In a game on a single screen:** it pauses the game and shows QUIT GAME? with OK and CANCEL. CANCEL is selected first, so a stray press is safe. The flippers (D-pad, stick) choose, LAUNCH (Cross) picks, and BACK or EXIT again cancels. It covers the whole screen.
  - **Cabinet layouts:** EXIT still leaves straight away.
  - **On the menu:** Start keeps the quit-the-app question (Cross confirms).
- **Status:** Accepted

### D-261 — The loading screen covers the whole screen in landscape
- **Date:** 2026-11-23
- **Bug (director, screenshot):** three seconds after the loading jingle, in landscape on a single screen, the loading screen was a portrait strip in the middle. The warm-up copies of the cars (huge, close to the camera) and the game's attract text showed at the sides.
- **Cause:** the loading overlay went into the mode's 1080×1920 frame (D-255), which in landscape covers only the centre.
- **Fix:** a black backdrop over the whole TABLE, whatever its shape, sits under the loading content, which stays centred. It lasts through the warm-up and the reveal delay (D-259) and is freed with the overlay.
- **Status:** Accepted

### D-262 — Tilt Breaker on 16:9: the DMD on top, the game under it, full width
- **Date:** 2026-11-23
- **Decision (director):** adapt Tilt Breaker for 16:9 screens: the DMD on top, and the game area rendered under it.
- **Screens:** `want_dmd_above(on)` keeps the flexible TABLE (D-255), but in landscape it takes the area under the DMD (full width) instead of the whole window with the DMD over it. `dmd_cover()` is 0 then. Tilt Breaker asks for this, instead of D-255's 9:16 TABLE, and gives it back on exit.
- **Tilt Breaker:** its orthographic camera keeps the playfield's height (16 units), so on a wide area the playfield stays centred at the same size, and the starfield, planet and space fill the sides. The edge shields are invisible, so nothing marks the extra width. Gameplay (the field, 8.2 × 15.1) is unchanged. Its text is centre-anchored, so it fits as it is.
- **Status:** Accepted

### D-263 — Tilt Breaker: the edge shields glow faintly at rest
- **Date:** 2026-11-23
- **Decision (director):** render the side (blue) shields at 5 % even when no ball is hitting them, to make clear what the play area is on 16:9 (D-262).
- **Change:** `shield.gdshader` gains `idle`, a resting glow with the same band, edge and hex texture as a hit. The field's left, right and top edge shields use `EDGE_IDLE` 0.05; hits still flash them fully, then they fade back to the glow. The ship's own shield keeps `idle` 0, so it's unchanged. The glow shows in every layout.
- **Supersedes:** D-049's fully invisible barriers.
- **Status:** Accepted

### D-264 — Tilt Breaker: Cross charges the shot on a gamepad
- **Date:** 2026-11-23
- **Decision (director):** map X (Cross) on the gamepad to the charge shot.
- **Change:** on a single screen, LAUNCH (the pad's Cross, or Space) held during play is the charge shot, exactly like holding both flippers (`Sim.charge_held`).
  - It charges level by level, fires on release and auto-fires at maximum (D-074/D-075).
  - Only a press made while the ball is in play counts, so the press that serves the ball doesn't start charging.
  - The charging particles show for it too.
- **Unchanged:** cabinet layouts keep both flippers as the only way to charge.
- **Test:** the charge button charges the shot.
- **Status:** Accepted

### D-265 — Tilt Breaker landscape: DMD in a left box, backglass in a right box
- **Date:** 2026-11-23
- **Decision (director, marked-up screenshot):** place the DMD in the box on the left, which lets the play area be zoomed bigger, and put the backglass in the box on the right. Supersedes D-262's DMD-on-top for Tilt Breaker.
- **Screens:** `want_side_panels(on)`. In single-screen landscape the TABLE covers the whole window, so Tilt Breaker's camera, which keeps the playfield's height, draws it as tall as the window.
  - **DMD:** at 3.7 % / 27 % of the window, 26 % of its width (4:1).
  - **BACKGLASS:** the game's backglass art and effects, shown at 74 % / 31 %, 24.5 % of the width (16:9).
  - **Turbo Run:** keeps the DMD over its top centre (D-254/255).
  - **Portrait:** unchanged.
- **Status:** Accepted

### D-266 — Tilt Breaker side panels: centred, aligned, framed
- **Date:** 2026-11-23
- **Decision (director):** centre the backglass in the right side and make it 10 % bigger, align its middle with the DMD's middle, and frame the backglass and DMD with the brick texture.
- **Layout** (`Screens._place_single`, side panels):
  - **Spaces:** each panel is centred in the space beside the playfield, which is taken as 9:16 of the window's height, centred.
  - **Sizes:** the DMD is 26 % of the width (at most 86 % of its space). The backglass is 27 % (10 % bigger than D-265's 24.5 %), at 16:9.
  - **Height:** both are centred on the same line, 40 % down the window.
- **Frames:** `want_side_panels(on, frame_tex)` puts a tiled frame (1.8 % of the window height thick) behind each panel. Tilt Breaker passes its bricks' blue circuit texture (`circuit_blue.png`), drawn with hard pixels.
- **Status:** Accepted

### D-267 — Tilt Breaker: side panels clear of the play area; the logo on the start screen
- **Date:** 2026-11-23
- **Bug (director):** the panel frames overlapped the game area.
  - **Cause:** D-266 estimated the play area as 9:16 of the window's height.
  - **Fix:** Tilt Breaker reports its real play area (`Screens.set_play_half_width`): its field's half width plus `PLAY_MARGIN` 0.9 units, over the TABLE's width in its 16-unit-high orthographic view. Each panel, frame included, fits between that edge (plus a 2.5 % gap) and the window edge, shrinking if the space is narrow.
- **Decision (director):** replace the TILT BREAKER text above PRESS START at the start of the game with the game's logo. The attract screen shows `logo.png` (760×520 box, aspect kept) instead of the title in its styled font.
- **Status:** Accepted

### D-268 — PC tester build (Windows zip on a GitHub release)
- **Date:** 2026-11-23
- **Decision (director):** build a PC version in a zip to distribute to testers, upload it to GitHub, then commit, push and merge to main.
- **Build:** the Windows export templates aren't installed (downloading them needs approval), so the build is the game exported as a `.pck` (new export preset "Windows", no template needed) next to the official Godot 4.7.2 runtime, renamed `PinGames.exe`. Godot runs a same-named `.pck` beside it. Also included: `PinGames_console.exe` (the same with a log window), `README.txt` (controls), and `override.cfg`.
- **override.cfg:**
  - `pingames/default_layout = "single"`: the build starts on one screen. `Config` reads that setting, or the export feature `single`, as the layout's default.
  - `application/config/custom_user_dir_name = "PinGamesTester"`: settings and scores go to `%APPDATA%\PinGamesTester`, apart from a development install.
- **Distribution:** `PinGames-tester-2026-11-23.zip` on a GitHub release of the (private) repo, so testers need repo access.
- **Note:** the runtime is the editor binary, so the title bar says (DEBUG). A proper release build would need the export templates.
- **Status:** Accepted

### D-269 — Tilt Breaker: the edge shields' resting glow at 10 %
- **Date:** 2026-11-23
- **Decision (director):** make the barriers 10 % visible instead of 5 % (D-263), and include it in the tester build (D-268).
- **Change:** `EDGE_IDLE` 0.05 → 0.10.
- **Status:** Accepted

### D-270 — Proper Windows release build; the web uses the single-screen layouts; touch overlay check
- **Date:** 2026-11-23
- **Decision (director):** download the export templates as needed. The web version should also use the new layouts. The Android touch overlay seemed not to be added. Leave the Android and Quest APKs out of the workflow for now; build those only on request.
- **Templates:** the official Godot 4.7.2 Windows x86_64 templates (debug and release, from the engine's GitHub release, `version.txt` checked) are installed in `%APPDATA%\Godot\export_templates\4.7.2.stable`.
- **Windows build:** the "Windows" preset exports a release build: `PinGames.exe`, the `.pck` and `PinGames.console.exe`, product name PinGames. The tester zip (D-268) is rebuilt from it, with no "(DEBUG)" title, 233 MB.
- **Web:** the browser build uses the `single` layout (D-251–D-267) instead of D-173's `web` page: the game takes the page's shape, with the DMD on top or in Tilt Breaker's side panel, and the translucent touch overlay on touch screens. The page owns the canvas, so there's no window sizing there.
- **Touch overlay:** it was built in D-251 (translucent buttons along the bottom, over the game: EXIT/BRAKE/LEFT and START/LAUNCH/SHIFT/RIGHT, a HIDE toggle). It's hidden while a gamepad is connected, which is why it never showed in test runs here. `--touch` now forces it on even with a pad connected.
- **APKs:** Android and Quest builds are ad hoc, only when asked.
- **Status:** Accepted

### D-271 — Oncoming traffic avoids a crashed or stopped car
- **Date:** 2026-11-23
- **Bug (director):** after a crash, with the hero stopped, oncoming cars drove through it. They should stop or avoid it.
- **Cause:** collisions are off while the car is crashed or immune (D-125), and oncoming traffic held its lane.
- **Fix:** while the hero is crashed (`spin_t`) or below 4 m/s, an oncoming car up to `DODGE_AHEAD` 170 m ahead whose lane overlaps it swerves round. It moves across (`t.dodge`, at `DODGE_RATE` 4.5 m/s) to the side it's already on, keeping `DODGE_CLEAR` 0.7 m clearance and using the kerb if needed (else the other side), and slows to 60 %. If neither side has room, it brakes to a stop `WAIT_GAP` 5 m short. Once the hero is moving again, it eases back into its lane. Same-direction traffic already waits behind (D-223).
- **Test:** an oncoming car never overlaps a car crashed in its lane.
- **Status:** Accepted

### D-272 — The web app applies new versions by itself
- **Report (director):** Edge on Android still showed the 3-screen web layout with the buttons at the sides, after D-270 was deployed.
- **Cause:** the PWA's service worker (D-176) serves the cached build. A new version installs in the background but only takes over once every tab and the installed app are fully closed. The server had the new build (`no-cache`, new `CACHE_VERSION`).
- **Fix:** on the web, the shell listens for `JavaScriptBridge.pwa_update_available` (and checks `pwa_needs_update()` at start). When a new version is waiting, it calls `pwa_update()`, which activates it and reloads: at once on the menus, or when the player returns to the menu if a game is running.
- **Note:** this code only arrives with the update itself, so getting off the old cached version takes one manual step: fully close the app or tab and reopen it, or clear the site's data.
- **Status:** Accepted

### D-273 — Touch overlay: round buttons, all one size, more visible
- **Date:** 2026-11-23
- **Decision (director):** make the Android buttons round and slightly more visible, all the same size on screen.
- **Shape:** in the overlay (`TouchControls.overlay`, single layout), every button is a circle of one size: four to a column in the bottom bar (42 % of the height in portrait, 60 % in landscape), at most 17 % of the short side, sitting at the bar's bottom. The empty slot on the left keeps the two columns level.
- **Visibility:** idle fill 32 % (was 18 %), border 70 % (was 45 %) and 4 px wide; pressed 55 %.
- **Labels:** sized in the dot font so the longest (6 letters) fits across the circle, and scaled down further on tiny screens.
- **Unchanged:** the side-column style for other layouts.
- **Status:** Accepted

### D-274 — Tilt Breaker: the resting edge glow really at 10 %
- **Date:** 2026-11-23
- **Bug (director):** the walls were more invisible than before; they should have been more visible after going from 5 % to 10 % (D-269).
- **Cause:** with additive blending the shader's light was colour × a × alpha (= a), so the resting glow came out squared: 10 % showed as 1 % (and 5 % as 0.25 %).
- **Fix:** the shader writes its light straight, with alpha 1. A hit keeps exactly its old look (2.5 × a × a), and the resting glow is `idle` (10 %) of the shield colour.
- **Status:** Accepted

### D-275 — Tilt Breaker: the ship enters each level centred; no drop of the power-up you have
- **Date:** 2026-11-23
- **Decisions (director):** the paddle always flies into the horizontal centre of the level, and the power-up you currently have can't spawn again.
- **Ship:** the level-clear outro glided the ship to the centre only in the view, while the sim kept its old position, so the next level's ship rose in where the last one had been. `Sim.next_level` now puts the paddle in the field's centre, standing still.
- **Power-ups:** drops pick from every kind except the active one (`random_powerup_kind`). With none active, all six can drop.
- **Test:** covers both.
- **Status:** Accepted

### D-276 — Bezel on the side-panel frames
- **Date:** 2026-11-23
- **Decision (director):** add a bezel effect to the DMD and backglass frames (D-266).
- **Shader:** `core/ui/bezel_frame.gdshader` draws each frame: the frame texture tiled (a tile is 3× the frame's thickness) and darkened slightly, with a raised bezel.
  - **Outer edge:** a third of the band lit along the top and left, shaded along the bottom and right.
  - **Inner lip:** the reverse, as if the screen sits recessed.
  - **Seam:** dark where the frame meets the screen.
- **Thickness:** the frame is 2.6 % of the window height (was 1.8 %), so the bevel reads.
- **Status:** Accepted

### D-277 — After game over, back to the game's PRESS START
- **Date:** 2026-11-23
- **Decision (director):** on game over, don't go back to the game selection; go back to PRESS START in the game.
- **Change:** `Shell.return_to_game(id)`: after GAME OVER, or after the high-score initials, the shell restarts that game's mode, which opens on its own attract / PRESS START screen. Its assets are already loaded, so there's no loading screen.
- **Credits:** a game's START plays straight away, so the next game's credit is taken here. With no credit left (not free play), it goes to the picker, which shows INSERT COIN.
- **Unchanged:** EXIT during a game still leaves to the picker.
- **Status:** Accepted

### D-278 — Optimisation pass: loading, stutter, Android, transitions
- **Date:** 2026-11-23
- **Decision (director):** optimise the game without sacrificing graphics quality: loading times, stutter from loading while in-game, Android performance, and smooth transitions between menus and game. During the work: the look is retro, so the model textures don't need their fidelity; cars and scenery are flat or cel-shaded (sprites excepted).
- **Measured first** (desktop, windowed dev run, HD): opening Turbo Run took about 11.7 s (4.9 s loading files, 2.6 s building the game, 2.2 s warm-up, 2 s hold) and Tilt Breaker 4.4 s. Every return to PRESS START (D-277) rebuilt the game with no loading screen, a freeze of about 2.5 s in Turbo Run.
- **Causes and fixes:**
  - **Dot-matrix UI fonts** (`core/ui/dot_text.gd`, D-232): each text size was drawn dot by dot, pixel by pixel, in script the first time it was used: up to 0.7 s per size (2.7 s at 2× render scale). This was most of the HUD's build time and a hitch in every menu the first time. Each dot is now drawn once and stamped (`Image.blend_rect`): 50–100× faster. The atlases match the old ones to within 2/255 per channel.
  - **HD car textures:** all textures were imported lossless, including the 8192 px hot hatch albedo and four 4096 px ones (about 500–650 MB of video memory by their sizes, 0.9 s to load for the hot hatch alone). The seven `HD_TEXTURES` are now limited to 2048 px and GPU-compressed at high quality (BPTC on desktop, ASTC on mobile), with mipmaps. Side-by-side HD screenshots of the cars show no visible difference. The 8K texture's import went from 55 MB to 5.6 MB. Pixel-art (16-BIT/8-BIT) textures and all sprites stay lossless, since block compression would show on them.
  - **Loading on worker threads** (`GameMode._preload`): every file is requested with `ResourceLoader.load_threaded_request` at once and polled each frame. The browser build has no threads and keeps the old loop.
  - **Synthesized sounds:** a game's `SOUNDS` table (0.7 s of script synthesis in Turbo Run's start) is made on worker threads during the loading screen (`Synth.begin_many` / `finish_many`). Turbo Run's looping sounds (engine, wind, skid, siren, rain) and its cars' outline meshes are kept for the session, so a restart doesn't rebuild them.
  - **Loading animation:** Turbo Run's dot panel redrew 4,096 circles a frame (about 50 ms), which slowed everything running behind it, the warm-up included. It's now one tiled dot picture plus tinted dots.
  - **Reveal** (supersedes the 2 s of D-259): the warm-up copies are hidden and freed, the loading screen stays 8 frames (at least 0.25 s), then fades out over 0.35 s. Captured frames show no copies from the first frame after they're hidden. If floating cars ever show again, raise `REVEAL_FRAMES`.
- **Transitions:** every change of shell mode (menu, game, initials, operator) fades up from black over 0.3 s on the TABLE and BACKGLASS (`Shell._fade_in`). The new screen is live under the cover, so input and timing don't change.
- **Android / single screen:** the BACKGLASS viewport isn't rendered while the single layout doesn't show it (only Tilt Breaker's landscape side panels do). The texture and font changes above matter most there: far less memory, and no multi-second script stalls.
- **Web preset:** `vram_texture_compression/for_mobile=true`, so phones get the ASTC/ETC2 versions of the compressed car textures instead of decompressing BPTC at load.
- **Result** (same desktop runs): Turbo Run opens in about 2.4 s and Tilt Breaker in 1.8 s. A restart after game over takes 84 ms (Turbo Run) and 7 ms (Tilt Breaker). A 70 s race holds 60 fps with no frame over 80 ms; uncapped it runs at 350–500 fps.
- **Not measured:** no Android device was attached, so the Android gains are inferred from the desktop numbers and memory sizes. Run with `--log-perf` there to check.
- **Tools:** `--log-perf` (`?log-perf`) prints the frame rate, worst frame, draw calls, primitives and video memory every 2 s. `scripts/tools/measure_load.gd <game>` times each file a loading screen loads. The shell log now gives the load, start, warm-up and shown times.
- **Test:** sounds made in a batch are the ones `Synth.make` returns.
- **Status:** Accepted

### D-279 — Touch overlay: game-quality buttons
- **Date:** 2026-11-23
- **Decision (director):** make the web touchscreen buttons proper Google Play store game UI level, not simple unappealing circles.
- **Look** (`core/ui/touch_button.gd` + `touch_button.gdshader`, the overlay of the single layout: web and Android): each button is a shaded glass disc in its colour with a bevelled rim (bright at the top, deep below), a gloss highlight, a soft drop shadow and a glow. It's drawn by a shader, so it stays smooth at any size.
- **Icons**, in white over the glass, with the label small underneath: double arrowheads for LEFT / RIGHT, an arrow off a base line for LAUNCH, a play triangle for START, a cross for EXIT, a spark for the magna saves. A game can swap icons with the labels (`set_labels(labels, icons)`): Turbo Run shows the brake-lamp sign for BRAKE and a gear lever for SHIFT.
- **Feel:** a held button sinks (7 % smaller), fills with its colour and its glow flares, easing in over 0.05 s and out over 0.16 s. A touch gives a 12 ms vibration where the device supports it.
- **Placement:** the buttons keep D-273's one size and D-220's slots, but stand off the screen's edges (3.5 % of the short side) with wider gaps, so nothing sits against a rounded corner and the shadows have room.
- **Unchanged:** the side-column style of the old `web` page layout, and the HIDE toggle.
- **Checked:** landscape (Turbo Run) and portrait (Tilt Breaker) previews, the latter under the Compatibility renderer the browser uses. Not checked on a real phone.
- **Status:** Accepted

### D-280 — Turbo Run car select keeps its shape on any screen
- **Date:** 2026-11-23
- **Bug (director, phone screenshot):** in the Android browser, in portrait, the car select was stretched sideways: flattened turntables and cars, and the third stats card cut off.
- **Cause:** the showroom is laid out for exactly 1080×1920 (or 1920×1080 in landscape), but in the single layout the portrait TABLE is whatever is left under the DMD (about 1080×1264 on that phone). The 3D view was stretched to fill it, and the cards kept their 1920-high positions.
- **Fix** (`games/racer/showroom.gd`): the 3D view, title and cards sit in a holder of the layout's own size, scaled to fit the screen and centred; the sky backdrop still fills the whole area behind it.
- **Dev:** `--single-size=WxH` opens the single-screen preview at any size (it is still limited to the monitor's usable area).
- **Known, not changed:** in a nearly square landscape area the UI layer's 16:9 box leaves black bands above and below the car select.
- **Checked:** portrait 450×676 and landscape 1280×720 previews. Not checked on the phone.
- **Status:** Accepted

### D-281 — Touch overlay: quieter, no START / LAUNCH buttons, EXIT at the top
- **Date:** 2026-11-23
- **Decision (director):** make the touch buttons more transparent and less intrusive. The LAUNCH and START buttons are redundant on a touchscreen. The EXIT button can go at the top of the screen.
- **Tap the game:** in the overlay (single layout: web and Android), a touch anywhere on the game that isn't a button is LAUNCH, held for as long as the finger stays (Tilt Breaker's charge shot, D-264). Every screen that takes START also takes LAUNCH (picker, attract screens, menus, initials, the quit dialog), so START needs no button. This replaces the overlay's use of the TABLE halves as flipper pads (D-176); LEFT and RIGHT are the flippers.
- **Buttons left:** MAGNA (BRAKE / SHIFT in Turbo Run) above LEFT and RIGHT at the bottom corners.
- **EXIT:** a small button (62 % of the others' size, the cross only) in the top left corner, opposite the HIDE toggle.
- **Quieter at rest** (amends D-279): the glass is 22 % opaque (was 55 %), the rim 50 %, the shadow and glow much lighter, icons and labels at about 60 %. A held button still fills with colour and lights up fully.
- **Unchanged:** the side-column style of the old `web` page layout keeps all its buttons and the flipper pads.
- **Checked:** landscape (Turbo Run) and portrait (the menu and Tilt Breaker) previews; a tap on the menu starts the game. Not checked on a real phone.
- **Status:** Superseded by D-282 (the layout and tap-to-launch; the quieter look and the EXIT button stay)

### D-282 — Touch overlay: the bottom half of the screen is the flippers
- **Date:** 2026-11-23
- **Decision (director):** make the bottom half of the screen the LEFT and RIGHT flippers, and only add buttons for EXIT and LAUNCH in the top half, glass-like and unintrusive. At the start of the game, show a message and an overlay pointing out which areas are the LEFT and RIGHT flippers. Supersedes D-281's layout (magna buttons above flipper buttons, tap anywhere for LAUNCH).
- **Flippers** (`core/ui/touch_zones.gd`, the overlay of the single layout: web and Android): a touch in the bottom half of the screen holds LEFT on its left half and RIGHT on its right half. Each finger is tracked, so both can be held, and a finger sliding across changes side. Nothing is drawn there in play except a faint blue light rising from the bottom of a held side.
- **Buttons:** only two, in the quiet glass style (D-279, D-281): EXIT, the small cross in the top left corner, and LAUNCH at the right edge just above the middle of the screen, within a thumb's reach. LAUNCH does everything START does. A touch elsewhere in the top half does nothing.
- **Magna saves:** no touch control. Turbo Run stays in its automatic 2-button mode on touch (no BRAKE or SHIFT), and Tilt Breaker has no dash there (D-007: two flippers and LAUNCH are enough).
- **Hint:** when the overlay first appears (the menu) and each time a game starts (`GameMode` calls `show_hint` through the `touch_controls` group), the two areas show for 4 s as dark glass panels with a blue edge, an arrow and LEFT / RIGHT, with "TOUCH THE LOWER HALF OF THE SCREEN FOR THE FLIPPERS" above them. Touching an area fades them out sooner.
- **HIDE** still hides the buttons and turns the touch areas off.
- **Unchanged:** the side-column style of the old `web` page layout.
- **Checked:** landscape (Turbo Run) and portrait (menu) previews with mouse clicks. Not checked on a real phone.
- **Status:** Accepted

### D-283 — Turbo Run on phones: sound cuts, frame rate, touch help
- **Date:** 2026-11-23
- **Reports (director, phone browser):** Turbo Run still stutters a bit and the sound cuts. The attract screen's help still names the magna saves, which the touch overlay no longer has (D-282).
- **Measured:** the browser build in desktop Edge holds a steady frame rate in a race (one 141 ms frame in 40 s), so nothing in the race stalls by itself; the phone simply has less to spare. No phone was attached, so the fixes below are aimed at the known costs, not measured on the device.
- **Why the sound cuts:** the browser build has no threads, so sound is mixed on the game's own thread (D-175). Any frame longer than the sound buffer (about 46 ms) leaves a gap.
- **Sound fixes:**
  - `audio/driver/output_latency.web = 100` (was the default 50): the buffer is about twice as long (93 ms), so a slow frame no longer empties it. Sounds start about 50 ms later in the browser.
  - The tunnel reverb (D-127) ran for the whole race at zero level. It is now switched on only in tunnels.
  - Turbo Run's loops (engine, whine, wind, skid, siren, passing cars) are paused while too quiet to hear (under -58 dB), so the mixer skips them. In the menus that is all of them.
- **Frame rate** (browser and Android only; cabinets and the PC build are untouched): in HD, if a race averages under about 48 fps for 4 s, the world's quality goes down one step, and stays there for the session: 4× anti-aliasing → 2× → none at 85 % resolution → 70 % → 58 %. The HUD and touch controls stay at full resolution. 16-BIT and 8-BIT already render small and don't change. `--rc-auto-quality` turns this on in a dev run and `--rc-full-quality` turns it off anywhere.
- **Touch help:** with the touch overlay on, Turbo Run is always in its 2-button mode (the operator's 4-button setting is ignored there), and uses shorter texts: the attract help (`RC_HOW_TO_TOUCH`) and the car select hint without the magna colour change (`RC_SELECT_HINT_TOUCH`). Gears are still shifted by holding both sides.
- **Not done:** a threaded browser build would mix sound off the game's thread, the complete cure for cuts. It needs cross-origin isolation on the server and can't be tested here on a phone; proposed to the director.
- **Checked:** the quality steps by capping a dev run at 30 fps (all four steps taken; the lowest still looks right); the touch attract screen. Not checked on a phone.
- **Status:** Accepted

### D-284 — Local 2-player: plan, and slice 1 (input)
- **Date:** 2026-11-23
- **Decision (director), on branch `two-player`:** 2-player options.
  - **Where:** landscape screens only, with a keyboard or gamepads; local multiplayer only.
  - **Tilt Breaker:** two paddles, offset slightly vertically so they don't collide. Shared 3 lives, separate power-ups and energy bars, shared score. A wider play area and levels made for two.
  - **Turbo Run:** side-by-side split-screen racing. Each player chooses a car. The first to reach the end of stage 10 wins, with no time limit.
- **Director's answers:**
  - **Controls:** a gamepad per player; one pad alone is P2 with the keyboard as P1; keyboard only splits between the two.
  - **Choosing 2P:** a 1 PLAYER / 2 PLAYERS choice in each game after PRESS START, shown only when 2P is possible.
  - **Turbo Run 2P keeps:** traffic, police chases, weather and time of day, and each half shows the other car (they can bump).
  - **Tilt Breaker 2P:** one shared ball; a drain costs a shared life.
- **Slices:** 1. input (this entry); 2. Tilt Breaker 2P; 3. Turbo Run 2P.
- **Slice 1** (`CabinetInput`):
  - **Actions:** player 2 has `p2_flip_l`, `p2_flip_r`, `p2_launch`, `p2_magna_l`, `p2_magna_r`.
  - **`set_two_player(on)`** rebinds:
    - two pads: pad 1 drives only P1's per-player actions and pad 2 only P2's (the `SINGLE_PAD` mapping, D-256);
    - one pad: P2, with the keyboard as P1;
    - none: the keyboard splits, P1 on arrows / Space / Ctrl and P2 on A / D / W / Q / E.
  - **Shared:** EXIT, START and BACK stay on every device.
  - **Pads coming and going:** a pad connecting or disconnecting rebinds.
  - **Analog:** `steer_axis(player)` and `trigger(right, player)` read that player's pad.
  - **Signals:** player 2's presses and releases come through `action_pressed` / `action_released` like the others.
  - **Availability:** `two_player_possible()` is true on a landscape single screen, except touch-only devices (web or Android) without two pads.
- **Test:** player 2's actions and keys.
- **Status:** Accepted (slice 1 of 3)

### D-285 — Tilt Breaker 2P, part 1: the simulation
- **Date:** 2026-11-23
- **Decision (director):** D-284's Tilt Breaker 2P: two paddles slightly offset vertically so they don't collide, shared 3 lives, separate power-ups and energy bars, shared score, a wider field and levels for two. The director chose one shared ball; a drain costs a shared life.
- **Field:** `Sim.setup_two`. `FIELD_2P` is 14.16 wide (1.73× the 1P field), with 19 columns at the 1P brick width.
- **Levels:** `level2p_01..10.txt` are generated from the 1P levels: their 11 columns in the middle, with 4 edge columns mirrored out to each side, so patterns carry across. The director may edit them.
- **Ships:** they start in the middle of each half. Player 2's ship flies `P2_LIFT` 0.6 higher, so the ships pass each other.
- **Per-ship state** (`PLAYER_FIELDS`: position, speed, height, dash, power-up, shield, energy, charge, invulnerability, stick) is swapped in with `_use(i)`, so the 1P code runs unchanged for whichever ship is live. `player_get(i, field)` reads either ship. `step_two(dt, p1, p2)` takes each player's [left, right, launch, dash].
- **Shared:** the ball (and Bounce extras), lives, score, bricks and enemies.
- **The ball:** it bounces off either ship (P1 checked first) and their Lightspeed ghosts, and either ship's shield saves it.
- **Power-ups:** a capsule goes to the ship that catches it (`powerup_collect` names the ship). A drop is never a kind either ship already has (D-275).
- **Enemies:** a collision destroys that ship, which costs a shared life.
- **A drain:** a shared life lost; both ships' power-ups end and their energy refills, and the serve passes to the other player (`server`).
- **Next level:** both ships return to their halves with full energy.
- **1P:** unchanged. All the existing tests pass.
- **Tests:** a wider field and levels, the offset ships, each player moving only their own ship, per-ship power-ups, and a drain costing a shared life and passing the serve.
- **Status:** Accepted (part 1; the view and the 1P/2P choice follow)

### D-286 — Tilt Breaker 2P, part 2: the view and the 1P/2P choice
- **Date:** 2026-11-23
- **Decision:** completes D-285 on screen.
- **The choice:** when `CabinetInput.two_player_possible()` (single landscape screen, keyboard or pads, D-284), PRESS START opens 1 PLAYER / 2 PLAYERS (flippers choose, Launch confirms), then the difficulty as before. Otherwise the choice is skipped.
- **Going 2P:** choosing 2 PLAYERS turns on player 2's controls and starts the 2P simulation on the wide field. It rebuilds the bricks, the edge shields and the shield barrier for the wide field, and builds a second ship (warm key light).
- **The view's ship state:** like the simulation's, one ship's nodes and view state (`VIEW_FIELDS`) are live at a time, swapped by `_view_use(i)`, which also swaps the simulation. `_animate_ship` (position, banking, engines, blinking, shield flash, recoil, charge glow, Lightspeed ghosts, recharge flash) runs once per ship. Each event is shown on its own ship (`Sim.event_ship`, the ship named in `paddle`/`powerup_collect`, the server for `serve`).
- **Intro and outro:** both ships fly in together; at a level's end each settles in the middle of its half and lifts off.
- **The HUD:** each player's energy bar shows at the bottom corners of the TABLE (P1 blue, P2 orange), coloured by their power-up and labelled with its letter. The DMD shows the shared score and lives; at the start it reads "2 PLAYERS".
- **P2 controls:** `p2_flip_l` / `p2_flip_r` move, `p2_launch` fires and charges, and `p2_magna_*` dash. P2's stick steers (`steer_axis(1)`).
- **Leaving the game:** turns 2P input off again.
- **Dev:** `--tb-2p` starts straight in 2P. `--screenshot-delay` counts frames, not seconds.
- **1P:** unchanged.
- **Status:** Accepted

### D-287 — Tilt Breaker 2P: two power bars on the DMD
- **Date:** 2026-11-23
- **Decision (director):** in 2-player Tilt Breaker the DMD shows both players' power bars.
- **Layout:** `Dmd.show_status_two` keeps the shared score (top) and lives (bottom left). P1's compact 3-cell bar comes after the lives, P2's is at the right edge, and the level (`L1`) sits between them.
- **Badges:** each bar's badge slot shows that player's power-up letter in its colour, or the player's number (dim) when they have none.
- **Per player:** the bar hides for Lightspeed or Shield (as in 1P), and each player's LOW warning blinks in their own bar (`_low_power_t` is per ship).
- **Drawing:** `_draw_bar` takes an optional cell width and right edge; 1P is unchanged.
- **Status:** Accepted

### D-288 — Turbo Run 2P, part 1: the simulation
- **Date:** 2026-11-23
- **Decision (director, D-284):** split-screen racing. Each player chooses a car; the first to the end of stage 10 wins, with no time limit. Traffic, police chases, weather and time of day stay, and the other player's car is visible and can be bumped.
- **One shared simulation, as in Tilt Breaker (D-285):**
  - Each player's car state (`PLAYER_FIELDS`: position, speed, gear, drift, nitro and canisters, police, crash, checkpoints, score, …) is swapped in with `_use(i)`, so the 1-player code runs unchanged for whichever car is live.
  - `setup_two(seed, cars)` puts both cars side by side on the grid. `step_two(dt, inputs)` steps each player and tags each event with its player (`event_player`).
  - `start_at_stage(n)` moves both cars to stage n's start.
- **Shared:** the track, the traffic and the random stream.
- **Per player:** police chases and nitro canisters.
- **Traffic:**
  - It moves once per step (`_move_traffic`), reacting to both players: it yields to either player's police, waits behind either one's crash, and dodges either one when they're stopped.
  - Each player's pass handles that player's contacts, passes, near misses and high beams (their own `last_ds` / `flashed`).
  - Cars are removed only when out of range of both players. Spawns count the cars near the current player, and never appear in sight of the other player (−80…400 m around them).
- **Player-to-player contact (`_rival_contact`):** side by side, both bounce apart and turn away (as with traffic, D-239). Nose to tail, the car behind slows to the front car's speed and the front one gets a nudge.
- **No clock:** each player's clock is frozen.
- **The finish:**
  - The first player across the line is the `winner` (event `winner`).
  - The race is over (`race_over`) when both have stopped, or `WIN_WAIT` 8 s after the winner crossed.
  - Crossing the line again does nothing.
- **1P:** unchanged. All the existing tests pass, plus new tests for the grid, separate steering, no clock, the side-swipe, the winner and the race's end.
- **Status:** Accepted (part 1; the split-screen view follows)

### D-289 — Turbo Run 2P, part 2: split screen
- **Date:** 2026-11-23
- **Decision:** the screen side of D-288.
- **The choice:** when `CabinetInput.two_player_possible()`, PRESS START opens 1 PLAYER / 2 PLAYERS, then graphics, start stage and car select as before. In 2P, car select runs twice ("PLAYER n: CHOOSE YOUR CAR"; P2 may use their own controls). The two cars are never painted identically: the same car and colour gets the next paint.
- **Two views, one race:**
  - The module (player 1's view) splits the TABLE into two halves with a black line. It moves its own nodes into the left half and adds a second copy of the game script as a child (player 2's view, `_role = 1`) in the right half.
  - Each view is the full 1P view: its own 3D world (the game already renders into its own viewport), camera, chunks, weather, sky, sun, fog, HUD and engine sounds. It draws the shared simulation from its own player's car (`sim._use(_role)` each frame).
  - `add_to_table`, `_table_base` and `_table_px` give each view its half. Each half has a portrait-like shape, so it uses the portrait HUD layout.
- **Stepping:** player 1's view steps the race with both players' controls (`_read_input` per view: flippers, stick, triggers, brake), then each view shows its own player's events plus the shared ones. P2's magna buttons go to P2's view (manual brake/shift).
- **The other car:** drawn in each view with its model and colour, drift yaw, side-impact sway, crash spin or slew, turning wheels and night lights.
- **Owned by player 1's view only:** the DMD (other DMD calls go to a quiet stand-in), music (it follows player 1's stage), the backglass, the tunnel reverb, and the shared lamp/sprite night levels and city lights (shared materials, so they follow player 1's time of day).
- **HUD:** POSITION (1ST/2ND) replaces TIME.
- **DMD:** "P1 speed / stage" on the left and "P2 speed / stage" on the right, plus a strip with stage ticks and both cars' places in the race (P1 yellow, P2 cyan).
- **The finish:**
  - The finisher's half shows "WINNER!" or "2ND". The other half shows "PLAYER n WINS", and so does the DMD.
  - The finale shows each half's place, player and distance, without scores.
  - Then back to PRESS START with no high-score entry (`finished([])`). Leaving the game turns 2P input off.
- **Dev:** `--rc-2p` (`--rc-car2=N`) starts straight in 2P. `--rc-autopilot` drives both cars.
- **1P:** unchanged.
- **Status:** Accepted

### D-290 — Turbo Run 2P: a tag over the other player's car when it's ahead
- **Date:** 2026-11-23
- **Decision (director):** each half shows the other player's tag (`P1` / `P2` in red, outlined) over a red down-pointing triangle above their car. It shows only while that car is ahead (3–600 m) and in line of sight.
- **How:**
  - The tag is a billboarded Label3D and Sprite3D (the triangle is drawn at runtime). Both are fixed-size on screen and pixel-crisp, with the triangle's tip 2.3 m above the road over the car.
  - They're drawn with the depth test, so hills, tunnels, buildings and traffic in the way hide the tag: that gives the line of sight without ray casts.
- **Status:** Accepted

### D-291 — Turbo Run 2P: a DMD per player, no radar lights, half-size gauges
- **Date:** 2026-11-23
- **Decision (director):** in a 2-player race:
  - **A DMD for each player.** The single screen's shared DMD box is hidden (`Screens.show_single_dmd(false)`; shown again on leaving). Each half shows its own DMD at its top centre, 480 base px wide (half a half: the single screen's DMD is a quarter of 16:9).
  - Player 1's DMD is the `Dmd` autoload. Player 2's view makes its own instance of `core/dmd/dmd.gd`. Each shows the full 1P content for its player: REV UP, the dash, police chase, radar, and the crash/nitro/shift animations with that player's car sprite.
  - Custom DMD frames draw from their view's player (`_dmd_custom` makes that car live first). D-289's quiet stand-in and shared two-player frame are gone.
  - "PLAYER n WINS" shows on both DMDs.
  - **No radar lights** along the top (the DMD's radar and beeps are enough). The radar bar is hidden with `modulate.a` in 2P; 1P is unchanged.
  - **The bottom gauges at half size** (`_hud_compact`). `Dial.set_radius` halves the tachometer and speedometer, and their number labels keep their text size, with every other number shown so the smaller arc isn't crowded. The shift lamp scales down, and the gear lever is drawn at half size. The RPM/MPH captions and the digital speed keep their size.
- **Status:** Accepted

### D-292 — Turbo Run: player 2's own default colour; dust and sparks on vehicle collisions
- **Date:** 2026-11-23
- **Decision (director):**
  - **Player 2's default colour differs from player 1's.**
    - P2 has their own paints per car (`_car_paint_p2`, starting at the second paint), so their car comes in another colour by default.
    - The car select and their magna repaint use P2's paints.
    - D-289's rule still applies on top: the same car and paint as P1 gets the next paint.
  - **Dust and sparks on every vehicle collision:** a player and traffic (bumps, side-swipes, crashes into a car or truck), the two players, and a player and the police (rams either way). Crashes into roadside objects don't count.
    - Each view shows every collision near it, whichever player it was. The burst sits at the contact point (halfway between the two vehicles; ahead of the car for a crash) and stays in the world, so at speed the cars leave it behind.
    - **Sparks:** small round dots, white-yellow to orange to red, flying up and falling under gravity.
    - **Dust:** soft puffs in the road-dust colour that drift up and grow.
    - Crashes give a bigger burst.
- **Particles:** `CPUParticles3D` (GPU particles don't move in our TABLE viewports). Fired with `restart()` after placing them, with no shadows. Setting `emitting = true` left an inactive particle drawn as a black square at the emitter and could hide the sparks entirely.
- **Dev:** `--rc-burst` fires a burst in front of the car every half second.
- **Status:** Accepted

### D-293 — Turbo Run 2P: the speedo in the corner, smaller gears, a bar tachometer
- **Date:** 2026-11-23
- **Decision (director):** in a 2-player race, each half's bottom HUD is:
  - **The speedo** in that player's bottom right corner (the bottom row right-aligned).
  - **The gear lever** beside it at 0.4 size (D-291 had 0.5), with a gap so its H/L letters stay clear of the speedo.
  - **The tachometer as a horizontal bar** under the speedo's MPH caption, replacing the round tacho (hidden in 2P): 20 segments, yellow, green in the perfect-shift band (the perfect-start band on the grid), and red from the redline (7/8). Unlit segments are dimmed in the same colours.
- 1P is unchanged.
- **Status:** Accepted

### D-294 — Turbo Run 2P: the shifter at its small size, level with the speedo
- **Date:** 2026-11-23
- **Decision (director):** the 2P shifter was too big and ran off the bottom of the screen. It should line up with the speedo + tacho.
- **Cause:** a container resets its children's scale on every layout, so D-291/D-293's scaled lever went back to full size (150×210) after the first re-layout.
- **Fix:**
  - The lever now sits in a plain holder Control (the container sizes the holder, not the lever) at `GEAR_COMPACT` 0.4.
  - The gear column is as tall as the speedo + MPH + tach bar block and centres the lever on it (`SIZE_SHRINK_END`, `ALIGNMENT_CENTER`).
- **Status:** Accepted

### D-295 — Turbo Run 2P: the shifter beside the speedo, 50% bigger
- **Date:** 2026-11-23
- **Decision (director):** the 2P shifter goes right next to the speedo, 50% bigger (`GEAR_COMPACT` 0.4 → 0.6).
- **The gap came from widths left over from the full-size HUD:**
  - the row's 36 px separation (now 6);
  - the gear column's 90 px minimum (now none);
  - the nitro strip under the lever, 160 px wide (now the lever's width, with its fill scaled to the strip's width);
  - the tach bar, 40 px wider than the speedo (now the speedo's width), which pushed the speedo right.
- The lever sits hard against the speedo (`SIZE_SHRINK_END`).
- **Status:** Accepted

### D-296 — Turbo Run 2P: the gauge block 25% bigger
- **Date:** 2026-11-23
- **Decision (director):** the 2P bottom-right gauge block is 25% bigger: the speedo (`COMPACT` 0.5 → 0.625 of the full dial), the shifter (`GEAR_COMPACT` 0.6 → 0.75) and the tach bar (18 → 22 px high, the speedo's width).
- The text (dial numbers, MPH, digital speed) was already full size and stays as it is (PinPixel sizes snap to multiples of 12, D-060).
- **Status:** Accepted

### D-297 — Turbo Run 2P: the REV! hand points at the bar tachometer
- **Date:** 2026-11-24
- **Decision (director):** in 2P the countdown's REV! hand (D-197, D-209) pointed at thin air: the round tacho it aims at is hidden there (D-293).
- **Fix:** with the bar tachometer, the hand turns 90° counter-clockwise to point down. Its fingertip sits just above the bar's green start band and pokes down at it, with REV! to its left. 1P is unchanged.
- **Status:** Accepted

### D-298 — Turbo Run: a police car parked behind each speed camera
- **Date:** 2026-11-24
- **Decision (director):** each speed camera has a police car parked behind it, side on with its nose to the road. It's scenery only: chases still start as before when a camera catches you speeding (D-135, D-156).
- **How:** built with the camera's road chunk. It's the police model (lights off), 4.5 m further out than the camera and 4 m before it along the road.
- **Dev:** `--rc-at-trap[=N]` starts N m (default 45) before the next speed camera.
- **Status:** Accepted

### D-299 — Turbo Run: no steering while sliding to a stop
- **Date:** 2026-11-24
- **Decision (director):** when time runs out (and past the finish line), the car's slide to a stop ignores the player's steering, flippers and stick. Before, it could be steered and looked like it was sliding sideways on ice.
- A checkpoint reached on momentum still saves the race (D-103).
- **Status:** Accepted

### D-300 — Turbo Run: the checkpoint time bonus decays more slowly
- **Date:** 2026-11-24
- **Problem (director):** a run with no crashes until city 2 (stage 7), then one crash plus a bust, missed the next checkpoint with the normal car.
- **Measured:** the sim's autopilot, with traffic contact off (a clean drive), takes about 30 s per stage in the normal car. With the checkpoint bonus at 34 − 2 s per checkpoint and a floor of 20 s (D-101, D-183), the bonuses fell below a stage's time from stage 5. The clean drive ran out of time in stage 6 or 7 with zero crashes, so any mistake there was fatal.
- **Change:** `BONUS_DECAY` 2 → 1 s per checkpoint, `BONUS_FLOOR` 20 → 28 s. The normal car's bonuses are now 33, 32, 31, 30, 29, then 28.
- **Result:** the clean drive finishes with 3–5 s to spare (three seeds), with a 9–19 s buffer through the middle stages. A player using nitro and perfect shifts gains more. One crash plus a bust (~15 s) mid-race is survivable; several aren't.
- **The other cars:** their per-car extras (D-183: easy +10, hard −4) apply to the floor as before.
- **Status:** Accepted

### D-301 — Turbo Run: the radio (music select) after car select
- **Date:** 2026-11-24
- **Decision (director):** after the car select (both players' in 2P), a music select screen: a mock-up radio in 16-bit art style, with a dial, the song titles scrolling on an LCD and a 90s-style graphic equaliser. The chosen song plays for the whole run.
- **The radio** (`games/racer/radio.gd`) is drawn flat in code in the UI layer, so 8-BIT/16-BIT get real pixels:
  - a bevelled dark body with a speaker grille each side (their cone caps thump with the bass);
  - a dark LCD with scan lines, a glass glint, FM / ST, the frequency, the title scrolling in cyan dot-matrix text ("SONG  -  BOGART VGM"), and a 12-band, 10-segment equaliser (green / yellow / red, falling peaks);
  - a cream backlit tuning dial (88–108 MHz) with the five stations marked and a red needle that slides to the chosen one;
  - five preset buttons (the chosen one pressed in, its lamp lit);
  - VOL and TUNE knobs (TUNE turns with the needle) and a "TURBO FM STEREO" badge.
- **The equaliser:** follows the music through a spectrum analyser added to the Music bus while the radio shows (12 log-spaced bands, 60 Hz–12 kHz). Where bus effects don't run (web playback), it bounces on its own to a ~120 bpm pulse.
- **Controls:** flippers (or magna saves; either player in 2P) tune down/up, Launch confirms. As in the other menus, it goes on by itself after `SELECT_TIME`. Each station plays its song as soon as it's tuned (crossfaded in from where it gets going, D-227), and the DMD shows the title and frequency. The attract demo keeps driving behind the dimmed screen.
- **Stations:** 88.9 Maximum Overdrive, 92.3 One More Round, 96.5 Nightlife, 101.1 Dreamstate, 105.7 Chillwave Nightdrive, all Bogart VGM. The choice is kept for the session.
- **The run's music:** the race carries the chosen song on and it loops for the whole run. This replaces D-226's one song per two stages with crossfades at the checkpoints.
- **Dev:** `--rc-radio` opens the radio straight away.
- **Status:** Accepted

### D-302 — No sound effects on attract or selection screens
- **Date:** 2026-11-24
- **Decision (director):** attract and the selection screens are music only, with no sound effects.
- **How:** every sound effect in Turbo Run and Tilt Breaker goes through the game's `_sfx()`, which drops it while `_phase` is in `QUIET_PHASES`:
  - Turbo Run: attract, players, gfx, stage, select, radio;
  - Tilt Breaker: attract, players, select.
- Turbo Run's engine, wind, skid, siren, horn and passer loops were already silenced on its menus (D-235, D-236). They now use the same list, which adds the 1/2-player and radio screens.
- The race countdown, Tilt Breaker's intro and everything after keep their sounds. (Sky Striker has no sound effects yet.)
- **Status:** Accepted

### D-303 — Turbo Run: contact sparks like metal scraping metal
- **Date:** 2026-11-24
- **Decision (director):** smaller sparks, from where the vehicles actually touch, flying towards the back of the car like metal scratching metal (supersedes D-292's sparks).
- **The contact point** is on the hit car's body, facing the other vehicle: its flank when the other is beside it (more than 40% of a car's width across), otherwise its front or rear bumper (along the road, clamped to the car's length). It's 0.45 m up.
- **The sparks:**
  - small (0.1 m) specks in a short 0.35 s stream (not a burst) from that point;
  - the emitter rides on the car that was hit: this view's own car, or the other player's car in 2P;
  - each spark leaves forward along the road at 55–85% of the car's speed, so it streaks back along the body and off behind, dropping under gravity;
  - a flat fan with 14° of spread;
  - crashes into cars and trucks give more sparks.
- **The dust puff** stays where it happened (D-292).
- `--rc-burst` now makes a contact on the car's right flank at its speed.
- **Status:** Accepted

### D-304 — Menus keep their own sounds; only the gameplay behind them is silent
- **Date:** 2026-11-24
- **Decision (director):** corrects D-302. The attract and selection screens still play their menu sounds when choosing options. Only the background gameplay sound is silent: car and gameplay effects.
- **How:** in `QUIET_PHASES`, `_sfx()` lets through only `MENU_SFX` (start, select, move, error, rc_shift, the tuning/shift click Turbo Run's menus use) and drops everything else.
- The attract demo car's radar beeps (their own player) stay quiet too. The engine, wind, skid, siren, horn and passer loops stay silent as before (D-235).
- **Status:** Accepted

### D-305 — Turbo Run: timed menus tick through their last 5 seconds
- **Date:** 2026-11-24
- **Decision (director):** the menus that choose by themselves after `SELECT_TIME` (graphics, start stage, car select, radio) play a tick once a second for the last 5 seconds (`rc_tick`, the race clock's tick, now also a menu sound).
- A move restarts the menu's timer, and the ticking with it.
- Tilt Breaker's menus have no time limit, so they don't tick.
- **Status:** Accepted

### D-306 — Fix: Tilt Breaker's side panels stayed on after quitting early
- **Date:** 2026-11-24
- **Bug (director):** quitting Tilt Breaker early (back/exit soon after choosing it) left its DMD and BACKGLASS side boxes (D-265) on the single screen, over the menus and the next game (Turbo Run).
- **Cause:** `Screens.want_side_panels()` only set its flags. The single screen was laid out again only when something else asked (e.g. the game reporting its play width each frame). A game quit before that happened turned the panels off without the screen being re-placed.
- **Fix:** `want_side_panels()` lays the single screen out again at once, as `want_dmd_above()` already did.
- **Checked:** reproduced (quit 20 steps after starting the game; the boxes stayed on the menu), then fixed in the single layout; the windowed layout is unaffected.
- **Status:** Accepted

### D-307 — Turbo Run: the race's song starts from the top
- **Date:** 2026-11-24
- **Decision (director):** at the start of the race, the chosen song (D-301) starts from its beginning, with no crossfade (one song per race now).
- **How:** `Audio.play_music(path, fade, restart)` takes a `restart` flag. Asking for the song already playing then starts it again from 0 instead of carrying it on. The race calls it with fade 0 and restart, so the radio's preview (which joins each song past its quiet opening, D-227) is cut and the song starts at its first note.
- The radio still crossfades between stations while tuning.
- **Status:** Accepted

### D-308 — Turbo Run's own theme; Chillwave Nightdrive to the game selection menu
- **Date:** 2026-11-24
- **Decision (director):** the director's own "Turbo Run" theme (`Turbo_Run-Original.mp3`, CC BY 3.0, the director's work) is Turbo Run's main tune. The other songs move down one place, and the 5th (Chillwave Nightdrive) leaves the racing game to become the game selection menu's song.
- **Turbo Run:** it plays in attract (`MUSIC_ATTRACT`) and is radio station 1 (88.9, the default). The LCD credits it as "TURBO RUN - ORIGINAL SOUNDTRACK".
- **The other stations:** 2 Maximum Overdrive, 3 One More Round, 4 Nightlife, 5 Dreamstate (all Bogart VGM). Its crossfade join point is 3 s (measured: full strength from ~3 s).
- **The game selection menu (picker):** plays Chillwave Nightdrive (`Audio.MUSIC_PICKER`). The shell's attract keeps `MUSIC_MAIN`.
- **Files:** converted to `assets/audio/music/racer/turbo_run_original.ogg` (Vorbis q5). Recorded in `assets/CREDITS.md`.
- **Status:** Accepted

### D-309 — Turbo Run: wheelspin smoke pulling away, black skid marks when drifting
- **Date:** 2026-11-24
- **Decision (director):** accelerating from a full stop puts smoke out of the tyres, and drifting leaves black skid marks on the asphalt from the tyres' contact with the road.
- **Wheelspin smoke:**
  - From a standstill (under 1 m/s: the start grid, after a crash, a bust), the rear tyres smoke while the car pulls away (throttle on), until it reaches `LAUNCH_SMOKE_V` 9 m/s.
  - Not off-road, which already throws dust.
  - It uses the drift smoke's puffs (D-100), thinner and smaller (alpha 0.22, size 0.5–0.9), so it doesn't hide the car.
- **Skid marks:**
  - While drifting, and in the drift-brake slide at time up or past the finish, the two rear tyres lay dark strips (near-black, alpha 0.6, 0.26 m wide).
  - The strips start at where the tyres really are: 1.35 m behind the centre, 0.78 m to each side, turned with the drift angle.
  - They're built from flat segments about 0.6 m long in a world-space ring of 900 (a MultiMesh), drawn over the road and its puddles. They stay on the road as the car leaves them; the oldest are reused, and a new race clears them.
- **Dev:** `--rc-skid` lays the marks all the time.
- **Status:** Accepted

### D-310 — Turbo Run: smaller, brighter sparks; skid marks on crashes
- **Date:** 2026-11-24
- **Decision (director):**
  - **Contact sparks** (D-303) are smaller (0.06 m, was 0.1) and bright yellow (white-yellow, yellow, then a fading amber).
  - **Crashes** mark the road too: a spin-out lays the rear tyres' skid marks (D-309) while the car still slides, so it leaves the curling tyre trail of the spin.
  - A roll-over doesn't mark the road (its wheels are in the air), and neither does a car stopped after a crash.
- **Dev:** `--rc-crash-at=N` makes the car spin out N s into the race.
- **Status:** Accepted

### D-311 — Turbo Run: the director's finish and time-over jingles
- **Date:** 2026-11-24
- **Decision (director):** the director's `racing_goal` plays after crossing the finish line, and `time_over` plays when time runs out. Both are the director's own work.
- **How:**
  - Both are converted to OGG (`assets/audio/music/racer/racing_goal.ogg`, 5.0 s; `time_over.ogg`, 6.7 s).
  - They play once on the music channel in place of the race's song (`Audio.play_music(..., loop = false)`, a new option), quickly faded in from it.
  - They replace the old synth fanfare and time-up sound for these moments.
- **In 2P:** the goal jingle plays when the winner crosses (player 1's view owns the music).
- **Saved checkpoint:** a checkpoint reached on momentum after time up (the race goes on, D-103) brings the race's song back.
- Recorded in `assets/CREDITS.md`.
- **Status:** Accepted

### D-312 — Turbo Run: default paints yellow, orange, red; black and grey added
- **Date:** 2026-11-24
- **Decision (director):** the default car colours are yellow (Easy), orange (Normal) and red (Hard). Black and grey join the colour options.
- **Defaults:** set by the cars' base hue turns (`Sim.CARS[i].hue`): the red hot hatch turned to yellow (0.13), the red sports car to orange (0.06). The supercar's own paint is a pale yellow, which a hue turn alone makes pink. It uses a "deepened" paint: a hue of `10 + turn` in the car shader means turn, then deepen the paintwork's colour (10.89 = red). `_turn_hue()` keeps that through repaints. `CAR_COLS` (DMD) follows.
- **Black and grey:** two new entries at the end of `PAINTS` (`PAINT_BLACK` 2.0, `PAINT_GREY` 3.0). The car shader reads a hue of 1.5 or more as a neutral paint: only the paintwork (saturated texels) becomes black or grey, keeping its light and shade, while glass, tyres, chrome, stripes and lamps stay as they are. Under the showroom's strong light black reads as a dark charcoal.
- **The DMD pictures** (`_painted`) follow: deepened paints are turned and saturated; black shows as dark grey (still visible on the black DMD), grey as light grey.
- **Fix found on the way:** a shader local named `mn` clashed with an existing varying and the car shader failed to compile (all cars pale). The tests don't compile spatial shaders, so only a screen run showed it.
- **Status:** Accepted

### D-313 — Turbo Run: the car select DMD shows each car's own picture
- **Date:** 2026-11-24
- **Decision (director):** the cars on the car select DMD didn't look like their in-game counterparts (a generic dot car).
- **How:**
  - The DMD now draws the highlighted car's own side picture (the race's DMD sprites, D-243/245) in its current paint, cached per car and paint, and repainted live as the colour changes.
  - The hot hatch got its own picture (`dmd_car_hatch.png`, 22×9): rendered side-on from its model with `render_car_side.py`, converted with `gen_loading_car.py --wheels --flip`. It was using the sports car's picture, in the race animations too.
- **Status:** Accepted

### D-314 — Single screen: the DMD framed as the car's rear-view mirror
- **Date:** 2026-11-24
- **Decision (director):** on a single screen, a thin frame round the DMD that makes it look like the car's mirror; the mount stalk minimal.
- **How:**
  - `Screens.MirrorFrame`: a thin dark rounded housing (2.5% of the DMD's width, lit top edge, soft shadow) and a light line round the glass.
  - A minimal stalk up to the top edge of the screen.
  - The DMD hangs that much lower so the housing shows all round.
- **When:** on a landscape single screen, whenever its shared DMD shows at the top centre (every game). Not with Tilt Breaker's side panels (their own frames, D-266), not in portrait (the DMD spans the width), and not in a 2P race (each half has its own DMD, D-291).
- **Status:** Accepted

### D-315 — Turbo Run: "Start Your Engines" for attract and the menus
- **Date:** 2026-11-24
- **Decision (director):** the director's new track "Start Your Engines" (`start_your_engines.mp3`, 2:12) is Turbo Run's attract and menu music.
- It is `MUSIC_ATTRACT` (was the Turbo Run theme, D-308). The 1/2-player, graphics, start-stage and car select screens carry it on. The radio still plays the station being tuned (D-301), and the Turbo Run theme stays radio station 1.
- Converted to `assets/audio/music/racer/start_your_engines.ogg` (Vorbis q5). Recorded in `assets/CREDITS.md`.
- **Status:** Accepted

### D-316 — Turbo Run: the slide after a roll-over leaves tyre marks
- **Date:** 2026-11-24
- **Decision (director):** when the car rolls over in a crash, its wheels leave skid marks while it slides after the flip.
- **How:** during the roll-over's slide (`crash_slide`: landed on its wheels, turned across the road) the skid marks (D-309) come from all four tyres, front and rear, turned with the car. Only the rear tyres would put them all to one side of a car sliding sideways.
- The roll itself (wheels in the air) still leaves none.
- **Dev:** `--rc-crash-flip` makes `--rc-crash-at` a roll-over.
- **Status:** Accepted

### D-317 — Turbo Run: rear-ending a truck no longer rolls the car through it
- **Date:** 2026-11-24
- **Bug (director):** crashing into the back of a truck, the car's roll carried it forward through the truck. The roll slides on at up to 30 m/s, faster than the truck.
- **Fix (director's design):** a high-speed rear-end into a truck (same direction):
  - shoves the truck on: it gains `TRUCK_SHOVE` 8 m/s, then eases back to its own speed;
  - moves the rolling car off to the truck's nearer side (towards the road's middle if it's square behind), at `VEER_RATE` 14 m/s, to just clear of the truck's flank;
  - rolls the car away from the truck;
  - holds the car behind the truck's tail, at no more than the truck's speed, until it's clear sideways.
- **State:** `veer_x` / `veer_id` (per player in 2P). Any other crash clears them.
- **Test:** a car at 60 m/s into a truck's back rolls, is never inside the truck, and the truck speeds up. Both checks fail on the old code.
- **Dev:** `--rc-crash-at=N --rc-crash-truck` puts a truck just ahead in the car's lane at N s.
- **Status:** Accepted

### D-318 — Tilt Breaker: the director's own gameplay music
- **Date:** 2026-11-24
- **Decision (director):** the director's "Tilt Breaker" track (`tilt_breaker-original.mp3`, 2:25) plays during Tilt Breaker's gameplay.
- It is the game's `MUSIC` (was n-Dimensions, which stays in the repo and credits, unused). Attract keeps "My Very Own Dead Ship" (D-082).
- Converted to `assets/audio/music/breakout/tilt_breaker_original.ogg` (Vorbis q5). Recorded in `assets/CREDITS.md`.
- **Status:** Accepted

### D-319 — Fix: Tilt Breaker lost its side panels after a game over
- **Date:** 2026-11-24
- **Bug (director):** Tilt Breaker showed the DMD at the top in the mirror frame (D-314), and no backglass.
- **Cause:** after a game over, the game goes straight back to its own PRESS START (D-277). Its new copy starts, asking for the side panels, before the old copy is freed. The old copy's exit then turned them off. D-306 made that take effect at once; before, the stale layout happened to stay.
- **Fix:** `Screens.want_side_panels(on, frame, owner)` remembers who asked, and a request to turn them off from anyone else is ignored. Tilt Breaker passes itself.
- **Checked:** reproduced with a new `--tb-over-at=N` dev flag (game over at N s); the same run with the fix keeps the panels.
- **Status:** Accepted

### D-320 — Tilt Breaker: "Earth's End" after the last life
- **Date:** 2026-11-24
- **Decision (director):** the director's "Earth's End" (`earths_end.mp3`, 15 s) plays after losing all lives in Tilt Breaker.
- It plays once (`loop` false, D-311), starting as the game-over finale begins, in place of the gameplay music.
- Converted to `assets/audio/music/breakout/earths_end.ogg`. Recorded in `assets/CREDITS.md`.
- **Status:** Accepted

### D-321 — Tilt Breaker: an extra charge at 20,000 and 50,000
- **Date:** 2026-11-24
- **Decision (director):** Tilt Breaker awards an extra life (a plasma **charge**, in the game's terms) at 20,000 and at 50,000 points, once each per game. The callout reads **EXTRA CHARGE!**, never "life" (director).
- **Sim:** `EXTRA_LIFE_AT` in `sim.gd`; `_check_extra_life()` runs at the start of each step (1P and 2P; in 2P the score and lives are shared, D-285). `balls_total` grows with it, so the DMD shows the new charge dot. Event `extra_life`.
- **View:** a bright two-octave arpeggio (`tb_extra_life`, synth), "EXTRA CHARGE!" flashed on the DMD in cyan, and a backglass light chase.
- **Attract:** the DMD cycle gets an "EXTRA CHARGE AT / 20,000  50,000" page after the title / PRESS START page (director).
- **Test:** no charge at 19,990; one at 20,000 only once; both by 80,000 and no more after.
- **Dev:** `--tb-score=N` starts play at N points.
- **Status:** Accepted

### D-322 — Tilt Breaker: "DANGER / PROXIMITY ALERT"
- **Date:** 2026-11-24
- **Decision (director):** while an enemy is in the bottom 20% of the screen, a see-through red "DANGER / PROXIMITY ALERT" blinks in the middle of the play area, until the enemy moves away or is destroyed.
- **Sim:** `enemy_in_danger(margin)`: any enemy out of its wormhole below `field.end.y - 20% of the field height`. The view turns it off only once the enemy is 0.45 m back above the line, so an orbit's top dipping just above it doesn't flicker the alert.
- **Look:** PinPixel dot lettering in red at 62% alpha: "DANGER" between two drawn warning triangles (the font has no ⚠ glyph), "PROXIMITY ALERT" under it. Blinks with `modulate.a` (0.6 s cycle). Sized to the TABLE height, so it fits the single screen's narrower play area, and centred 10% above the middle, clear of PLASMA CANNON READY on the single screen.
- Only during play (not the finale or menus).
- **Dev:** `--tb-enemy-low` puts an enemy at the bottom (and keeps the ship from colliding with it).
- **Status:** Accepted
