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
6. **Stable screens (D-352).** Adding, removing or changing UI elements during play must never make other elements on screen move or drift. Players expect consistency: things appear and disappear in place (blink with `modulate.a`, reserve their space, overlay instead of reflowing).

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
| Ball start / max speed | 8.5 → 13.5 u/s (Normal) | +0.25 per ship hit (max after about 20 returns, D-054); see Difficulty |
| Paddle return angle | up to 60° from vertical | by hit position, plus a little paddle "english" |
| Auto-serve | 6 s | the ball launches by itself if Launch isn't pressed |

**Difficulty (D-182):** after PRESS START the player picks EASY, NORMAL or HARD (flippers choose, LAUNCH goes; the last choice is remembered, and NORMAL is the first default).
| Difficulty | Ball start → max | Lives |
|---|---|---|
| Easy | 6.8 → 11.5 u/s | operator balls + 2 (5 by default) |
| Normal | 8.5 → 13.5 u/s | operator balls (3) |
| Hard | 10.0 → 15.5 u/s | operator balls − 1, at least 1 (2) |

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

  Each level plays a rising charge tone, then a warm **hum** when reached. Each level needs ⅓ of the power bar to be available, and charging stops at the highest level you can afford; with an empty bar you hear "LOW POWER". Releasing fires a bolt straight up in that level's colour: a level-n bolt is bigger and punches through up to **n** bricks or enemies (one plasma hit each) before dissolving, and it costs n/3 of the bar. Power recharges slowly from 1 s after the last blast (full in about 15 s). Losing a life refills the bar (D-102). The ship can't move while charging.
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
- **Drops (D-329):** every 8th brick destroyed has a 70% chance to drop a capsule. Blaster and paddle upgrades take turns; 1UP or Nuclear replaces a drop 4% of the time (D-341). A capsule just below the ship can still be caught.
- **Power-up slots (D-327):** two kinds, held at once: **blaster upgrades** (sphere capsules with orbiting electrons: T P B I W H) charge to level 1 only and use 1 cell (T, P) or the full bar (B, I, W, H) per shot; **paddle upgrades** (spinning pill capsules: S L K) use no energy. Catching a capsule pops its name up from the catch point. **W** Wave Beam: a snaking shot that hits each brick on its way once and is never stopped. **H** Homing Missile: flies to the nearest enemy or brick; its blast hits a 3×3-brick area three times. **K** Sidekicks: two mini ships dock at the ship's sides and widen its catch. (The per-kind rules below are from before D-327.)
- **Power-ups (D-072):** every 10th brick destroyed has a 70 % chance to drop a capsule (glossy coloured sphere, letter, two orbiting electrons). Catch it with the ship: it also refills one bar level (D-078). One at a time; lasts until the level ends or you die. The DMD shows its letter next to the power bar, and the bar takes its colour.
  - **T** (blue) Triple laser: the charged shot fires 3 bolts, straight up and at ±20° (D-078).
  - **P** (red) Power laser: charges straight to level 3 in one phase, with only the level-3 effects.
  - **B** (yellow) Bounce plasma: the shot is an extra plasma ball that rebounds like the main one; 1 level, full bar. A life is only lost once every ball has sunk.
  - **I** (purple) Ion cannon: level 3 only, full bar; an instant beam fries the one brick column straight above the ship (D-078).
  - **L** (white) Lightspeed: no shot, no bar; the ship is 30 % faster and leaves two afterimages that also bounce the plasma.
  - **S** (green) Shield: no shot, no bar; a green barrier at the bottom saves one sinking ball, then you return to the normal plasma cannon (D-084).
  - **1UP** (pink, reads "1UP") and **Nuclear** (orange, atom symbol) are rarer (about a third as likely as the others) and act at once (D-326): 1UP adds a charge; Nuclear flashes the screen white and destroys every brick (not metal), clearing the level.
  - The ship never blocks a ball rising from below.
