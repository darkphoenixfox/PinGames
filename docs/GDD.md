# PinGames — Game Design Document

> Living document. Sections marked **[PROPOSAL]** wait for the director's approval.
> When a proposal is approved or changed, update it here and log a decision in `DECISIONS.md`.
> Working titles (BLOCK BREAKER, SKY STRIKER, TURBO RUN) are placeholders.

## 1. Vision
PinGames is a bundle of short, loud, readable arcade games built for virtual pinball cabinets. The player stands at the cabinet, looks down at a portrait playfield, and has only pinball buttons. Scores, combos and callouts appear on the DMD. The BACKGLASS shows art and live attract content. A game should feel at home in a pinball frontend next to VPX tables.

### Pillars
1. **Pinball-native controls.** Every game is fully playable with **2 flippers + Launch**. Magna saves add depth but are never required.
2. **Three screens, one show.** TABLE is the game. The DMD is the scoreboard and narrator. The BACKGLASS is the stage. All three react to events.
3. **Arcade sessions.** A typical game lasts 3–5 minutes. There are no tutorials longer than one attract loop, and you're in the game within 5 seconds of pressing Start.
4. **Readable at cabinet distance.** The playfield is about 1 m away, at an angle, on a 40"+ TV. Use high contrast, big sprites and no small text on TABLE.
5. **Inspired by, never copied.** Same genres and feel; original names, art, music and levels.

## 2. Hardware and screens
| Screen | Orientation | Base resolution | Role |
|---|---|---|---|
| TABLE | Portrait (TATE) | 1080x1920 (render scale 0.5–2x) | Gameplay |
| DMD | Landscape 4:1 | 128x32 dots (192x64 / 256x64 optional) | Score, ball/lives, callouts, mini-animations |
| BACKGLASS | Landscape 16:9 | 1920x1080 | Game art, player scores, attract video, boss intros |

Layouts are `3screen`, `2screen` (DMD inside the backglass) and `windowed` (three windows on one monitor, for development). See D-005, D-006 and D-013.

### What each screen shows, by phase
| Phase | TABLE | DMD | BACKGLASS |
|---|---|---|---|
| Attract | Demo gameplay loop, title, high-score table, "PRESS START" | Title, FREE PLAY / INSERT COIN, high scores, scrolling credits | Key art; animated elements |
| Picker | Game list (flippers move, Launch/Start picks) | Selected game's title | Selected game's key art |
| Play | Game | Score, player, ball/lives, combo callouts | Art plus live state (boss health, stage, lap time) |
| Game over / high score | Initials entry | Final score, "NEW HIGH SCORE" | Celebration / ranking |

## 3. Controls contract
| Action | Default (keyboard / pad) | Guaranteed? | Typical use |
|---|---|---|---|
| `flip_l` / `flip_r` | L/R Shift · L1/R1 | Yes | Move / steer / choose |
| `launch` | Space · Cross | Yes | Primary action (serve, bomb, turbo) |
| `start` | Enter · Circle | Yes | Start game / add player |
| `exit` | Backspace · Square | Yes | Back to picker, or quit (when started with `--game`) |
| `magna_l` / `magna_r` | L/R Ctrl · L2/R2 | **No** (4+1 cabinets) | Optional extras only |
| `coin` | 5 | No | Credits in coin mode |

Rules:
- Holding both flippers counts as a third input ("chord"). Games may use it but must show it on screen.
- Anything mapped to a magna save must also be reachable another way, or be a pure bonus.
- **Operator menu** (approved, D-024): hold Start + Exit for 3 s, or hold Exit for 5 s on the picker. Inside it, flippers move, Launch selects and Exit goes back.
- **High-score initials:** flippers cycle the letter, Launch confirms, Exit deletes.

## 4. Shared systems (M1)
- **Operator menu:**
  - Display Setup wizard: shows a big ID on every monitor; flippers cycle role and rotation; Launch confirms.
  - Input remapping: "press the button for LEFT FLIPPER…".
  - Language, free play / coin, balls/lives, difficulty, volume, attract sounds on/off, reset high scores.
