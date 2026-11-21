# PinGames — Game Design Document

> Living document. Sections marked **[PROPOSAL]** wait for the director's approval.
> When a proposal is approved or changed, update it here and log a decision in `DECISIONS.md`.
> Names: **TILT BREAKER** is chosen (D-037). SKY STRIKER and TURBO RUN are still working titles.

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
| `flip_l` / `flip_r` | Left/Right arrow · L1/R1 | Yes | Move / steer / choose |
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

### 5.1 TILT BREAKER (block breaker) — first vertical slice (M2)
**Genre feel:** paddle-and-ball brick breaking with capsule power-ups, which fits a portrait playfield naturally.

**Controls**
| Input | Action |
|---|---|
| Flippers (hold) | Move the ship left / right. Speed ramps up while held. |
| Launch (or Start) | Fire the plasma shot; fire lasers when that power-up is active |
| Both flippers (hold 1 s, release) | Energy blast straight up (costs ⅓ power); also releases a caught ball (magnet power-up) |
| Magna L/R (opt.) | Dash: a quick engine burst in that direction |

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

**Tuning (M2 step 1, in `games/breakout/sim.gd`; numbers are in playfield units, which are 9 wide × 16 tall):**
| Setting | Value | Meaning |
|---|---|---|
| Paddle width | 1.5 | about 1/6 of the playfield |
| Ship line / drain line | z = 5.9 / 7.3 | the plasma is lost once it passes the planet's horizon |
| Paddle top speed / accel / stop | 11 / 70 / 90 per s | crosses the field in ~0.8 s |
| Dash (magna save) | 26 u/s for 0.12 s, 0.6 s cooldown | |
| Ball start / max speed | 8.5 → 13.5 u/s | +0.25 per ship hit (max after about 20 returns, D-054) |
| Paddle return angle | up to 60° from vertical | by hit position, plus a little paddle "english" |
| Auto-serve | 6 s | the ball launches by itself if Launch isn't pressed |

**Camera:** orthographic, leaning 20° towards the player (D-040).

**DMD:** score, charges, "MULTIBALL!", power-up names, brick count left.
**Backglass (D-058):** the director's art (the ship firing plasma at nanomachine pyramids above the planet). Four light groups blink with game events: the **title logo** (steady in play, blinking slowly in attract, flickering in alarms and chases), **engine flames** (breathing at idle, brighter with ship speed), **plasma comets** (flash on firing, shield rebounds and blast charging) and **impacts/lightning** (flicker on brick and enemy kills and blast hits). Everything blinks like an alarm on a lost charge or ship, the groups run a chase on rack clear, and the lights go dark at game over.
**Fiction and art direction (director, D-041):**
- **The bricks** are a sentient, self-replicating alien race of nanomachines (D-045). Each brick is a unique rectangle cut from a random spot of the director's 16-bit circuit textures (red, yellow, green and blue; rows are currently red, red, yellow, green, blue, blue until stage layouts arrive), shown as chunky low-res pixels with a 1-texel bevel. Their lit LEDs and traces pulse in waves across the swarm. Destroyed bricks blow up in a **solid fireball in the brick's colour** (white-hot core, billowing edge) and throw tumbling brick-coloured shards (D-087, replacing the pixel-art blast of D-046).
- **The player** flies a spaceship (the paddle, `paddle.glb`).
  - It **banks** up to about 18° when moving. The hitbox stays a fixed rectangle.
  - The side engines are **afterburners** (D-042). Both are off at rest. While moving, only the trailing one burns: a cone of blue flame, white-hot at the nozzle and tapering to a point, that grows with speed and flares on a dash.
- **The ball** is a **plasma shot**. It is invisible until fired. Launch or Start fires it from the ship, with a firing sound, a muzzle flash and a recoil kick and shake of the ship (D-042). In flight it has a white-hot core, a swirling halo, electric arcs and a fading trail.
- **Rebounds:** the ship's **energy shield** flashes in front of the hull, with a ripple from the impact point, and deflects the plasma back at the swarm.
- **Lives** are the ship's **energy charges**. Losing one says "CHARGE LOST".
- **Status only on the DMD (D-051):** big score, the remaining charges as plasma dots, and the blast power bar (3 cells). The TABLE has no HUD, and the backglass shows the title art.
- **Energy blast (D-051, D-053, D-054):** only while the plasma is in play (not while waiting to fire it). Hold **both flippers** to charge in up to **3 levels**, 0.68 s each (D-056):
  - **Level 1:** blue particles gather in front of the ship, then a small blue sphere appears.
  - **Level 2:** yellow particles, then a medium yellow sphere.
  - **Level 3:** red particles, then a full-size red sphere.

  Each level plays a rising charge tone, then a warm **hum** when reached. Each level needs ⅓ of the power bar to be available, and charging stops at the highest level you can afford; with an empty bar you hear "LOW POWER". Releasing fires a bolt straight up in that level's colour: a level-n bolt is bigger and punches through up to **n** bricks or enemies (one plasma hit each) before dissolving, and it costs n/3 of the bar. Power recharges slowly from 1 s after the last blast (full in about 15 s). The ship can't move while charging.