- **Charged shot (D-074..D-076):** reaching the maximum level fires automatically. With an empty bar, "LOW" shows only in the DMD bar area, and only after both flippers are held for more than 0.5 s. The bar is full at the start of every level. The ship flashes yellow each time the bar recharges a level (each third; only when full for Bounce and Ion) (D-084).
- **Bricks (D-073):** UPPERCASE = 1 hit; lowercase = armoured (2 hits, glowing frame, cracks after the first hit, 1.5× points); `X` = indestructible metal (doesn't count towards clearing).
- **Levels 1–10 (D-073):** rows, pyramid, checkerboard, eye (first armour), metal-core towers, diamond, funnel, twin fortresses, armour weave, hive mind. Every 5 levels enemies get +40 % speed, spawn more often, one more can be on screen, and their orbits steer towards the ship.
- **Level-change boost (D-076):** "LEVEL CLEAR!" shows first, then the ship glides to the centre and levels out, and lifts off as the DMD plays the pixel ship boosting away (D-085).
- **Cube enemy (D-323, D-324):** from level 3, about a third of enemies are cubes in the same circuit style; they drift towards the nearest ship while sweeping, descend faster and follow the ship at the bottom.
- **Unstuck (D-323):** an enemy that hasn't got lower for 10 s starts circling from a 12 o'clock heading, hugging and going over the bricks that hold it, then resumes its sweep once lower.
- **Proximity alert (D-322):** while an enemy is in the bottom 20% of the screen, "⚠ DANGER ⚠ / PROXIMITY ALERT" blinks in see-through red in the middle of the play area, until it moves away or is destroyed.
- **Extra charge (D-321):** one extra charge (life) at **20,000** and one at **50,000** points: a jingle, "EXTRA CHARGE!" on the DMD and a new charge dot. The attract DMD shows "EXTRA CHARGE AT 20,000 50,000".
- **Boss (D-335):** level 10 (every 10th) has a boss: a spinning see-through icosahedron with a red HAL eye, roaming above the bricks. Every 10–15 s it charges (red sparks into the eye) and fires a slow ray at the ship that passes through bricks; only the plasma ball stops it, and it costs a charge if it hits. 45 HP (D-340; ball 1, bolts by level, wave 2, missile 3, ion 3), shown by the eye's colour: blue, green, yellow, orange, red (D-338), 5000 points; the level ends when the bricks and the boss are both gone.
- **Levels 11–20 (D-342):** new content. **Charged bricks** (red, pulsing; first hit fires a torpedo straight down) from 11; **plasma bricks** (a captured ball, freed as an extra ball when broken); **mini-icosahedrons** (enemy-sized, fire small torpedoes at the ship) from 11; **corrupted paddles** (a dark ship with a red eye that warps in 35% down the field, slides side to side, blocks the plasma; 10 ball hits or 5 weapon hits) from 15; level 20's boss is a **dodecahedron** that fires three torpedoes in a fan. Torpedoes pass through bricks; only the plasma stops them. Bosses glow red where they're hit.
- **Space backdrop (D-343):** levels 11–20 swap the horizon for Earth in the bottom-left corner (its curve under the ship), a grey moon slowly orbiting at the top right, and dimmed alien ships crossing far behind with thruster trails.
- **Start level (D-336):** after 1 PLAYER / 2 PLAYERS, choose the starting level (1–20, D-342) with the flippers, then the difficulty.
- **Game over (D-044):** when the last charge is lost, the explosion grows until it fills the whole screen, with a bigger, longer blast. The screen fades to black, then **GAME OVER** and the **final score** show on the TABLE, DMD and backglass. After about 4 s (or Launch/Start to skip) the game goes to high-score entry or back to the picker.

**2 players (D-285, D-286).** Available only on a single landscape screen with a keyboard or gamepads (D-284). After PRESS START, players choose 1 PLAYER or 2 PLAYERS, then the difficulty.
- **Field:** wider, with 19-column levels (`levels/level2p_*.txt`).
- **Ships:** two, P2's flying slightly higher, so they pass each other. Each has its own power-up and energy bar (at the bottom corners of the TABLE, and both on the DMD, D-287).
- **Shared:** one ball, the lives and the score. A drain costs a shared life and passes the serve to the other player.
- **Controls:** P1 uses the arrows, Space and Ctrl, or their own pad. P2 uses A/D (move), W (launch) and Q/E (dash), or their own pad.


### 5.2 SKY STRIKER — vertical shmup (TATE) (M3)

*Hidden from the picker, attract and operator menu until it has something to show (D-184); `--game=shmup` still opens it.*
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
- **Road:** real 3D, not sprite scaling. It is an endless seeded road made of sections: straights, sweepers, medium curves and hairpins, with hills and dips. 4 lanes with kerbs, sand and grass, drawn with a 16-bit texel shader. Low-poly "PS2" props: palms, rocks, lamps and chevron signs on the outside of curves. Mountains on the horizon. **Cars (D-205, D-210):** easy is the director's red hot hatch (D-206), with its twin exhausts on the left; normal is the sports car in green; hard is the director's yellow supercar, with twin pipes each side. The hot hatch also drives in the traffic. **Double roll (D-206):** hitting a big obstacle at 100 mph or more rolls the car over twice, with a higher hop. **Finish line (D-221):** the end of stage 10 is the finish: a chequered gate and stripe across the road. Crossing it ends the race with a 100,000 finish bonus plus 2,000 per second left on the clock; the car drift-brakes to a stop, swinging about 75° sideways in a cloud of tyre smoke (D-222), and the results say FINISH! with the time bonus. **Finish town (D-229):** the last 600 m before the line run through a small snowy town (chalets and town houses close on both sides, street lamps, a flat road), with groups of cheering spectators lining both kerbs over the last 260 m and just past the line. **Areas (D-216, order D-225):** 1–2 beach, 3–4 forest, 5 desert, 6–7 city, 8 fields, 9–10 snowy mountain (the finish); each cross-fades into the next over the last 200 m. Time of day: day 1–3, sunset 4–5, night 6–8, dawn 9–10. The city (at night) has tall dark buildings full of lit rooms (warm, cool and TV-blue, whole office floors in the glass towers), lit shopfronts, starburst street lamps and glowing traffic lights, a sidewalk barrier, and cross-street junctions with zebra crossings. The desert has cacti, dry shrubs, dunes and distant buttes; the forest is lined with tall walls of pines; the snowy mountain has snow-laden spruces, snowy boulders and steep slopes. A START STAGE screen (for testing) after GRAPHICS picks the stage the race starts at. **Weather (D-217, D-219):** random per race: spells start at random places and last at least 1.4 km (up to 3 km), with clear gaps between. Each is a kind that suits the area (rain or fog in town, the fields, the forest and on the beach; dust haze in the desert; snow or fog on the mountain), and it fades where the road leaves the areas it suits. Overcast skies, closer fog and dimmer sun; rain streaks, a rain hiss, a wet, shiny road and puddles with screen-space reflections (cars, lamps, signs and buildings mirrored in the water, D-225); drifting snowflakes; sandy haze. Nothing falls in tunnels. **Stage scenery (D-204):** stage 1 is a beach: sand and the sea on the left (rolling foam, a waterline washing in and out), a flat-ish road, small beach houses and a surf shop on the right, palms, the odd lifeguard tower; it blends into grass fields over the last 200 m. Stage 2's fields have oaks and cypresses instead of palms. **Time of day (D-193):** a procedural sky with one sun that moves with the race: stages 1–3 daylight (the sun coming down from about 48°), stages 4–5 golden hour and sunset (it sets late in stage 5, ahead of the road's start), stages 6–8 night (moon and stars, headlights), and dawn in stages 9–10 (D-225). **Music (D-301, D-439):** the song picked on the radio plays for the whole run; the five stations are the director's own tracks. The sky, clouds, mountains, light, ambient and fog all follow the sun's elevation.
- **Graphics (D-195, D-207):** after Start, a GRAPHICS screen offers 8-BIT (270×480, a fixed 54-colour console-style palette with dithering), 16-BIT (the 480×854 pixel look) or HD (native resolution, high-res sprites and car textures, smooth filtering, 4× MSAA). Flippers step through them and the road behind switches live; Launch confirms, and the choice is remembered (16-BIT by default). Animations (car angles, roll-overs, spins, wheels, pickup bob, showroom turntable) step like sprite frames in 8-BIT, with twice as many steps in 16-BIT, and are fully smooth in HD (D-208).
- **Car select (D-122):** after Start, three cars spin on turntables: red EASY (259 km/h, high grip), yellow NORMAL (288 km/h) and blue HARD (317 km/h, slides wide). Their stats show on a card beside each car (top speed, cornering and time as 5-segment bars with values, D-185) and on the DMD. Flippers choose, Launch/Start confirms, and after 15 s the highlighted car is taken.
- **Controls:**
  - Flippers steer.
  - **2+1:** throttle and braking are automatic. The car brakes by itself when a corner would throw it off and it isn't drifting.
  - **4+1 (D-189):** the throttle stays automatic. Magna R is the **shifter** (one press flips L ↔ H) and magna L **brakes** (no auto-brake then; brake + steer still flicks into a drift). The flippers steer and rev on the grid as in 2+1. This switches on at the first magna press when `operator.cabinet_buttons` = auto (and stays on for the session), and is always on when it is 4.
  - **Gears (D-103):** with 2+1 buttons, holding **both flippers for 0.5 s shifts L ↔ H** (with 4+1, the magna R shifter does). L pulls hard but tops out at 180 km/h. H is slow off the line but reaches 288 km/h. Shift up when the tachometer hits the red (SHIFT blinks), and drop to L after a crash.
  - **NITRO (D-103):** drive through a nitro canister on the road for 5 s of boost (up to 360 km/h). Canisters sit in any lane, including the oncoming ones, every 0.7–1.2 km.
  - Launch/Start begins the race.
