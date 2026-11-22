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