- **Sound (D-050):** 16-bit-era effects synthesized in code (pulse waves, LFSR noise, arpeggios, vibrato, SNES-style echo).
- **Setting (D-043):** the ship is in orbit. The horizon of an **earth-like planet** runs across the bottom of the TABLE: so huge that its curve is barely visible, out of focus (soft, low-detail shading), with a glowing atmospheric rim and haze. It has oceans, continents and drifting clouds. Plasma that gets past the ship falls past the horizon: an **explosion sound**, a **fireball**, and the planet's surface **lights up where it would have hit**, with a shockwave spreading along the horizon. The ship sits higher to make room.
- **Space (D-049):** a pixel-art starfield (three parallax layers of square stars that twinkle) fills the background. It swings around a pivot far below the screen as the ship moves, like the ship moving along its orbit. There are **no visible walls**: invisible boundaries sit a little inside the screen edges, and a rebound there flashes an energy shield (the same effect as the ship's) where the plasma hits.
- **Enemy: tetrahedron (D-052, D-053).** A small polygonal tetrahedron, about one brick wide (the director asked for 50% smaller). Its faces use crops of a **single circuit colour per enemy**, with edges glowing in the same colour, and it tumbles in 3D.
  - **Arrival:** it teleports in through a swirling **wormhole** in the top 10% of the screen and can't be hit while emerging.
  - **Movement:** wide horizontal sine sweeps, slowly descending. It needs a gap through the bricks at least as wide as itself (a single missing brick is enough) to get down; otherwise it stays in the top area.
  - **At the ship's height:** it flies wide elliptical circles around the bottom, which may or may not cross the ship.
  - **Destroyed by** plasma attacks: the ball (which rebounds off it) and energy blasts (which dissolve on it). Fireball explosion (D-083), 500 points.
  - **Touching the ship destroys the ship** (one charge lost) and the enemy self-destructs. The ship respawns blinking and is invulnerable for 2 s. Losing the last charge this way triggers the game-over finale.
  - **Spawning:** the first arrives about 10 s into play, then one every 14–22 s, **at most 2 on screen at a time**.
- **DMD pixel animations (D-056):** short clips (about 1.3–1.8 s) over the DMD status. **Tetra shot down:** the ball hits a spinning wireframe tetra, which explodes, with "+500". **Enemy incoming:** a vortex opens and a tetra emerges, with "INCOMING". **Charge lost:** the ball falls onto the planet, with a blast dome. **Ship destroyed:** a tetra dives into the pixel ship. **Rack clear:** a mini brick wall pops apart, with "+1000".
- **Logos (D-063):** the game list shows the Tilt Breaker logo in place of its name (large when selected, small and dimmed otherwise), and the backglass shows it while the game is selected. The DMD shows a 70×32 pixel-art version of the horizontal logo; in attract it drops in, a glint sweeps across, then it sparkles.
- **Attract and intro (D-061):** the game opens in its own **attract mode**. The TABLE shows the title and a blinking PRESS START over the planet and stars. The DMD cycles the title and PRESS START, the top-5 high scores, and pixel animations. **Start** (or Launch) plays a jingle and shows **GET READY** on the DMD and in the middle of the TABLE. The **wall forms**: bricks drop in one after another, top row first, falling in 3D from above and settling with a bounce. Then the **ship blasts up** from below the screen on a downward **belly afterburner** and settles into place. Play begins with PLASMA CANNON READY.
- **Levels (D-068):** stages are text files in `games/breakout/levels/`, one character per brick (R/Y/G/B = colour, `.` = empty, `#` = comment line), up to 11 columns × 10 rows. **Level 1** is 4 rows of 11 (44 bricks). **Level 2** is a stepped nanomachine **pyramid**. After the last file the levels loop.
- **Level complete (D-068):** every enemy on screen explodes and the DMD plays "LEVEL CLEAR! +1000". The ship **flies away** up the screen and toward the viewer (rising, growing, pitching) on its belly afterburner. The screen **fades to black**, then the next level loads with the same intro (bricks drop in, ship blasts in) and "LEVEL n".
- **Power-ups (D-072):** every 10th brick destroyed has a 70 % chance to drop a capsule (glossy coloured sphere, letter, two orbiting electrons). Catch it with the ship: it also refills one bar level (D-078). One at a time; lasts until the level ends or you die. The DMD shows its letter next to the power bar, and the bar takes its colour.
  - **T** (blue) Triple laser: the charged shot fires 3 bolts, straight up and at ±20° (D-078).
  - **P** (red) Power laser: charges straight to level 3 in one phase, with only the level-3 effects.
  - **B** (yellow) Bounce plasma: the shot is an extra plasma ball that rebounds like the main one; 1 level, full bar. A life is only lost once every ball has sunk.
  - **I** (purple) Ion cannon: level 3 only, full bar; an instant beam fries the one brick column straight above the ship (D-078).
  - **L** (white) Lightspeed: no shot, no bar; the ship is 30 % faster and leaves two afterimages that also bounce the plasma.
  - **S** (green) Shield: no shot, no bar; a green barrier at the bottom saves one sinking ball, then you return to the normal plasma cannon (D-084).
  - The ship never blocks a ball rising from below.
- **Charged shot (D-074..D-076):** reaching the maximum level fires automatically. With an empty bar, "LOW" shows only in the DMD bar area, and only after both flippers are held for more than 0.5 s. The bar is full at the start of every level. The ship flashes yellow each time the bar recharges a level (each third; only when full for Bounce and Ion) (D-084).
- **Bricks (D-073):** UPPERCASE = 1 hit; lowercase = armoured (2 hits, glowing frame, cracks after the first hit, 1.5× points); `X` = indestructible metal (doesn't count towards clearing).
- **Levels 1–10 (D-073):** rows, pyramid, checkerboard, eye (first armour), metal-core towers, diamond, funnel, twin fortresses, armour weave, hive mind. Every 5 levels enemies get +40 % speed, spawn more often, one more can be on screen, and their orbits steer towards the ship.
- **Level-change boost (D-076):** "LEVEL CLEAR!" shows first, then the ship glides to the centre and levels out, and lifts off as the DMD plays the pixel ship boosting away (D-085).
- **Game over (D-044):** when the last charge is lost, the explosion grows until it fills the whole screen, with a bigger, longer blast. The screen fades to black, then **GAME OVER** and the **final score** show on the TABLE, DMD and backglass. After about 4 s (or Launch/Start to skip) the game goes to high-score entry or back to the picker.

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

**Prototype (D-089), playable:**
- **Road:** real 3D, not sprite scaling. It is an endless seeded road made of sections: straights, sweepers, medium curves and hairpins, with hills and dips. 4 lanes with kerbs, sand and grass, drawn with a 16-bit texel shader. Low-poly "PS2" props: palms, rocks, lamps and chevron signs on the outside of curves. Mountains on the horizon, sunset sky.
- **Controls:**
  - Flippers steer.
  - **2+1:** throttle and braking are automatic. The car brakes by itself when a corner would throw it off and it isn't drifting.
  - **4+1:** magna R = accelerate, magna L = brake. This switches on at the first magna press when `operator.cabinet_buttons` = auto, and is always on when it is 4.
  - Holding **both flippers burns NITRO** from a bar for as long as they are held (a full bar lasts 4 s). The bar refills by itself when not in use (14 s from empty, after a 1 s pause), faster while drifting, and +30 % per checkpoint (D-097).
  - Launch/Start begins the race.
- **Drifting (the core skill):**
  - Steer *into* a corner at more than about 150 km/h to break loose. In manual mode, brake plus steer also starts a drift.
  - The car slides nose-in, keeps almost all its speed, smokes and scores drift points.
  - Letting go of the steering ends the drift and banks the points. Not drifting through a hairpin costs speed.
- **Clock:** 45 s to start. A checkpoint every 1.8 km adds time, from +34 s down to a minimum of +20 s. TIME UP ends the game.
- **Traffic:** slower cars in the lanes, more after each checkpoint. Rear-ending one at speed spins you out, a light touch is a bump, and passing close is a NEAR MISS (+5,000).
- **Roadside objects:** palms, rocks, lamps and signs crash you if you leave the road.
- **Score:** distance, drift points, near misses, passes and checkpoints.
- **Not done yet:**
  - Route forks
  - Rear-view mirror or minimap in the bottom of the TABLE
  - Backglass art
  - DMD animations
  - Stage palettes
  - Attract high-score pages

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
1. Final names for the bundle, the shmup and the racer. The block breaker is TILT BREAKER (D-037).
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

### Music assignments (director's picks; license must be confirmed on each page before import, D-032)
| Use | Track | Source | License (from search summary, unverified) | Status |
|---|---|---|---|---|
| Main screen (picker; attract if "attract sounds" is on) | "Legends" by KLY (Kim Lightyear) | https://opengameart.org/content/legends | CC BY 3.0 (confirmed). Credit "Kim Lightyear (KLY)" by name, including in the store/project description | ✅ In game |
| Tilt Breaker: attract mode | "My Very Own Dead Ship" by yd | https://opengameart.org/content/background-space-track | CC0 (confirmed by the director) | ✅ In game (D-082) |
| Tilt Breaker: game music (intro and play) | "n-Dimensions (Main Theme - Retro Version)" by Matthew Pablo | https://opengameart.org/content/space-dimensions-8bitretro-version | CC BY 3.0 (confirmed by the director). Credit "Matthew Pablo" | ✅ In game (D-081) |
| Turbo Run (racer): menu + 5 race loops | "8-bit Music Pack (Loopable)" by CodeManu | https://opengameart.org/content/8-bit-music-pack-loopable | CC BY 3.0 | ✅ In game (racer stub plays race loop 1) |
