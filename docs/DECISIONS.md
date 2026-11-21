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