- **Drifting (the core skill):**
  - Steer *into* a corner at more than about 150 km/h to break loose. In manual mode, brake plus steer also starts a drift.
  - The car slides nose-in, keeps almost all its speed, smokes and scores drift points.
  - Letting go of the steering ends the drift and banks the points. Not drifting through a hairpin costs speed.
- **Clock:** set by the car (D-183). EASY 55 s to start, NORMAL 45 s, HARD 40 s. A checkpoint every 2.3 km (D-101) adds time, falling 2 s per checkpoint: NORMAL from +34 s to a minimum of +20 s, EASY +10 s more (+44 to +30, D-187), HARD 4 s less (+30 to +16). TIME UP ends the game, unless the coasting car still reaches the next checkpoint: then the time is added and the race goes on (D-103).
- **Traffic:** slower cars in the lanes, more after each checkpoint. Rear-ending one at speed spins you out, a light touch is a bump, and passing close is a NEAR MISS (+5,000).
- **Roadside objects:** palms, rocks, lamps and signs crash you if you leave the road.
- **Score:** distance, drift points, near misses, passes and checkpoints.
- **Dashboard (D-103):** the bottom of the TABLE shows a tachometer, a gear box and a speedometer, drawn as segmented dials in the director's reference style. The DMD shows a segmented speed dial, digital speed, score, gear box, clock and a horizontal tachometer bar.
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