- **Credits:** free play by default. In coin mode, Coin adds a credit and Start spends one.
- **High scores:** top 10 per game in `user://scores.cfg`, plus a grand champion. They are shown in attract on all three screens.
- **DMD** (D-026, D-027): a full-colour dot matrix, one colour per dot. The API is `Dmd.show_text(top, bottom, colours)`, `Dmd.show_score(score, left, right)` and `Dmd.flash(text, seconds)`. Long text scrolls automatically. Games may also draw anything 2D into `Dmd.viewport`, at 128x32 dots by default. A shared palette gives the bundle one DMD style.
- **Audio:** buses for Music, SFX and Callouts. Music is chiptune / arcade style and comes from a mix of sources (D-023): AI-generated tracks, tracker modules and royalty-free packs. **The game plays only OGG Vorbis.** Tracker modules (.xm/.it/.mod) are kept as source files and rendered to OGG with `openmpt123` by a script, so no native audio plugin is needed.
- **Attract mode:** after 60 s idle, the shell cycles each game's attract demo.

## 5. Games

### 5.1 BLOCK BREAKER — [PROPOSAL] — first vertical slice (M2)
**Genre feel:** paddle-and-ball brick breaking with capsule power-ups, which fits a portrait playfield naturally.

**Controls**
| Input | Action |
|---|---|
| Flippers (hold) | Move paddle left / right. Speed ramps up while held. |
| Launch | Serve the ball; fire lasers when that power-up is active |
| Both flippers | Release a caught ball (magnet power-up) |
| Magna L/R (opt.) | Paddle dash: a quick burst in that direction |

**Mechanics**
- 3 balls (operator setting). Extra balls at score thresholds.
- Bricks: normal, multi-hit, metal (indestructible), explosive, moving.
- Capsules: Expand, Laser, Catch (magnet), Multiball (3), Slow, Extra Ball, Warp (skip stage).
- **Flippers in some levels** (director, D-021). Some stages contain real pinball flippers worked by the flipper buttons. They can be anywhere in the stage, not only below the paddle: guarding side lanes, sitting next to brick clusters, or on upper floors.
  - The same button moves the paddle and fires that side's flipper **at the same moment**, so stages are designed around that.
  - *Open:* should flipper stages change how the paddle moves (for example, the paddle drifts back to centre)? Decide during M2 playtests.
- **Multiple paddles** (director). Some stages have 2 or more paddles at different heights. All paddles move together from the same buttons.
- **Multi-height stages** (director). Some stages are taller than one screen and split into floors, like a video-pinball table stacked vertically (Xenotilt is the reference for the structure only, not the game type).
  - The camera follows the ball between floors.
  - Each floor can have its own paddle(s), flippers and bricks.
  - Ramps, gaps and kickers send the ball up a floor. A ball that drops off an upper floor falls to the floor below instead of being lost. Only the bottom floor's drain costs a ball.
- The previous idea of "flipper bumpers below the paddle in every stage" is replaced by the points above.
- 32 stages in 4 worlds, with a boss stage every 8. Stages are stored as text (e.g. `games/breakout/levels/*.txt`) so they can be written without an editor. The format supports several floors, and places paddles and flippers per floor.

**DMD:** score, ball count, "MULTIBALL!", power-up names, brick count left.
**Backglass:** world art, boss portrait and health bar, power-up legend.
**Art direction [PROPOSAL]:** glossy neon. Bricks and paddle are cel-shaded 3D models with outlines, on animated sprite backgrounds.

### 5.2 SKY STRIKER — vertical shmup (TATE) (M3)
**Genre feel:** a WWII-to-near-future air combat scrolling shooter. TATE is its natural format.

**Controls** (director, D-022)
| Input | 2+1 cabinet | 4+1 cabinet |
|---|---|---|
| Flippers (hold) | Move ship left / right (**horizontal only**) | same |
| Fire | **Automatic** | **Manual**: hold either magna save |
| Both flippers held 3 s | **Bomb** | same |
| Launch | Unassigned (D-025): hands stay on the flippers | same |