**Radio (D-301).** After car select, a 16-bit car-stereo screen picks the music: a tuning dial with a sliding needle, the title scrolling on an LCD over a graphic equaliser, five presets. The chosen song plays for the whole run (the director's own tracks since D-439).

**2 players (D-288, D-289).** Available only on a single landscape screen with a keyboard or gamepads (D-284). After PRESS START, players choose 1 PLAYER or 2 PLAYERS. Each player then picks a car (P1 first, then P2) after the graphics and stage screens.
- **Screen:** split side by side. Each half has its own camera and HUD, with POSITION (1ST/2ND) where the clock was. Each player sees the other's car, and the cars bump each other. While the other car is ahead and in sight, a red P1/P2 tag with a down triangle marks it (D-290).
- **Race:** no time limit. The first to the end of stage 10 wins; the race ends when both have stopped, or 8 s after the winner crosses. There's no high-score entry.
- **Shared:** traffic, which reacts to both cars.
- **Per player:** police chases, nitro canisters, weather and time of day (each half shows its own stage's sky, sun and fog).
- **DMD:** each player has their own DMD at the top of their half, with the full 1P content (D-291). There are no radar lights. At the bottom right of each half: a half-size speedo (full-size text), smaller gears beside it, and the tachometer as a yellow/green/red bar under the speedo (D-293).
- **Controls:** P1 uses the arrows, Space and Ctrl, or their own pad. P2 uses A/D (steer), W (launch) and Q/E (brake / shift), or their own pad.

**Pursuit (D-460).** A 1-player mode, the third choice after 1 PLAYER / 2 PLAYERS (the menu now always shows, with 2 PLAYERS only where possible). The player drives the police car after a speeding car.
- **Menus (D-476: graphics first, then the mode):** graphics, then 1 PLAYER / 2 PLAYERS / PURSUIT, then CHOOSE YOUR TARGET (the three race cars are the difficulty; each card shows how many rams stop it, and its paint is the speeder's), then the radio. No start-stage menu.
- **Road:** no checkpoints or gates, no START banner (D-466); the stages loop (after the two snow stages, a forest stage, then the beach of stage 1 again), with the day running round with them. No speed cameras, no finish town.
- **Clock:** 90 s; reaching each speeder (the chase coming on) adds 30 s, like a checkpoint (D-465), and stopping it adds 60 s. The run ends when time is up.
- **The chase:** the speeder starts 800 m ahead (the next ones 1,000 m), cruising at 0.78 of its top (D-465); the player closes in flat out with nitro. Within 160 m the chase is on: lights and siren, IN PURSUIT!, the chase theme, and traffic pulls over. The speeder then drives a little under the police car's top speed (D-463): flat out the player gains slowly, with nitro much faster; it slows for bends like the player, and waits if it gets more than 90 m ahead, so it stays in sight. If the player crashes, it gets away for a while. A red arrow bounces on it the first time the player gets within 45 m (D-464). Nitro can't carry the police car far past it. Past 450 m the chase is off (SUSPECT LOST) until the player closes in again.
- **Stopping it:** ram it (from behind or the side) to fill its damage meter; it smokes from half damage. At 100 % it's wrecked: BUSTED! and +60 s; it stops in its lane, the police car drives round it and parks across the lane in front, the fine (the points), then it turns back into the road and the clock runs again (D-466). The police radio then calls in the next speeder, 1,000 m up the road.
- **Police radio (D-466):** at the start and after each bust, the DMD shows a radio with DISPATCH and a scrolling call: the speeder's colour and kind and the speed it was clocked at.
- **HUD:** SUSPECT and the distance (feet up close, miles further off), and the damage meter during the chase. The DMD shows the police car and the speeder side on at the real gap, with the damage bar.

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
| Tilt Breaker: game music | "Tilt Breaker" (original theme); "Tilt Breaker 2" for levels 11–20; "Earth's End" at game over | The director | Director-made | ✅ In game (D-318, D-320, D-362; n-Dimensions removed, D-439) |
| Turbo Run (racer): attract, radio stations, chase, jingles | Start Your Engines (attract); radio: Turbo Run, Full Throttle, Turbo Run (Out of the Park Mix), High Tide, Abrupt Cutoff; In Pursuit (chase); Racing Goal, Time Over | The director | Director-made | ✅ In game (Bogart VGM songs removed, D-439) |
| Game selection menu | "Start Menu" | The director | Director-made | ✅ In game (D-403) |