- **Bomb charge:** holding both flippers starts a 3-second buildup. It has a rising sound, a charge ring around the ship, the DMD counting up and the screen tinting. Releasing either flipper early cancels it with no cost. While charging, the ship can't move (both buttons are held), which makes the bomb a deliberate risk.
- Stages are built for a ship that only moves sideways. Enemy patterns and bullets are dodged left and right, and some lanes can be blocked.
- **How the game knows 2 vs 4 buttons:** the operator setting `operator.cabinet_buttons` is `auto`, `2` or `4`.
  - With `auto` (the default), the game starts in auto-fire. The first time a magna save is pressed, it switches to manual fire for the rest of that game.
  - The DMD shows "MANUAL FIRE" when it switches.
  - *Proposal; confirm.*

**Mechanics:** weapon levels from power-up pickups, plus sub-weapons, and a scoring medal chain. 5 stages, each with a mid-boss and a boss. Big bosses are shown on the BACKGLASS during their intro.
**Art direction [PROPOSAL]:** pre-rendered-look 3D planes with a toon shader, over parallax sprite terrain.

### 5.3 TURBO RUN — super-scaler racer — [PROPOSAL] (M4)
**Genre feel:** a sprite-scaled pseudo-3D road with hills, curves and route forks, plus an optional pursuit mode.

**Controls**
| Input | Action |
|---|---|
| Flippers (hold) | Steer left / right |
| Throttle | **Automatic** |
| Both flippers | Brake |
| Launch | Turbo (limited charges, refilled at checkpoints) |
| Magna L/R (opt.) | Pursuit mode: ram / lane switch. Race mode: shift low/high |

**Mechanics:** checkpoint timer, time extensions and route forks (choose by steering at the fork). Pursuit mode: catch the target car and ram it until its damage bar is full.
**Portrait layout:** the road view takes the top ~70% of TABLE. The bottom shows the rear-view mirror, minimap and speed.
**Art direction [PROPOSAL]:** classic super-scaler. Roadside objects and cars are billboard sprites (AI-generated, or pre-rendered from 3D). The road is drawn with a segment-projection renderer. Sunset palettes.
**Technical risk:** the road renderer. Prototype it early in M4 as a spike.

## 6. Roadmap
| Milestone | Content |
|---|---|
| **M0** ✅ | Repo, docs, bootable 3-window shell, game stubs, tests |
| **M1** ✅ | Core shell: operator menu, Display Setup wizard, remapping, attract mode, high scores, credits, audio buses, DMD API and pixel font. Still to do: music playback in attract, per-game attract demos (they need real games) |
| **M2** | Block Breaker vertical slice: one complete world, then all of it |
| **M3** | Sky Striker |
| **M4** | Turbo Run (road renderer spike first) |
| **M5** | Hardware DMD (dmdserver), frontend integration docs, export presets, Win/Linux packages |
| **M6** | Art and audio pass, language files |

## 7. Open questions
1. Final names for the bundle and each game (director is thinking about it).
2. Sky Striker: is the `cabinet_buttons = auto` switch to manual fire OK? (§5.2)
3. Block Breaker: should the paddle behave differently in stages with flippers? (§5.1, decide in playtests)
4. Should multiplayer work like pinball (players take turns)? The shell is ready for `start(players)`.
5. Should nudge or an analog plunger be used at all (they aren't guaranteed)?

## 8. Asset pipeline
### 3D models (D-020)
- **Source:** Meshy. Export **.glb** with PBR textures, and use Meshy's remesh or reduced polycount.
- **Location:** `assets/models/<breakout|shmup|racer|shared>/<snake_case_name>.glb`. Commit it, and Git LFS handles the file.
- **Polycount budgets** (initial; to revise after profiling on the cabinet):
  - Hero objects (player ship, paddle, player car): ≤ 15k triangles
  - Enemies and props: ≤ 5k triangles
  - Bosses: ≤ 40k triangles
- **Textures:** 1024² by default, 2048² for bosses and hero objects only.
- **Look:** the GLB's own materials are the base. Each game's style (outline, cel bands, retro dithering) is a shader applied in code.
- **Sprites from 3D:** super-scaler sprites, such as racer roadside objects and cars seen from fixed angles, may be pre-rendered from GLBs into sprite sheets by a headless Godot script. They don't need to be drawn by hand.
- **Credits:** add one row per file to `assets/CREDITS.md`.

### 2D art, audio, fonts
These are AI-generated or royalty-free, and each needs a row in `assets/CREDITS.md`. Their file formats will be decided in M1 and M6.
