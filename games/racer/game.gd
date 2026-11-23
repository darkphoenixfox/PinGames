## TURBO RUN (D-089): arcade road racer prototype. Race the clock through
## checkpoints on an endless seeded road with curves and hills, traffic and
## roadside obstacles. Emphasis on drifting through corners.
## The pure race logic is in sim.gd / track.gd; this module draws it in 3D on
## the TABLE (low-poly "PS2" props, 16-bit textures), with DMD + BACKGLASS.
## Controls (D-007, D-089):
##   flippers = steer (and rev on the grid); throttle automatic in both layouts
##   2+1 buttons: hold both flippers 0.5 s = shift gear L <-> H (D-103), auto-brake
##   4+1 buttons (D-189): magna_r = shifter (one press flips L <-> H),
##   magna_l = brake; switches on at the first magna press when
##   operator.cabinet_buttons = auto, always on when = 4
##   NITRO = drive through a canister on the road (5 s boost, D-103)
extends "res://core/game_module.gd"

const InstParam = preload("res://core/util/inst_param.gd")

const Sim = preload("res://games/racer/sim.gd")
const Track = preload("res://games/racer/track.gd")
const Scenery = preload("res://games/racer/scenery.gd")
const City = preload("res://games/racer/city.gd")   # D-216
const DotText = preload("res://core/ui/dot_text.gd")   # D-233
const Weather = preload("res://games/racer/weather.gd")   # D-217
const PUDDLE_SHADER = preload("res://games/racer/shaders/puddles.gdshader")
## Weather looks (D-217): fog [begin, end] m at full strength per kind, and
## the haze's sandy fog colour.
const WEATHER_FOG := {"rain": Vector2(90.0, 430.0), "snow": Vector2(45.0, 320.0),
	"fog": Vector2(12.0, 160.0), "haze": Vector2(60.0, 380.0)}
const HAZE_COL := Color(0.84, 0.68, 0.48)
const Toon = preload("res://games/racer/toon.gd")
const Sprites = preload("res://games/racer/sprites.gd")
const Night = preload("res://games/racer/night.gd")
const DmdAnims = preload("res://games/racer/dmd_anims.gd")
const Showroom = preload("res://games/racer/showroom.gd")
const Tunnel = preload("res://games/racer/tunnel.gd")
const SELECT_TIME := 15.0   # s to choose a car before the highlighted one is taken
## Car colours on the DMD, matching Sim.CARS' hues (red, yellow, blue).
const CAR_COLS := [Color("3f8cff"), Color("e8303a"), Color("ff8a1e")]   # D-202: easy blue, normal red, hard orange
const NIGHT_GROUP := &"rc_night_lights"
const Dial = preload("res://games/racer/dial.gd")
const GearLever = preload("res://games/racer/gear_lever.gd")
const RadarBar = preload("res://games/racer/radar_bar.gd")
const UI = preload("res://core/ui/ui.gd")
const Synth = preload("res://core/util/synth.gd")
const ScoreTable = preload("res://core/util/score_table.gd")
const ROAD_SHADER = preload("res://games/racer/shaders/road.gdshader")
const CAR_SHADER = preload("res://games/racer/shaders/car.gdshader")
const PIXEL_POST = preload("res://games/racer/shaders/pixel_post.gdshader")
const SKY_SHADER = preload("res://games/racer/shaders/sky.gdshader")   # D-193
const TimeOfDay = preload("res://games/racer/sky.gd")
const LOGO := "res://assets/textures/racer/logo.png"
const BG_DIR := "res://assets/textures/racer/"
## Shared lit-backglass shader (D-058; generic: off art + on art + group masks).
const BACKGLASS_SHADER = preload("res://games/breakout/shaders/backglass_lights.gdshader")
const DMD_LOGO := "res://assets/textures/racer/dmd_logo.png"
const SKY_TEXTURE := "res://assets/sprites/racer/sky.png"
const CAR_MODEL := "res://assets/models/racer/red_car.glb"
## The model's nose points +Z; turn it to face down the road (-Z).
const MODEL_TURN := Basis(Vector3.UP, PI)
## Cars snap to 32 views around the camera, like a sprite set (D-092).
const SPRITE_ANGLES := 32
## Nose turn at full steer (rad): ~1.5 sprite steps, visible on straights.
const SHIFT_RISE := 36.0    # px the SHIFT word rises each loop (D-158)
const SHIFT_NAG := 3.0      # s at the redline in L before the big SHIFT (D-116)
const REV_HAND := "res://assets/textures/racer/rev_hand.png"   # D-197
const REV_HAND_GAP := 44.0     # px from the tacho's band to the fingertip at rest (D-209)
const REV_POKES := 3.0         # pokes at the band, then still (D-209)
const REV_POKE_RATE := 9.0     # rad/s
const DIAL_R := 150.0        # tachometer and speedometer radius (D-149)
const SPEEDO_MAX := 220      # mph on the speedometer dial (D-147; nitro on the fastest car ~206)
const MAX_TRAVEL_YAW := 0.45   # rad: the most the nose follows sideways travel (D-124)
## Crash animations (D-098): stepped at ANIM_FPS; a roll-over shows FLIP_FRAMES
## poses per full turn and hops FLIP_HOP metres.
const ANIM_FPS := 10.0
## Pixel renderer resolution (D-107): 1/3 of the 1080x1920 TABLE.
const PIXEL_RES := Vector2i(480, 854)   # D-194: softer pixels (was 360 x 640)
const NES_RES := Vector2i(270, 480)     # D-207: 8-BIT, chunkier pixels
const FLIP_FRAMES := 8.0
const FLIP_HOP := 1.6
## TIME UP slide (D-105): 90 degrees in OVER_TURN_TIME s, OVER_TURN_FRAMES steps.
const OVER_TURN_TIME := 0.6
const OVER_TURN_FRAMES := 6.0
const FINISH_DRIFT := 0.83   # of 90 degrees: the finish drift-brake angle (D-222)
## Number plate spot on the red car's rear bumper (model space, D-114).
const PLATE_Y := 0.56     # raised clear of the bumper's bottom edge (D-127)
const PLATE_SIZE := Vector2(0.51, 0.255)   # oversized so TRN reads at pixel scale (15 % smaller, D-127)
const PLATE_Z := -2.215           # nitro canisters read from far away (D-103)
## Roll-over phases (fractions of the animation, D-101): slew 90 degrees by
## FLIP_TURN_END, roll over until FLIP_ROLL_END, then lie still; in the last
## FLIP_UNTURN s of the stop the car turns back to face the road.
const FLIP_TURN_END := 0.25
const FLIP_ROLL_END := 0.8
const FLIP_UNTURN := 0.4
## Landing bounce after a roll-over (D-211): bounces every LAND_PERIOD s,
## starting LAND_HEIGHT m high and dying away, for LAND_TIME s.
const LAND_HEIGHT := 0.45
const LAND_PERIOD := 0.26
const LAND_DECAY := 3.2
const LAND_TIME := 1.0
const LAND_ROCK := 0.12   # rad of side-to-side rock
const CAR_TEXTURE := "res://assets/models/racer/red_car_albedo.png"
## Director's truck (D-099): 10 m, same orientation as the car.
const TRUCK_MODEL := "res://assets/models/racer/truck.glb"
const TRUCK_TEXTURE := "res://assets/models/racer/truck_albedo.png"
## Director's second truck (D-121): a US-style tractor with a striped trailer.
const TRUCK2_MODEL := "res://assets/models/racer/truck2.glb"
## Director's hatchback (D-136), mixed into car traffic.
const HATCH_MODEL := "res://assets/models/racer/hatchback.glb"
const HATCH_TEXTURE := "res://assets/models/racer/hatchback_albedo.png"
const HATCH_POOL := 8
## Director's hot hatch (D-205): the easy car, and in the traffic mix.
const HOTHATCH_MODEL := "res://assets/models/racer/hothatch.glb"
const HOTHATCH_TEXTURE := "res://assets/models/racer/hothatch_albedo.png"
const HOTHATCH_POOL := 6
## Director's supercar (D-210): the hard car. Its texture atlas is in tiny
## pieces, so RETRO samples a 1024 px albedo (256 px turned it to mush).
const SUPERCAR_MODEL := "res://assets/models/racer/supercar.glb"
const SUPERCAR_TEXTURE := "res://assets/models/racer/supercar_albedo.png"
## The player's model per car (Sim.CARS order: easy, normal, hard).
const CAR_MODELS := [HOTHATCH_MODEL, CAR_MODEL, SUPERCAR_MODEL]
## Each player model's albedo, and its key in TAIL_AT / NIGHT light spots.
const MODEL_TEXTURES := {CAR_MODEL: CAR_TEXTURE, HOTHATCH_MODEL: HOTHATCH_TEXTURE, SUPERCAR_MODEL: SUPERCAR_TEXTURE}
const MODEL_LIGHTS := {CAR_MODEL: "car", HOTHATCH_MODEL: "hothatch", SUPERCAR_MODEL: "supercar"}
## Exhaust tips per model (model space, rear is -Z): where the nitro and
## backfire flames come out. The hot hatch has two pipes together on its left.
const EXHAUSTS := {
	CAR_MODEL: [Vector3(-0.57, 0.28, -2.2), Vector3(0.57, 0.28, -2.2)],
	HOTHATCH_MODEL: [Vector3(0.42, 0.26, -2.05), Vector3(0.53, 0.26, -2.05)],
	# Twin pipes on each side (D-210).
	SUPERCAR_MODEL: [Vector3(-0.64, 0.27, -2.2), Vector3(-0.52, 0.27, -2.2),
		Vector3(0.52, 0.27, -2.2), Vector3(0.64, 0.27, -2.2)],
}
## Number plate per model: [centre, size] (D-127 for the red car). D-212: the
## hot hatch and supercar plates fit their own plate recess (measured from
## renders and the mesh's rear surface), so they don't float or clip.
const PLATES := {
	CAR_MODEL: [Vector3(0.0, PLATE_Y, PLATE_Z), PLATE_SIZE],
	HOTHATCH_MODEL: [Vector3(0.0, 0.415, -2.025), Vector2(0.37, 0.185)],
	SUPERCAR_MODEL: [Vector3(0.0, 0.43, -2.215), Vector2(0.34, 0.17)],
}
## Puts a car's night tail glows on its lamps (D-198): onto the body mesh, in
## the model's own space, at the centre of the lamp area the car shader lights
## (LAMP_BOXES, else the shader's defaults), just behind the rear surface.
func _place_tails(car: Node3D, holder: Node3D, model: String) -> void:
	var body: MeshInstance3D = null
	for m in car.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).material_override is ShaderMaterial:
			body = m
			break
	if body == null or body.mesh == null:
		return
	var lb: Dictionary = LAMP_BOXES.get(model, {})
	var lo: Vector3 = lb.get("tail_min", Vector3(0.2, 0.7, -9.0))
	var hi: Vector3 = lb.get("tail_max", Vector3(0.7, 0.9, -1.95))
	var rear := body.mesh.get_aabb().position.z
	var tails: Array = holder.get_meta("tails", [])
	for i in tails.size():
		var tl: Node3D = tails[i]
		tl.reparent(body, false)
		var sx := -1.0 if i == 0 else 1.0
		tl.position = Vector3(sx * (lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5 + 0.04, rear - 0.04)
		tl.scale = Vector3.ONE * 0.6
	# They now live on the body: show them with the night lights holder.
	holder.set_meta("tails", tails)
	holder.visibility_changed.connect(func():
		for tl in tails:
			(tl as Node3D).visible = holder.visible)
	for tl in tails:
		(tl as Node3D).visible = holder.visible


## Rear lamp glow spots per model at night (D-198): x = half width, nose +Z.
const TAIL_AT := {
	"car": Vector3(0.62, 0.72, -2.2),
	"hatch": Vector3(0.62, 0.85, -2.0),
	"hothatch": Vector3(0.7, 0.8, -2.05),
	"supercar": Vector3(0.65, 0.78, -2.2),
	"police": Vector3(0.62, 0.75, -2.35),
}
## Indicator spots per model, on its own right side (D-163).
const BLINKERS := {
	"car": [Vector3(-0.85, 0.65, -2.15), Vector3(-0.8, 0.6, 2.15)],
	"hatch": [Vector3(-0.8, 0.85, -1.95), Vector3(-0.78, 0.65, 1.95)],
	"hothatch": [Vector3(-0.8, 0.88, -2.0), Vector3(-0.8, 0.5, 2.0)],
	"supercar": [Vector3(-0.75, 0.78, -2.2), Vector3(-0.6, 0.62, 2.2)],
	"truck": [Vector3(-1.3, 0.9, -4.95), Vector3(-1.2, 1.1, 4.95)],
	"truck2": [Vector3(-1.4, 0.9, -4.95), Vector3(-1.3, 1.1, 4.95)],
}
const DRY_BUS := "SFXDry"   # D-215: effects that stay dry in tunnels
## Turning wheels (D-250): [rim picture, [Vector3(z, y, rim radius) per
## axle]], model space, measured from side renders of each model.
const RIMS := "res://assets/textures/racer/"
const WHEELS := {
	"res://assets/models/racer/red_car.glb": [RIMS + "rim_5spoke.png", [Vector3(1.204, 0.334, 0.25), Vector3(-1.189, 0.333, 0.25)]],
	"res://assets/models/racer/supercar.glb": [RIMS + "rim_9spoke.png", [Vector3(1.247, 0.341, 0.25), Vector3(-1.294, 0.339, 0.255)]],
	"res://assets/models/racer/hothatch.glb": [RIMS + "rim_9spoke.png", [Vector3(1.202, 0.325, 0.243), Vector3(-1.298, 0.324, 0.243)]],
	"res://assets/models/racer/hatchback.glb": [RIMS + "rim_5spoke.png", [Vector3(1.186, 0.309, 0.24), Vector3(-1.181, 0.298, 0.24)]],
	"res://assets/models/racer/police2.glb": [RIMS + "rim_police.png", [Vector3(1.289, 0.359, 0.29), Vector3(-1.375, 0.364, 0.29)]],
	"res://assets/models/racer/truck.glb": [RIMS + "rim_truck.png", [Vector3(3.78, 0.44, 0.25), Vector3(1.05, 0.44, 0.25),
		Vector3(-2.54, 0.45, 0.25), Vector3(-3.55, 0.45, 0.25)]],
	"res://assets/models/racer/truck2.glb": [RIMS + "rim_truck2.png", [Vector3(4.45, 0.45, 0.24), Vector3(1.04, 0.43, 0.22),
		Vector3(0.23, 0.43, 0.22), Vector3(-3.02, 0.43, 0.22), Vector3(-3.97, 0.43, 0.22)]],
}
## Lamp areas per model for car.gdshader (model space, |x|; D-144). The red
## car uses the shader defaults.
const LAMP_BOXES := {
	"res://assets/models/racer/supercar.glb": {   # D-210, from its renders
		"tail_min": Vector3(0.45, 0.66, -9.0), "tail_max": Vector3(0.85, 0.9, -1.95),
		"tail_red_only": true,
		"head_min": Vector3(0.45, 0.52, 1.9), "head_max": Vector3(0.75, 0.7, 9.0),
	},
	# Measured from orthographic renders of the model (D-205).
	"res://assets/models/racer/hothatch.glb": {
		"tail_min": Vector3(0.55, 0.68, -9.0), "tail_max": Vector3(0.86, 0.92, -1.88),
		"tail_red_only": true,
		"head_min": Vector3(0.42, 0.6, 1.8), "head_max": Vector3(0.86, 0.77, 9.0),
	},
	"res://assets/models/racer/hatchback.glb": {
		"tail_min": Vector3(0.0, 0.35, -9.0), "tail_max": Vector3(0.95, 1.3, -1.6),
		"tail_red_only": true,
		"head_min": Vector3(0.35, 0.45, 1.6), "head_max": Vector3(0.85, 0.82, 9.0),
	},
}
## Director's police car (D-135).
const POLICE_MODEL := "res://assets/models/racer/police2.glb"   # D-140: not modelled on a real car
const POLICE_TEXTURE := "res://assets/models/racer/police2_albedo.png"
const TRUCK2_TEXTURE := "res://assets/models/racer/truck2_albedo.png"
## D-195 HD graphics: each model's original high-res texture (same UV layout).
const HD_TEXTURES := {
	CAR_TEXTURE: "res://assets/models/racer/red_car_red_car_albedo.jpg",
	TRUCK_TEXTURE: "res://assets/models/racer/truck_truck_albedo.jpg",
	TRUCK2_TEXTURE: "res://assets/models/racer/truck2_truck2_albedo.jpg",
	HATCH_TEXTURE: "res://assets/models/racer/hatchback_hatchback_albedo.jpg",
	POLICE_TEXTURE: "res://assets/models/racer/police2_albedo_hd.png",
	HOTHATCH_TEXTURE: "res://assets/models/racer/hothatch_hothatch_albedo.jpg",
	SUPERCAR_TEXTURE: "res://assets/models/racer/supercar_albedo_hd.jpg",   # 4096 px (D-210)
}
## D-207: 8-BIT ("nes"), 16-BIT (id "retro", kept for saved settings) and HD.
const GFX_OPTIONS := ["nes", "retro", "hd"]
const GFX_NAMES := {"nes": "RC_GFX_NES", "retro": "RC_GFX_RETRO", "hd": "RC_GFX_HD"}
const GFX_DESC := {"nes": "RC_GFX_NES_DESC", "retro": "RC_GFX_RETRO_DESC", "hd": "RC_GFX_HD_DESC"}

const ACCENT := Color("ffd23e")
const TITLE_FONT := "sunset"
## Music (D-226, director): the five Bogart VGM songs (CC BY 3.0), one for
## every two stages. Attract plays the first, and the race carries it on from
## the start; each new song crossfades in over MUSIC_XFADE s, starting
## MUSIC_SKIP s in (they all open very quietly).
const MUSIC_RACE := [
	"res://assets/audio/music/racer/bogart_maximum_overdrive.ogg",   # stages 1-2
	"res://assets/audio/music/racer/bogart_one_more_round.ogg",      # 3-4
	"res://assets/audio/music/racer/bogart_nightlife.ogg",           # 5-6
	"res://assets/audio/music/racer/bogart_dreamstate.ogg",          # 7-8
	"res://assets/audio/music/racer/bogart_chillwave_nightdrive.ogg",   # 9-10
]
const MUSIC_STAGES := 2
const MUSIC_XFADE := 6.0
## Where each song comes in on a crossfade (D-227), measured: past each one's
## quiet opening, to where it's at full strength (One More Round builds for
## 17 s, Dreamstate swells at 34 s).
const MUSIC_SKIP := [0.5, 16.5, 5.5, 31.0, 1.0]
const PASSERS := 2          # traffic engine voices (D-134)
## Oncoming horns (D-213): a dual-tone electric car horn (low and high tones a
## dissonant interval apart, buzzy diaphragm harmonics with a nasal resonance,
## a pitch scoop at each press), honked from the car itself: Doppler from its
## closing speed against a near-real speed of sound, volume by distance.
const HORN_TONES := [415.0, 500.0]
const HORN_FORMANT := 2000.0
const HORN_SOUND_SPEED := 300.0    # game m/s (real ~400 here; a touch exaggerated)
const HORN_RANGE := 260.0          # m where it fades out
## Honk pattern (s): [start, length] presses. D-214: always a clear BEEP BEEP,
## two equal presses with a gap, so it reads as "they're honking at me".
const HORN_PATTERNS := [[[0.0, 0.3], [0.45, 0.3]]]
const HORN_DUCK_DB := 6.0    # engine and wind dip while a horn sounds (D-214)
const PASS_RANGE := 70.0    # m: how far a car can be heard (D-192: was 45)
const SOUND_SPEED := 85.0   # m/s, exaggerated so the Doppler shift is obvious (D-192: was 110)
const ENGINE_GAIN_DB := -0.92   # D-192: the hero car's engine 10% lower (0.9x)
const PASS_DUCK_DB := 4.0       # D-192: engine + wind dip while a car passes close
const PASS_DUCK_RANGE := 15.0   # m
const MUSIC_ATTRACT := "res://assets/audio/music/racer/bogart_maximum_overdrive.ogg"
const CHUNK := 100.0             # metres of road per mesh chunk
const VIEW_AHEAD := 900.0
const VIEW_BEHIND := 60.0
const SKIRT_OUT := 400.0   # m the ground's skirt reaches past the strip's edge (D-197)
const SKIRT_DROP := 250.0  # m it falls: a gentle slope into the haze, not a wall
const LATERAL := [-140.0, -70.0, -36.0, -18.0, -11.7, -8.7, -7.5, -3.75, 0.0, 3.75, 7.5, 8.7, 11.7, 18.0, 36.0, 70.0, 140.0]
const TRAFFIC_POOL := 16
const CAM_BACK := 8.0
const CAM_HEIGHT := 2.3            # low, close to the road (D-098; was 3.6)
## The car sits this far below the screen centre (degrees), whatever the
## camera height: the old 3.6 m camera's framing (D-098).
const CAM_CAR_DEG := 15.9
const CAM_LOOK := 30.0
const CAM_FOV := 58.0
const FINALE_TEXT_AT := 0.6
const FINALE_SKIP_AT := 1.5
const FINALE_END_AT := 6.0

const SOUNDS := {
	# Start lights: a soft sine "boop" with an octave shimmer (D-116).
	"rc_count": {"voices": [[{"f": [440.0, 440.0], "t": 0.28, "w": "sine", "v": 0.45, "a": 0.005, "env": "hold"}],
		[{"f": [880.0, 880.0], "t": 0.22, "w": "triangle", "v": 0.12, "a": 0.005}]], "reverb": [0.5, 0.25]},
	# GO: the high start tone over a brass stab chord and a drum boom.
	"rc_go": {"voices": [[{"f": [880.0, 880.0], "t": 0.7, "w": "sine", "v": 0.4, "a": 0.005, "env": "hold"}],
		[{"f": [220.0, 220.0], "t": 0.6, "w": "saw", "v": 0.14, "lp": 0.6, "a": 0.02}],
		[{"f": [330.0, 330.0], "t": 0.6, "w": "saw", "v": 0.12, "lp": 0.6, "a": 0.02}],
		[{"f": [440.0, 440.0], "t": 0.6, "w": "saw", "v": 0.1, "lp": 0.6, "a": 0.02}],
		[{"f": [90.0, 45.0], "t": 0.4, "w": "sine", "v": 0.5}]], "reverb": [0.9, 0.3]},
	# Checkpoint: a rising brass fanfare over a timpani boom.
	"rc_checkpoint": {"voices": [
		[{"f": [262.0, 262.0], "t": 0.08, "w": "saw", "v": 0.18, "lp": 0.55, "env": "hold"},
		 {"f": [330.0, 330.0], "t": 0.08, "w": "saw", "v": 0.18, "lp": 0.55, "env": "hold"},
		 {"f": [392.0, 392.0], "t": 0.08, "w": "saw", "v": 0.18, "lp": 0.55, "env": "hold"},
		 {"f": [523.0, 523.0], "t": 0.6, "w": "saw", "v": 0.2, "lp": 0.5, "vib": [5.5, 0.15]}],
		[{"f": [131.0, 131.0], "t": 0.24, "w": "saw", "v": 0.14, "lp": 0.7, "env": "hold"},
		 {"f": [196.0, 196.0], "t": 0.6, "w": "saw", "v": 0.14, "lp": 0.7}],
		[{"f": [95.0, 50.0], "t": 0.5, "w": "sine", "v": 0.55}]], "reverb": [1.1, 0.3]},
	# Crash: an impact boom, crunching metal and breaking glass.
	"rc_crash": {"voices": [
		[{"f": [3000.0, 90.0], "t": 0.9, "w": "lfsr", "v": 0.42, "lp": 0.45}],
		[{"f": [110.0, 32.0], "t": 0.6, "w": "sine", "v": 0.65}],
		[{"f": [5200.0, 1800.0], "t": 0.35, "w": "noise", "v": 0.16}],
		[{"f": [3520.0, 3520.0], "t": 0.04, "w": "triangle", "v": 0.08, "gap": 0.03},
		 {"f": [2960.0, 2960.0], "t": 0.04, "w": "triangle", "v": 0.07, "gap": 0.05},
		 {"f": [4186.0, 4186.0], "t": 0.05, "w": "triangle", "v": 0.06, "gap": 0.04},
		 {"f": [3136.0, 3136.0], "t": 0.06, "w": "triangle", "v": 0.05}]], "reverb": [0.9, 0.3]},
	# Bump: a body thud with a metal clank.
	"rc_bump": {"voices": [[{"f": [130.0, 45.0], "t": 0.22, "w": "sine", "v": 0.6}],
		[{"f": [1800.0, 500.0], "t": 0.1, "w": "noise", "v": 0.25, "lp": 0.6}],
		[{"f": [620.0, 540.0], "t": 0.12, "w": "triangle", "v": 0.1}]], "reverb": [0.3, 0.15]},
	# Nitro (D-121): an ignition "fwoomp" - a noise burst falling through a low
	# pass, a growling engine roar and a sub boom; no tonal lead.
	"rc_nitro": {"voices": [
		[{"f": [6000.0, 400.0], "t": 0.55, "w": "noise", "v": 0.45, "lp": 0.35, "a": 0.01}],
		[{"f": [70.0, 140.0], "t": 0.35, "w": "saw", "v": 0.3, "lp": 0.7, "vib": [32.0, 0.8], "env": "hold"},
		 {"f": [140.0, 120.0], "t": 0.5, "w": "saw", "v": 0.25, "lp": 0.75, "vib": [32.0, 0.6]}],
		[{"f": [80.0, 36.0], "t": 0.6, "w": "sine", "v": 0.6}]], "reverb": [0.8, 0.22]},
	# Perfect shift / start (D-121): a rising brass stab with a turbo whoosh.
	"rc_perfect": {"voices": [
		[{"f": [262.0, 262.0], "t": 0.08, "w": "saw", "v": 0.16, "lp": 0.6, "env": "hold"},
		 {"f": [392.0, 392.0], "t": 0.35, "w": "saw", "v": 0.17, "lp": 0.55}],
		[{"f": [131.0, 131.0], "t": 0.08, "w": "saw", "v": 0.14, "lp": 0.7, "env": "hold"},
		 {"f": [196.0, 196.0], "t": 0.35, "w": "saw", "v": 0.14, "lp": 0.7}],
		[{"f": [800.0, 5000.0], "t": 0.35, "w": "noise", "v": 0.22, "lp": 0.4, "env": "lin"}]], "reverb": [0.8, 0.25]},
	# Radar detector chirp (D-135): a short, bright double blip.
	"rc_radar": {"voices": [[{"f": [2900.0, 2900.0], "t": 0.035, "w": "square", "v": 0.12, "env": "hold", "gap": 0.02},
		{"f": [2900.0, 2900.0], "t": 0.035, "w": "square", "v": 0.12, "env": "hold"}]]},
	# Upshift backfire: a crackle and a thump.
	"rc_backfire": {"voices": [[{"f": [1800.0, 300.0], "t": 0.12, "w": "lfsr", "v": 0.4, "lp": 0.3}],
		[{"f": [110.0, 50.0], "t": 0.15, "w": "sine", "v": 0.5}]], "reverb": [0.3, 0.2]},
	# Downshift: a short tyre chirp.
	"rc_chirp": {"voices": [[{"f": [1400.0, 900.0], "t": 0.18, "w": "triangle", "v": 0.18, "vib": [30.0, 0.8]}],
		[{"f": [5000.0, 3000.0], "t": 0.16, "w": "noise", "v": 0.12, "lp": 0.4}]]},
	# Gear change: a mechanical clunk.
	"rc_shift": {"voices": [[{"f": [150.0, 60.0], "t": 0.09, "w": "sine", "v": 0.5}],
		[{"f": [2200.0, 900.0], "t": 0.04, "w": "lfsr", "v": 0.18, "lp": 0.4}]]},
	# Near miss: a Doppler pass, engine tone dropping as it whooshes by.
	"rc_near_miss": {"voices": [[{"f": [440.0, 150.0], "t": 0.5, "w": "saw", "v": 0.16, "lp": 0.6}],
		[{"f": [4000.0, 500.0], "t": 0.45, "w": "noise", "v": 0.28, "lp": 0.45, "a": 0.05}]], "reverb": [0.4, 0.2]},
	# Drift points banked (D-121): a short brass stab over a tyre-release swoosh.
	"rc_drift_bank": {"voices": [
		[{"f": [294.0, 294.0], "t": 0.22, "w": "saw", "v": 0.16, "lp": 0.6, "a": 0.01}],
		[{"f": [370.0, 370.0], "t": 0.22, "w": "saw", "v": 0.14, "lp": 0.6, "a": 0.01}],
		[{"f": [440.0, 440.0], "t": 0.22, "w": "saw", "v": 0.12, "lp": 0.6, "a": 0.01}],
		[{"f": [3000.0, 800.0], "t": 0.3, "w": "noise", "v": 0.2, "lp": 0.5}],
		[{"f": [100.0, 55.0], "t": 0.2, "w": "sine", "v": 0.4}]], "reverb": [0.6, 0.22]},
	# Low-time clock: a woodblock "tock" with a soft body (D-112).
	"rc_tick": {"voices": [[{"f": [1900.0, 1600.0], "t": 0.05, "w": "triangle", "v": 0.35}],
		[{"f": [950.0, 900.0], "t": 0.09, "w": "sine", "v": 0.25}],
		[{"f": [7000.0, 7000.0], "t": 0.012, "w": "noise", "v": 0.18, "lp": 0.2}]], "reverb": [0.35, 0.18]},
	# Time up: a falling brass phrase and a low boom.
	"rc_time_up": {"voices": [
		[{"f": [392.0, 392.0], "t": 0.25, "w": "saw", "v": 0.18, "lp": 0.6, "env": "hold"},
		 {"f": [330.0, 330.0], "t": 0.25, "w": "saw", "v": 0.18, "lp": 0.6, "env": "hold"},
		 {"f": [262.0, 220.0], "t": 0.9, "w": "saw", "v": 0.2, "lp": 0.65, "vib": [4.0, 0.25]}],
		[{"f": [131.0, 110.0], "t": 1.4, "w": "saw", "v": 0.12, "lp": 0.75}],
		[{"f": [70.0, 40.0], "t": 0.8, "w": "sine", "v": 0.5}]], "reverb": [1.2, 0.3]},
}

var sim: Sim
## D-289: 2-player split screen. Player 1's view (the module) owns the menus,
## the DMD, backglass, music and the shared lamp levels; player 2's view is a
## second copy of this script, a child of the first, drawing the same shared
## simulation from player 2's car into the right half of the TABLE.
var _role := 0              # whose car this view follows
var _two := false           # a 2-player game
var _main := true           # owns the DMD, backglass, music, reverb, shared lamp levels
var _p2: Node = null        # player 2's view (on player 1's)
var _host: Control = null   # 2P: this view's half of the TABLE
var _dmd: Object            # Dmd, or a quiet stand-in in 2P (the DMD shows both players)
var _players_sel := 0       # 0 = 1 player, 1 = 2 players
var _players_ui: Control
var _players_rows: Array = []
var _select_p2 := false     # 2P car select: player 2's turn
var _p2_car := Sim.DEFAULT_CAR
var _hues := [-1.0, -1.0]   # each player's car colour (2P)
var _rival: Node3D = null   # the other player's car
var _rival_wheel := 0.0
var _time_caption: Label    # TIME, or POSITION in 2P


## Stands in for the DMD in 2P views: every call does nothing.
class QuietDmd extends RefCounted:
	func show_text(_a = null, _b = null, _c = null, _d = null) -> void:
		pass

	func show_image(_a = null) -> void:
		pass

	func show_custom(_a = null) -> void:
		pass

	func flash(_a = null, _b = null, _c = null) -> void:
		pass

	func play(_a = null, _b = null) -> void:
		pass


func _music(path: String) -> void:
	if _main:
		Audio.play_music(path)


func _crossfade(path: String, t: float, skip: float = 0.0) -> void:
	if _main:
		Audio.crossfade_music(path, t, skip)


## 2P: this view's nodes go into its half of the TABLE.
func add_to_table(node: Node) -> Node:
	if _host != null:
		return _own(_host, node)
	return super.add_to_table(node)


## The TABLE's pixels this view covers (2P: half of them).
func _table_px() -> Vector2:
	var px := Vector2(Screens.table.size)
	return Vector2(px.x * 0.5, px.y) if _host != null else px
var _phase := "attract"          # attract, race, finale
var _phase_t := 0.0
var _manual_locked := false      # operator.cabinet_buttons = 4
static var _seen_magna := false  # a magna save was pressed this session (stays 4-button, D-189)
var _root: Node3D
var _cam: Camera3D
var _weather: Node3D            # D-217
## D-233: all of the game's UI draws in its own viewport over the 3D view, at
## full resolution in HD and at the game's low resolution in 8-BIT/16-BIT.
var _ui_vp: SubViewport
var _ui_root: Control
var _ui_view: TextureRect
var _ui_px := 1.0                # target pixels per base pixel of the UI
var _puddle_mat: ShaderMaterial
var _wx := {"rain": 0.0, "snow": 0.0, "fog": 0.0, "haze": 0.0}   # smoothed weather weights
var _env: Environment
var _sun: DirectionalLight3D
var _road_mat: ShaderMaterial
var _chunks := {}                # chunk index -> Node3D
var _car: Node3D                 # player car (road frame)
var _car_body: Node3D            # model; yaws/rolls/spins
var _car_mats := {}         # model path -> ShaderMaterial
var _car_outlines := {}     # model path -> outline ArrayMesh
var _beam_mat: StandardMaterial3D
var _pix_vp: SubViewport
var _gfx_hd := false             # D-195: HD graphics (native resolution, high-res art)
var _gfx_mode := "retro"         # D-207: one of GFX_OPTIONS
## D-208: animation steps per mode: 8-BIT the base frame counts, 16-BIT twice
## as many, HD 0 = smooth (no stepping at all).
var _anim_mult := 2.0
var _retro_post: ShaderMaterial  # the 16-bit palette/dither pass, kept for switching back
var _hd_flipped := {}            # materials HD switched from nearest to smooth filtering
var _gfx_ui: Control
## Start stage (D-216, for testing): picked on its own screen after GRAPHICS.
var _start_stage := 1
var _stage_ui: Control
var _stage_num: Label
var _stage_area: Label
var _stage_hint: Label
var _gfx_rows: Array = []
var _gfx_index := 0
var _gfx_hint: Label
var _police: Node3D          # D-135
var _flashers: Array = []
var _police_night: Node3D       # D-198: its head/tail lights at night
var _siren_lights: Array = []   # D-198: [red, blue] OmniLight3D from the light bar
var _siren_pools: Array = []    # D-198: [red, blue] glow pools on the road around it
var _washes: Array = []
var _police_swing := 0.0     # 0..1 of the 90-degree stop turn (D-139)      # red / blue screen-edge glows (D-137)
var _siren: AudioStreamPlayer
var _radar_bar: Control
var _radar_led := 0.0
var _radar_beep_t := 0.0
var _world_view: TextureRect
var _showroom: Control
var _select_hint: Label
var _chosen_car := Sim.DEFAULT_CAR
var _bg_mat: ShaderMaterial
var _anims := DmdAnims.new()
var _night := 0.0           # 0 = day, 1 = night (D-113)
var _tod_p := -1.0          # D-193: time-of-day progress (stages played, smoothed)
var _lamps_shown := -1.0
var _tunnel_k := 0.0        # 0 outside .. 1 inside a tunnel (D-127)
var _tunnel_shown := -1.0
var _lamps := 0.0           # car lights level: max(night, tunnel)
var _reverb: AudioEffectReverb
var _reverb_on := false
## D-283: the phone can't hold the frame rate in HD -> steps down the world's
## anti-aliasing, then its resolution (the HUD stays sharp). Kept for the session.
const QUALITY_STEPS := [[Viewport.MSAA_4X, 1.0], [Viewport.MSAA_2X, 1.0], [Viewport.MSAA_DISABLED, 0.85],
	[Viewport.MSAA_DISABLED, 0.7], [Viewport.MSAA_DISABLED, 0.58]]
const QUALITY_WINDOW := 2.0      # seconds measured per verdict
const QUALITY_SLOW := 1.0 / 48.0 # an average frame slower than this is "can't keep up"
static var _quality := 0
var _q_t := 0.0
var _q_n := 0
var _q_bad := 0
var _radar_player: AudioStreamPlayer   # D-215: dry, no tunnel reverb (it's inside the car)
var _sky_mat: ShaderMaterial     # the procedural sky (D-193)
var _player_lights: Node3D
var _flame_mats: Array = []
var _rev_pop_t := 0.0
var _rev_popped := false
var _last_rpm := 0.0
var _shift_smoke_t := 0.0   # downshift tyre smoke left (D-112)
var _shift_flame_t := 0.0   # upshift exhaust flame left
var _bg_flash := 0.0    # s of backglass light flashing left (D-109)
var _bg_dark := 0.0     # s of crash flicker left
var _wheel_phase := 0.0
var _police_wheel := 0.0       # D-246
const SHADOW_DISTANCE := 140.0   # m of real shadows ahead of the camera (D-253)
const SHADOW_STRENGTH := 0.75
var _blob_mat: StandardMaterial3D   # soft round ground shadows under sprites (D-253)
var _blob_mesh: QuadMesh
var _used_gas := false          # D-252: R2 has been pressed this race
var _pad_brake := false
const WHEEL_MAX := 25.0   # rad/s the wheels are seen to turn at most (~4 turns a second, D-249)
var _travel := 0.0         # eased nose angle from sideways travel (D-128)
var _over_turn := 0.0   # 0..1 TIME UP sideways slide (D-105)
var _over_dir := 0.0
var _traffic_pool := {"car": [], "hatch": [], "hothatch": [], "truck": [], "truck2": []}   # pools of Node3D per model
## Tyre smoke / dust (D-100): our own pooled billboard puffs in one MultiMesh.
## CPUParticles3D drew a stray pure-black puff at the emitter when toggled.
const PUFF_MAX := 192
const PUFF_EVERY := 0.016        # s between puffs per wheel
const PUFF_LIFE := 0.6
var _puffs: MultiMesh
var _puff_list: Array = []       # {pos, vel, age, size, col}
var _puff_t := 0.0
var _flames: Array = []          # nitro flame meshes
var _land_t := 0.0              # s since a roll-over landed (D-211)
var _body_model := ""            # the player's car model built (D-205)
var _exhaust_z := -2.2           # its exhaust tips' z (model space)
var _cam_pos := Vector3.ZERO
var _cam_ready := false
var _cam_x := 0.0
var _engine: AudioStreamPlayer
var _pass_duck := 0.0       # dB the hero's engine and wind dip for a passing car (D-192)
var _horn: AudioStreamPlayer      # D-213
var _horn_waves: Array = []       # one AudioStreamWAV per pattern
var _horn_id := -1                # traffic id honking
var _skid: AudioStreamPlayer
var _engine_hi: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _passers: Array = []    # AudioStreamPlayers for nearby traffic (D-134)
var _hud: Control
## D-254: HUD pieces that move between the portrait and landscape layouts.
var _hud_top: HBoxContainer
var _hud_left: VBoxContainer
var _hud_mid: VBoxContainer
var _hud_bottom: HBoxContainer
var _hud_gap: Control
var _flex_req := false
var _time_label: Label
var _score_label: Label
var _stage_label: Label
var _speed_label: Label
var _speedo: Control
var _tacho: Control
var _rev_hint: Control       # D-197: pointing hand + REV! during the countdown
var _rev_hand: TextureRect
var _gear_lever: Control
var _shift_big: Label
var _shift_slot: Control
var _cops_flash := false
var _blink_mesh: QuadMesh
var _shift_armed := true    # SHIFT hint allowed (start of race / after a crash, D-160)
var _shift_shown := false
var _nitro_pop: Label       # NITRO notice above the speedometer (D-159)
var _nitro_pop_t := 0.0
var _nag_lever: Control     # animated shifter next to SHIFT (D-151)
var _frozen_label: Label
var _freeze_time := false   # debug cheat: clock frozen (D-118)
var _redline_t := 0.0       # s held at the redline in L (D-116)
var _nitro_label: Label
var _nitro_strip: ColorRect
var _pickup_nodes: Array = []   # pooled nitro canisters
var _mode_label: Label
var _drift_label: Label
var _center: Control             # big centre message (styled font)
var _center_t := 0.0
var _attract_ui: Control
var _attract_blink: Label
var _dmd_t := 0.0
var _last_tick := -1
var _finale_t := -1.0
var _finale_ui: Control
var _shake := 0.0


func get_info() -> Dictionary:
	return {"id": "racer", "title_key": "GAME_RACER_TITLE", "color": ACCENT, "font": TITLE_FONT, "buttons_min": 3,
		"logo": LOGO, "dmd_logo": DMD_LOGO,   # director's logo (D-108)
		"backglass": BG_DIR + "backglass_on.png"}   # shell screens (D-088, D-109)


func start(_players: int) -> void:
	_dmd = Dmd
	# D-254: in the single-screen layout the TABLE takes the screen's shape.
	if not Screens.table_shape_changed.is_connected(_on_table_shape):
		Screens.table_shape_changed.connect(_on_table_shape)
	_on_table_shape.call_deferred()   # D-255: the TABLE may already have its shape

	# Touch buttons (D-219): the magna saves are the brake and the shifter here.
	get_tree().call_group("touch_controls", "set_labels", {&"magna_l": tr("TOUCH_BRAKE"), &"magna_r": tr("TOUCH_SHIFT")},
		{&"magna_l": "brake", &"magna_r": "shift"})   # D-279: their icons
	for s in SOUNDS:
		Audio.register_sfx(s, Synth.make(SOUNDS[s]))
	_manual_locked = str(Config.get_value("operator", "cabinet_buttons")) == "4" and not _touch_play()
	# Cel shading (D-091); --rc-no-toon shows the plain look for comparison.
	Toon.enabled = not Config.cli.has("rc-no-toon")
	DebugTools.debug_action.connect(_on_debug_action)
	_build_world()
	_apply_gfx(_start_gfx())
	get_tree().node_added.connect(_on_world_node_added)
	_build_hud()
	_build_backglass()
	_build_audio_loops()
	# Tunnel reverb on the effects bus (D-127), removed again when the game ends.
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = 0.75
		_reverb.damping = 0.35
		_reverb.spread = 0.8
		_reverb.dry = 1.0
		_reverb.wet = 0.0
		AudioServer.add_bus_effect(bus, _reverb)
		_reverb_on = true
		_set_reverb(false)
	if Config.cli.has("rc-car"):   # dev: race with car 0 (easy) / 1 / 2 (hard), D-122
		_chosen_car = clampi(int(str(Config.cli["rc-car"])), 0, Sim.CARS.size() - 1)
	if Config.cli.has("rc-2p"):   # dev: a 2-player race (D-289); --rc-car2=N is player 2's car
		_two = true
		CabinetInput.set_two_player(true)
		_p2_car = clampi(int(str(Config.cli.get("rc-car2", "2"))), 0, Sim.CARS.size() - 1)
		_hues = [_car_hue(_chosen_car), _car_hue(_p2_car)]
		if _p2_car == _chosen_car:
			_hues[1] = fposmod(_hues[0] + float(PAINTS[1]), 1.0)
	if Config.cli.has("rc-skip-intro"):
		_begin_race()
	else:
		_enter_attract()


func on_action(action: StringName, pressed: bool) -> void:
	var p2_act := String(action).begins_with("p2_")
	if p2_act:   # D-289: player 2's buttons
		var base := StringName(String(action).substr(3))
		if _phase == "race" and is_instance_valid(_p2):
			_p2.on_action(base, pressed)
			return
		if _phase == "select" and _select_p2:
			action = base   # player 2 picks their own car
		else:
			return
	if _two and sim != null:
		sim._use(_role)
	if not pressed:
		return
	if _phase == "attract":
		if action == &"start" or action == &"launch":
			if CabinetInput.two_player_possible():
				_begin_players()   # D-289: 1 PLAYER / 2 PLAYERS first
			else:
				_begin_gfx()
		return
	if _phase == "players":
		match action:
			&"flip_l", &"flip_r", &"magna_l", &"magna_r":
				_players_sel = 1 - _players_sel
				Audio.sfx("rc_shift")
				_refresh_players()
			&"launch", &"start":
				_confirm_players()
		return
	if _phase == "stage":
		match action:
			&"flip_l", &"magna_l":
				_move_stage(-1)
			&"flip_r", &"magna_r":
				_move_stage(1)
			&"launch", &"start":
				_confirm_stage()
		return
	if _phase == "gfx":
		match action:
			&"flip_l", &"magna_l":
				_move_gfx(maxi(_gfx_index - 1, 0))
			&"flip_r", &"magna_r":
				_move_gfx(mini(_gfx_index + 1, GFX_OPTIONS.size() - 1))
			&"launch", &"start":
				_confirm_gfx()
		return
	if _phase == "select":
		match action:
			&"flip_l":
				_showroom.move(-1)
				Audio.sfx("rc_shift")
			&"flip_r":
				_showroom.move(1)
				Audio.sfx("rc_shift")
			&"magna_l":
				_repaint(-1)
			&"magna_r":
				_repaint(1)
			&"launch", &"start":
				_confirm_car()
		return
	if _phase == "finale":
		if _finale_t >= FINALE_SKIP_AT and (action == &"launch" or action == &"start"):
			_finale_t = FINALE_END_AT
		return
	if (action == &"magna_l" or action == &"magna_r") and not sim.manual:
		# 4-button cabinet detected: shifter + brake from now on (D-189).
		sim.manual = true
		_seen_magna = true
		_show_mode()
		_dmd.flash(tr("RC_MANUAL"), 1.2, Dmd.CYAN)
	if action == &"magna_r" and _phase == "race":
		sim.shift_request = true


func _process(delta: float) -> void:
	if sim == null:
		return
	if _two:
		sim._use(_role)   # D-289: this view's car is the live one
	_phase_t += delta
	if _main:
		_update_backglass(delta)
	_update_night(delta)
	var dt := minf(delta, 0.05)
	if _phase == "attract":
		sim.time_left = 99.0
		sim.step(dt, false, false)
		_attract_tick()
	elif _phase == "stage":
		sim.time_left = 99.0
		sim.step(dt, false, false)
		_stage_hint.text = tr("RC_GFX_HINT") % maxi(ceili(SELECT_TIME - _phase_t), 0)
		if _phase_t >= SELECT_TIME:
			_confirm_stage()
	elif _phase == "players":
		sim.time_left = 99.0
		sim.step(dt, false, false)
	elif _phase == "gfx":
		sim.time_left = 99.0
		sim.step(dt, false, false)   # the attract demo keeps driving behind the menu
		_gfx_hint.text = tr("RC_GFX_HINT") % maxi(ceili(SELECT_TIME - _phase_t), 0)
		if _phase_t >= SELECT_TIME:
			_confirm_gfx()
	elif _phase == "select":
		var left := ceili(SELECT_TIME - _phase_t)
		_select_hint.text = tr("RC_SELECT_HINT_TOUCH" if _touch_play() else "RC_SELECT_HINT") % maxi(left, 0)
		if _phase_t >= SELECT_TIME:
			_confirm_car()
	elif _phase == "race":
		if _two:
			# D-289: player 1's view steps the shared race with both players'
			# controls; each view then shows its own player's events.
			if _role == 0:
				var a := _read_input()
				var b: Array = _p2._read_input() if is_instance_valid(_p2) else [false, false, false]
				sim.step_two(dt, [a, b])
				sim._use(_role)
			_handle_events()
			_update_hud(delta)
			if _role == 0 and sim.race_over and _finale_t < 0.0:
				_begin_finale()
				if is_instance_valid(_p2):
					_p2._begin_finale()
		else:
			var inp := _read_input()
			sim.step(dt, inp[0], inp[1], false, inp[2])
			_handle_events()
			_update_hud(delta)
			if sim.done and _finale_t < 0.0:
				_begin_finale()
		_watch_quality(delta)
	elif _phase == "finale":
		if not _two:
			sim.step(dt, false, false)
		elif _role == 0:
			sim.step_two(dt, [[false, false, false], [false, false, false]])
			sim._use(_role)
		_finale(delta)
	_update_chunks()
	_animate(delta)
	_update_audio()


## This view's player's controls as [left, right, brake]; also sets their
## stick, accelerator and (once a pad's triggers are used) the manual layout.
func _read_input() -> Array:
	var pl := _role if _two else -1
	var l := CabinetInput.is_down(CabinetInput.for_player(&"flip_l", _role))
	var r := CabinetInput.is_down(CabinetInput.for_player(&"flip_r", _role))
	# Gamepad (D-252): stick steers, L2 brakes, R2 accelerates once used.
	var l2 := CabinetInput.trigger(false, pl)
	var r2 := CabinetInput.trigger(true, pl)
	if r2 > 0.0:
		_used_gas = true
	if (l2 > 0.3 or _used_gas) and not bool(sim.player_get(_role, "manual")):
		sim.player_set(_role, "manual", true)   # triggers mean a pad: brake and shifter controls (D-189)
		_seen_magna = true
	sim.player_set(_role, "steer_axis", CabinetInput.steer_axis(pl))
	sim.player_set(_role, "gas_axis", r2 if _used_gas else -1.0)
	_pad_brake = l2 > 0.3
	return [l, r, CabinetInput.is_down(CabinetInput.for_player(&"magna_l", _role)) or _pad_brake]


# --- phases --------------------------------------------------------------------------
func _new_sim() -> void:
	sim = Sim.new()
	_used_gas = false   # D-252
	_over_turn = 0.0
	_over_dir = 0.0
	_puff_list.clear()
	if _two:   # D-289: both cars on the grid, no clock
		sim.setup_two(7, [_chosen_car, _p2_car])
	else:
		sim.setup(7)
	# D-219: each race gets its own weather (--rc-wseed=N repeats one).
	sim.track.weather_seed = int(str(Config.cli["rc-wseed"])) if Config.cli.has("rc-wseed") else randi()
	if not _two:
		sim.freeze_time = _freeze_time
		sim.car = _chosen_car
		sim.time_left = sim.start_time()   # the car sets the clock (D-183)
	sim.manual = (_manual_locked or _seen_magna) and not _touch_play()   # once detected, the next races keep it (D-189)
	if _two:
		sim.player_set(1, "manual", _manual_locked)
	sim.autopilot = Config.cli.has("rc-autopilot")
	if _two:
		sim.player_set(1, "autopilot", Config.cli.has("rc-autopilot"))
	var n := _start_stage
	if Config.cli.has("rc-stage"):  # dev: start at the beginning of stage N (D-204)
		n = maxi(1, int(str(Config.cli["rc-stage"])))
	if n > 1:   # the start-stage screen (D-216) or the dev flag
		sim.start_at_stage(n)
	if Config.cli.has("rc-time"):  # dev: short clock to test TIME UP
		sim.time_left = float(str(Config.cli["rc-time"]))
	for k in _chunks.keys():
		_chunks[k].queue_free()
	_chunks.clear()
	_cam_ready = false


## The player car's DMD dot sprite (D-243), or null for the plain dot car.
const DMD_SPRITES := {SUPERCAR_MODEL: "res://assets/textures/racer/dmd_car_supercar.png",
	CAR_MODEL: "res://assets/textures/racer/dmd_car_sports.png",
	HOTHATCH_MODEL: "res://assets/textures/racer/dmd_car_sports.png"}   # D-244: red sports car (no hatch picture)
static var _dmd_sprites := {}


func _dmd_image(path: String) -> Image:
	var img := (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	return img


func _dmd_sprite(model: String) -> Image:
	if not DMD_SPRITES.has(model):
		return null
	if not _dmd_sprites.has(model):
		var img := (load(DMD_SPRITES[model]) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		_dmd_sprites[model] = img
	return _dmd_sprites[model]


## The sprite in the car's paint (D-244): the same hue turn the 3D car gets,
## on the painted (saturated) dots only, so windows and tyres stay as they are.
func _painted(img: Image, hue: float) -> Image:
	if img == null or is_zero_approx(hue):
		return img
	var out := img.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.5 and c.s > 0.35:
				c.h = fposmod(c.h + hue, 1.0)
				out.set_pixel(x, y, c)
	return out


## The song for stage k (D-226): one per MUSIC_STAGES stages; the last one goes
## on past the finish.
func _stage_music(k: int) -> String:
	return MUSIC_RACE[clampi((k - 1) / MUSIC_STAGES, 0, MUSIC_RACE.size() - 1)]


## Paint (D-236): on the car select screen the magna buttons step the
## highlighted car through PAINTS (tints on top of its own paint, 0 = as it
## comes); kept for the session.
const PAINTS := [0.0, 0.36, 0.62, 0.08, 0.13, 0.8, 0.5, 0.92]
static var _car_paint := [0, 0, 0]


func _car_hue(i: int) -> float:
	return fposmod(float(Sim.CARS[i].hue) + float(PAINTS[int(_car_paint[i])]), 1.0)


func _repaint(d: int) -> void:
	var i: int = _showroom.selected
	_car_paint[i] = posmod(int(_car_paint[i]) + d, PAINTS.size())
	_showroom.set_hue(i, _car_hue(i))
	_phase_t = 0.0
	Audio.sfx("rc_shift")


func _enter_attract() -> void:
	_phase = "attract"
	_phase_t = 0.0
	_new_sim()
	sim.autopilot = true
	sim.state = Sim.State.RACE
	sim.v = 60.0
	_music(MUSIC_ATTRACT)
	_hud.visible = false
	_attract_ui = UI.vstack(60)
	_attract_ui.add_child(UI.spacer(200))
	_attract_ui.add_child(_logo_rect(900))
	_attract_blink = UI.styled_label(tr("RC_PRESS_START"), TITLE_FONT, 2)
	_attract_ui.add_child(_attract_blink)
	var how := tr("RC_HOW_TO_4") if _four_buttons() else tr("RC_HOW_TO")
	if _touch_play():
		how = tr("RC_HOW_TO_TOUCH")
	var hint := UI.label(how, 36, UI.WHITE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 900
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # wraps at 900 px: no lines lost, margins kept
	_attract_ui.add_child(hint)
	_attract_ui.alignment = BoxContainer.ALIGNMENT_BEGIN
	_add_ui(_attract_ui)
	_dmd.show_image(load(DMD_LOGO))


func _attract_tick() -> void:
	# Blink by alpha, not visibility: a hidden label collapses in its VBox and
	# makes the text below it jump (D-096).
	_attract_blink.modulate.a = 1.0 if fmod(_phase_t, 1.0) < 0.6 else 0.0
	# DMD cycle; music credits (CC BY attribution, D-129) mixed in.
	var step := int(_phase_t / 3.0) % 5
	if step != int((_phase_t - get_process_delta_time()) / 3.0) % 5 or _phase_t < 0.05:
		match step:
			0: _dmd.show_image(load(DMD_LOGO))
			1: _dmd.show_text(tr("RC_SHIFT_HINT_4") if _four_buttons() else tr("RC_SHIFT_HINT"),
				tr("RC_NITRO_HINT"), Dmd.CYAN, Dmd.WHITE)
			2: _dmd.show_text(tr("RC_CREDIT_MUSIC"), tr("RC_CREDIT_BOGART"), Dmd.DIM, Dmd.YELLOW)
			3: _dmd.show_text(tr("ATTRACT_HIGH_SCORES"), _top_score_line(), Dmd.YELLOW, Dmd.WHITE)
			4: _dmd.show_text(tr("RC_CREDIT_BOGART"), tr("RC_CREDIT_BOGART_URL"), Dmd.YELLOW, Dmd.WHITE)


func _top_score_line() -> String:
	var table: Array = HighScores.get_table("racer")
	if table.is_empty():
		return ""
	var row: Array = table[0]
	return "%s %s" % [row[0], ScoreTable.format_score(int(row[1]))]


## Car select (D-122): three cars in a showroom, flippers choose, Launch/Start
## confirms (or the timer picks the highlighted one).
# --- graphics: HD / RETRO (D-195) ------------------------------------------------------
## --rc-gfx=nes|retro|hd (dev), else the last choice, else 16-BIT.
func _start_gfx() -> String:
	var g := str(Config.cli.get("rc-gfx", Config.get_value("racer", "graphics", "retro")))
	return g if g in GFX_OPTIONS else "retro"


## RETRO: the world at PIXEL_RES through the 16-bit palette/dither pass (D-107,
## D-194). HD: the world at the TABLE's own resolution with 4x MSAA, no pixel
## pass, the high-res sprite cut-outs and car textures, smooth filtering, and
## the road without its 25 cm texels.
## 8-BIT (D-207): as RETRO at NES_RES, with the post pass snapping to its
## fixed palette.
func _apply_gfx(mode: String) -> void:
	_gfx_mode = mode
	_anim_mult = {"nes": 1.0, "retro": 2.0}.get(mode, 0.0)
	_set_ui_res.call_deferred()   # D-233
	var on := mode == "hd"
	_gfx_hd = on
	var low := _low_res(mode)   # D-254: at the TABLE's shape
	_retro_post.set_shader_parameter("low_res", Vector2(low))
	_retro_post.set_shader_parameter("nes", mode == "nes")
	var q: Array = QUALITY_STEPS[_quality if _auto_quality() else 0]
	_pix_vp.size = Vector2i((_table_px() * float(q[1])).round()) if on else low
	_pix_vp.msaa_3d = (q[0] as Viewport.MSAA) if on else Viewport.MSAA_DISABLED
	_world_view.material = null if on else _retro_post
	_world_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if on else CanvasItem.TEXTURE_FILTER_NEAREST
	Sprites.set_hd(on)
	if _road_mat != null:
		_road_mat.set_shader_parameter("hd", on)
		_puddle_mat.set_shader_parameter("hd", on)
	for m in _car_mats.values():
		(m as ShaderMaterial).set_shader_parameter("hd", on)
	if on:
		_refilter(_root)
	else:
		for m in _hd_flipped:
			if is_instance_valid(m):
				(m as BaseMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_hd_flipped.clear()


## HD: every nearest-filtered material under `root` turns smooth (remembered,
## so RETRO can put it back).
func _refilter(root: Node) -> void:
	var nodes: Array = [root]
	nodes.append_array(root.find_children("*", "GeometryInstance3D", true, false))
	for g in nodes:
		if not (g is GeometryInstance3D):
			continue
		var mats: Array = [g.material_override, g.material_overlay]
		var mesh: Mesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
			for si in (g as MeshInstance3D).get_surface_override_material_count():
				mats.append((g as MeshInstance3D).get_surface_override_material(si))
		elif g is CPUParticles3D:
			mesh = (g as CPUParticles3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		if mesh != null:
			for si in mesh.get_surface_count():
				mats.append(mesh.surface_get_material(si))
		for m in mats:
			while m is BaseMaterial3D:
				if (m as BaseMaterial3D).texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST:
					(m as BaseMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					_hd_flipped[m] = true
				m = (m as Material).next_pass


## Pieces built while racing (road chunks, props) get HD filtering too.
func _on_world_node_added(n: Node) -> void:
	if _gfx_hd and n is GeometryInstance3D and _root != null and _root.is_ancestor_of(n):
		_refilter(n)


func _begin_gfx() -> void:
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_phase = "gfx"
	_phase_t = 0.0
	Audio.sfx("start")
	_gfx_index = maxi(GFX_OPTIONS.find(_gfx_mode), 0)
	_gfx_ui = Control.new()
	_gfx_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gfx_ui.add_child(UI.fill(Color(0, 0, 0, 0.35)))
	var col := UI.vstack(60)
	col.add_child(UI.styled_label(tr("RC_GFX_TITLE"), TITLE_FONT, 2))
	_gfx_rows.clear()
	for g in GFX_OPTIONS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_l := UI.label("", 96, UI.WHITE)
		row.add_child(name_l)
		row.add_child(UI.label(tr(GFX_DESC[g]), 36, UI.WHITE))
		col.add_child(row)
		_gfx_rows.append([name_l, row])
	_gfx_hint = UI.label("", 36, UI.WHITE)
	col.add_child(_gfx_hint)
	_gfx_ui.add_child(col)
	_add_ui(_gfx_ui)
	_refresh_gfx()


## Flippers step through 8-BIT / 16-BIT / HD, shown live on the road behind.
func _move_gfx(i: int) -> void:
	_phase_t = 0.0
	if i == _gfx_index:
		return
	_gfx_index = i
	Audio.sfx("rc_shift")
	_apply_gfx(GFX_OPTIONS[i])
	_refresh_gfx()


func _refresh_gfx() -> void:
	for i in _gfx_rows.size():
		var on := i == _gfx_index
		var name_l: Label = _gfx_rows[i][0]
		var g: String = GFX_OPTIONS[i]
		name_l.text = ("> %s <" % tr(GFX_NAMES[g])) if on else tr(GFX_NAMES[g])
		name_l.add_theme_color_override("font_color", ACCENT if on else UI.WHITE)
		(_gfx_rows[i][1] as Control).modulate.a = 1.0 if on else 0.45
	var cur: String = GFX_OPTIONS[_gfx_index]
	_dmd.show_text(tr("RC_GFX_TITLE"), tr(GFX_NAMES[cur]), Dmd.CYAN, Dmd.YELLOW)


func _confirm_gfx() -> void:
	if _phase != "gfx":
		return
	var g: String = GFX_OPTIONS[_gfx_index]
	# Remembered for next time (not from scripted test runs, which mustn't save).
	if not Config.cli.has("press") and str(Config.get_value("racer", "graphics", "retro")) != g:
		Config.set_value("racer", "graphics", g)
		Config.save()
	if is_instance_valid(_gfx_ui):
		_gfx_ui.queue_free()
	_begin_stage_select()


# --- start stage (D-216, for testing) ------------------------------------------------
## Flippers pick the stage the race starts at (1..STAGE_PICK_MAX), with its
## area's name; Launch confirms. Not saved: every game starts the picker at 1.
const STAGE_PICK_MAX := 10
const AREA_NAMES := {"beach": "RC_AREA_BEACH", "fields": "RC_AREA_FIELDS", "city": "RC_AREA_CITY",
	"desert": "RC_AREA_DESERT", "forest": "RC_AREA_FOREST", "snow": "RC_AREA_SNOW"}


func _begin_stage_select() -> void:
	_phase = "stage"
	_phase_t = 0.0
	_start_stage = 1
	_stage_ui = Control.new()
	_stage_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_ui.add_child(UI.fill(Color(0, 0, 0, 0.35)))
	var col := UI.vstack(40)
	col.add_child(UI.styled_label(tr("RC_STAGE_TITLE"), TITLE_FONT, 2))
	_stage_num = UI.label("", 96, ACCENT)
	col.add_child(_stage_num)
	_stage_area = UI.label("", 48, UI.WHITE)
	col.add_child(_stage_area)
	_stage_hint = UI.label("", 36, UI.WHITE)
	col.add_child(_stage_hint)
	_stage_ui.add_child(col)
	_add_ui(_stage_ui)
	_refresh_stage()


func _move_stage(d: int) -> void:
	_phase_t = 0.0
	var n := clampi(_start_stage + d, 1, STAGE_PICK_MAX)
	if n == _start_stage:
		return
	_start_stage = n
	Audio.sfx("rc_shift")
	_refresh_stage()


func _refresh_stage() -> void:
	_stage_num.text = "< %s >" % (tr("RC_STAGE") % _start_stage)
	_stage_area.text = tr(AREA_NAMES[Track.stage_area(_start_stage)])
	_dmd.show_text(tr("RC_STAGE_TITLE"), tr("RC_STAGE") % _start_stage, Dmd.CYAN, Dmd.YELLOW)


func _confirm_stage() -> void:
	if _phase != "stage":
		return
	if is_instance_valid(_stage_ui):
		_stage_ui.queue_free()
	_begin_select()


func _begin_select() -> void:
	_set_ui_res.call_deferred()   # D-254: a portrait panel in landscape
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_phase = "select"
	_phase_t = 0.0
	Audio.sfx("start")
	_world_view.visible = false
	_showroom = Showroom.new()
	_showroom.hd = _gfx_hd
	_showroom.landscape = _landscape()   # D-255: the cars side by side
	_showroom.nes = _gfx_mode == "nes"
	_add_ui(_showroom)
	_showroom.selected = _p2_car if _select_p2 else _chosen_car
	if _two:   # D-289: whose choice it is
		var who := UI.label(tr("RC_CHOOSE_P") % (2 if _select_p2 else 1), 48, UI.YELLOW if not _select_p2 else UI.CYAN)
		who.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)   # (the DMD covers the top)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		who.offset_top = -170
		who.offset_bottom = -100
		_showroom.add_child.call_deferred(who)
	_showroom.build(func(_hue: float, i: int) -> Node3D:
		var m: String = CAR_MODELS[i]
		return _car_instance(_car_hue(i), m, MODEL_TEXTURES[m]), load(SKY_TEXTURE), TITLE_FONT)   # D-236
	_select_hint = UI.label("", 36, UI.WHITE)
	_select_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_select_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_hint.offset_top = -90
	_select_hint.offset_bottom = -40
	_showroom.add_child(_select_hint)
	_dmd.show_custom(_draw_dmd_select)


func _confirm_car() -> void:
	if _phase != "select":
		return
	if _two and not _select_p2:   # D-289: then player 2 picks theirs
		_chosen_car = _showroom.selected
		_hues[0] = _car_hue(_chosen_car)
		_showroom.queue_free()
		_showroom = null
		_select_p2 = true
		_begin_select()
		return
	if _select_p2:
		_p2_car = _showroom.selected
		_hues[1] = _car_hue(_p2_car)
		if _p2_car == _chosen_car and is_equal_approx(_hues[1], _hues[0]):
			_hues[1] = fposmod(_hues[0] + float(PAINTS[1]), 1.0)   # never two identical cars
		_select_p2 = false
	else:
		_chosen_car = _showroom.selected
	_showroom.queue_free()
	_set_ui_res.call_deferred()   # D-254: back to the HUD's layout
	_showroom = null
	_world_view.visible = true
	_begin_race()


## DMD while choosing (D-122): the car in its colour, its name, top speed and
## cornering pips, with arrows to the other choices.
func _draw_dmd_select(p) -> void:
	if not is_instance_valid(_showroom):
		return
	var i: int = _showroom.selected
	var spec: Dictionary = Sim.CARS[i]
	var col: Color = CAR_COLS[i]
	_anims._car(p, 5, 13, col)
	p.text(tr(spec.name), 24, 1, 1, Showroom.ROW_COLS[i])
	p.text(tr("RC_DMD_TOP") % roundi(float(spec.top) * Sim.MPH), 24, 12, 1, Dmd.WHITE)
	p.text(tr("RC_DMD_CORNER"), 24, 23, 1, Dmd.DIM)
	var x0: float = 26 + p.text_width(tr("RC_DMD_CORNER"))
	for k in Showroom.PIPS:
		p.block(x0 + k * 6, 23, 5, 5, col if k < Showroom.corner_pips(i) else Color(0.16, 0.18, 0.22))
	if i > 0:
		for d in 4:
			p.line(122 - d, 4 + d, 126 + d, 4 + d, Dmd.WHITE)   # up arrow: the car above
	if i < 2:
		for d in 4:
			p.line(122 - d, 28 - d, 126 + d, 28 - d, Dmd.WHITE)


func _begin_race() -> void:
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_build_body(CAR_MODELS[_chosen_car])   # the hot hatch for the easy car (D-205)
	if _anims.police_sprite == null:   # D-245
		_anims.police_sprite = _dmd_image("res://assets/textures/racer/dmd_car_police.png")
	_anims.player_sprite = _painted(_dmd_sprite(CAR_MODELS[_chosen_car]), _car_hue(_chosen_car))   # D-243, D-244
	_phase = "race"
	_phase_t = 0.0
	_new_sim()
	if _two:
		_go_split()
	_shift_armed = true
	_shift_shown = false
	_paint_hero()
	# The start stage's song (D-226): stage 1 carries on attract's from where it
	# is; a later start stage (testing) plays its own from the top.
	_music(_stage_music(sim.checkpoints + 1))
	Audio.sfx("start")
	_hud.visible = true
	_show_mode()
	_center_message("3", 1.0)
	Audio.sfx("rc_count")
	_dmd.show_custom(_draw_dmd_revup)   # REV UP! with a live tacho (D-154)
	_last_tick = -1
	if _two:
		Dmd.show_custom(_draw_dmd_two)


## The hero car in the chosen car's colour (D-122; 2P: each player's, D-289).
func _paint_hero() -> void:
	var hue: float = _hues[_role] if _two else _car_hue(_chosen_car)
	for m in _car_body.find_children("*", "MeshInstance3D", true, false):
		var gi := m as MeshInstance3D
		if gi.material_override != null:
			InstParam.set_param(gi, "hue", hue)


func _begin_finale() -> void:
	_phase = "finale"
	_finale_t = 0.0


func _finale(delta: float) -> void:
	var before := _finale_t
	_finale_t += delta
	if before < FINALE_TEXT_AT and _finale_t >= FINALE_TEXT_AT:
		if is_instance_valid(_center):   # D-234: the results title replaces the banner
			_center.queue_free()
		_finale_ui = UI.vstack(40)
		var dim := UI.fill(Color(0, 0, 0, 0.55))
		_add_ui(dim)
		if _two:   # D-289: each half shows its player's place
			var won: bool = sim.winner == _role
			_finale_ui.add_child(UI.styled_label(tr("RC_WINNER") if won else tr("RC_SECOND"), TITLE_FONT, 3))
			_finale_ui.add_child(UI.styled_label(tr("RC_PLAYER_N") % (_role + 1), TITLE_FONT, 2))
			if _main:
				Dmd.show_text(tr("RC_P_WINS") % (maxi(sim.winner, 0) + 1), "", Dmd.YELLOW, Dmd.WHITE)
		else:
			_finale_ui.add_child(UI.styled_label(tr("RC_FINISH") if sim.finished else tr("DMD_GAME_OVER"), TITLE_FONT, 3))
		_finale_ui.add_child(UI.spacer(30))
		if sim.finished and not _two:   # D-221
			_finale_ui.add_child(UI.styled_label(tr("RC_TIME_BONUS") % ScoreTable.format_score(sim.time_bonus), TITLE_FONT, 2))
		if not _two:   # (2P: a race, not a score, D-289)
			_finale_ui.add_child(UI.styled_label(tr("RC_FINAL_SCORE"), TITLE_FONT, 2))
			_finale_ui.add_child(UI.styled_label(ScoreTable.format_score(sim.score), TITLE_FONT, 2))
		# Distance in the score's styled font, tinted cyan (D-116).
		var dist := UI.styled_label(tr("RC_DISTANCE") % (sim.s / 1609.34), TITLE_FONT, 2)   # miles (D-147)
		dist.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
		_finale_ui.add_child(dist)
		_add_ui(_finale_ui)
		_dmd.show_text(tr("RC_FINISH") if sim.finished else tr("DMD_GAME_OVER"), ScoreTable.format_score(sim.score), Dmd.YELLOW if sim.finished else Dmd.RED, Dmd.YELLOW)
	if _finale_t >= FINALE_END_AT:
		_finale_t = -100.0
		set_process(false)
		if _two:
			if _main:
				finished.emit([])   # D-289: no high score for a 2-player race
		else:
			finished.emit([sim.score])


# --- 2 players (D-289) ----------------------------------------------------------------------
func _begin_players() -> void:
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_phase = "players"
	_phase_t = 0.0
	Audio.sfx("start")
	_players_ui = Control.new()
	_players_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_players_ui.add_child(UI.fill(Color(0, 0, 0, 0.35)))
	var col := UI.vstack(60)
	_players_rows.clear()
	for k in ["RC_ONE_PLAYER", "RC_TWO_PLAYERS"]:
		var l := UI.label(tr(k), 96, UI.WHITE)
		col.add_child(l)
		_players_rows.append(l)
	_players_ui.add_child(col)
	_add_ui(_players_ui)
	_refresh_players()


func _refresh_players() -> void:
	for i in _players_rows.size():
		var l: Label = _players_rows[i]
		var on := i == _players_sel
		var t := tr(["RC_ONE_PLAYER", "RC_TWO_PLAYERS"][i])
		l.text = ("> %s <" % t) if on else t
		l.add_theme_color_override("font_color", ACCENT if on else UI.WHITE)
		l.modulate.a = 1.0 if on else 0.45
	_dmd.show_text(tr(["RC_ONE_PLAYER", "RC_TWO_PLAYERS"][_players_sel]), "", Dmd.CYAN, Dmd.YELLOW)


func _confirm_players() -> void:
	if is_instance_valid(_players_ui):
		_players_ui.queue_free()
	if _players_sel == 1:
		_two = true
		CabinetInput.set_two_player(true)
	_begin_gfx()


## Splits the TABLE in two halves (once): this view moves into the left one,
## player 2's view is built in the right one, both following the shared race.
func _go_split() -> void:
	_dmd = QuietDmd.new()
	if _host == null:
		var split := Control.new()
		split.name = "SplitScreen"
		split.mouse_filter = Control.MOUSE_FILTER_IGNORE
		super.add_to_table(split)
		split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var halves := []
		for i in 2:
			var h := Control.new()
			h.clip_contents = true
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			split.add_child(h)
			h.anchor_left = 0.5 * i
			h.anchor_right = 0.5 * (i + 1)
			h.anchor_top = 0.0
			h.anchor_bottom = 1.0
			h.offset_left = 0.0
			h.offset_right = 0.0
			h.offset_top = 0.0
			h.offset_bottom = 0.0
			halves.append(h)
		var line := ColorRect.new()
		line.color = Color.BLACK
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		split.add_child(line)
		line.anchor_left = 0.5
		line.anchor_right = 0.5
		line.anchor_bottom = 1.0
		line.offset_left = -3.0
		line.offset_right = 3.0
		_host = halves[0]
		for n in _owned:
			if is_instance_valid(n) and n != split and n.get_parent() == Screens.table:
				n.reparent(_host, false)
		_on_table_shape()
		_p2 = get_script().new()
		_p2._role = 1
		_p2._two = true
		_p2._main = false
		_p2._host = halves[1]
		_p2.name = "Player2View"
		add_child(_p2)
	_p2._start_p2(self)
	_build_rival(_p2_car, _hues[1])
	if is_instance_valid(_time_caption):
		_time_caption.text = tr("RC_POSITION")


## Player 2's view (D-289): built like the module's own, then straight into
## the race that player 1's view has just set up.
func _start_p2(p1: Node) -> void:
	_dmd = QuietDmd.new()
	sim = p1.sim
	_chosen_car = p1._p2_car
	_hues = p1._hues.duplicate()
	if _root == null:
		if not Screens.table_shape_changed.is_connected(_on_table_shape):
			Screens.table_shape_changed.connect(_on_table_shape)
		Toon.enabled = not Config.cli.has("rc-no-toon")
		_build_world()
		_apply_gfx(p1._gfx_mode)
		get_tree().node_added.connect(_on_world_node_added)
		_build_hud()
		_build_audio_loops()
		_on_table_shape.call_deferred()
	_build_body(CAR_MODELS[_chosen_car])
	_phase = "race"
	_phase_t = 0.0
	_finale_t = -1.0
	for k in _chunks.keys():
		_chunks[k].queue_free()
	_chunks.clear()
	_cam_ready = false
	_used_gas = false
	_over_turn = 0.0
	_over_dir = 0.0
	_shift_armed = true
	_shift_shown = false
	_paint_hero()
	_hud.visible = true
	_show_mode()
	_center_message("3", 1.0)
	_last_tick = -1
	_build_rival(p1._chosen_car, _hues[0])


## The other player's car (D-289): the model and colour they chose.
func _build_rival(car_i: int, hue: float) -> void:
	if is_instance_valid(_rival):
		_rival.queue_free()
	var m: String = CAR_MODELS[car_i]
	_rival = _car_instance(hue, m, MODEL_TEXTURES[m])
	_add_headlights(_rival, "car")
	_rival.set_meta("night", Night.add_car_lights(_rival, "car", _puff_texture(), TAIL_AT[MODEL_LIGHTS[m]]))
	_place_tails(_rival, _rival.get_meta("night"), m)
	_root.add_child(_rival)


## Draws the other player's car where the shared race has it: yawed by its
## drift and side-impact sway, spinning or slewed across on a crash.
func _animate_rival(delta: float, cam_yaw: float) -> void:
	if not _two or not is_instance_valid(_rival):
		return
	var o := 1 - _role
	var tr_ := sim.track
	var rs: float = sim.player_get(o, "s")
	var rx: float = sim.player_get(o, "x")
	_rival.visible = absf(rs - sim.s) < VIEW_AHEAD
	if not _rival.visible:
		return
	_rival.transform = tr_.frame(rs, rx)
	var yaw := deg_to_rad(float(sim.player_get(o, "drift_angle"))) + float(sim.player_get(o, "sway"))
	var spin: float = sim.player_get(o, "spin_t")
	var anim: float = sim.player_get(o, "crash_anim")
	if spin > 0.0 and anim > 0.0:
		var cp := clampf(1.0 - (spin - Sim.CRASH_STOP) / anim, 0.0, 1.0)
		if sim.player_get(o, "flipping"):
			yaw += clampf(cp / FLIP_TURN_END, 0.0, 1.0) * PI * 0.5 * float(sim.player_get(o, "flip_dir"))
		else:
			yaw += _anim_steps(cp, anim) * TAU * 2.0
	var h := tr_.heading(rs)
	_rival.basis = _rival.basis * Basis(Vector3.UP, _sprite_yaw(h + yaw, cam_yaw) - h) * MODEL_TURN
	var rv: float = sim.player_get(o, "v")
	_rival_wheel = fmod(_rival_wheel + minf(rv / 0.32, WHEEL_MAX) * delta, TAU * 100.0)
	for m in _rival.find_children("*", "MeshInstance3D", true, false):
		var gi := m as MeshInstance3D
		if gi.material_override != null:
			InstParam.set_param(gi, "spin", 1.0)
			InstParam.set_param(gi, "wheel_phase", _rival_wheel)
			InstParam.set_param(gi, "wheel_blur", clampf((rv - 6.0) / 20.0, 0.0, 1.0))
			InstParam.set_param(gi, "lamps", _lamps)
			InstParam.set_param(gi, "overhead", _overhead(rs))
	(_rival.get_meta("night") as Node3D).visible = _lamps > 0.0


## The DMD in a 2-player race (D-289): each player's stage and speed, and a
## strip with both cars along the whole race (P1 yellow, P2 cyan).
func _draw_dmd_two(p) -> void:
	if sim == null or not sim.two_player:
		return
	var cols := [Dmd.YELLOW, Dmd.CYAN]
	for i in 2:
		var x0 := 2 + i * 64
		var tag := tr("RC_DMD_P") % (i + 1)
		p.text(tag, x0, 2, 1, cols[i])
		var spd := str(roundi(float(sim.player_get(i, "v")) * Sim.MPH))
		p.text(spd, x0 + 60 - p.text_width(spd), 2, 1, Dmd.WHITE)
		var st: String = tr("RC_FINISH") if sim.player_get(i, "finished") else tr("RC_STAGE") % (int(sim.player_get(i, "checkpoints")) + 1)
		p.text(st, x0, 12, 1, Dmd.DIM)
	var total := float(Sim.FINISH_STAGE) * Sim.CHECKPOINT_EVERY
	p.line(2, 27, 125, 27, Color(0.2, 0.22, 0.26))
	for k in range(1, Sim.FINISH_STAGE):
		var gx := 2.0 + 123.0 * k / Sim.FINISH_STAGE
		p.line(gx, 26, gx, 28, Color(0.3, 0.32, 0.36))
	for i in 2:
		var fx := 2.0 + 123.0 * clampf(float(sim.player_get(i, "s")) / total, 0.0, 1.0)
		p.block(roundi(fx) - 1, 24 + i * 4 - 1, 3, 3, cols[i])


# --- events --------------------------------------------------------------------------
func _handle_events() -> void:
	for k in sim.events.size():
		var e: Array = sim.events[k]
		if _two:   # D-289: this view's player's events, and the shared ones
			var who := int(sim.event_player[k]) if k < sim.event_player.size() else -1
			if who != _role and who != -1:
				continue
		match e[0]:
			"winner":
				if int(e[1]) != _role:
					_center_message(tr("RC_P_WINS") % (int(e[1]) + 1), 3.0)
				if _main:
					Dmd.flash(tr("RC_P_WINS") % (int(e[1]) + 1), 3.0, Dmd.YELLOW)
			"count":
				_center_message(str(e[1]), 1.0)
				Audio.sfx("rc_count")
				_dmd.show_custom(_draw_dmd_revup)
			"go":
				if Config.cli.has("rc-police") and sim.police.is_empty():   # dev: a chase straight away (D-246)
					sim.call_police()
				_center_message(tr("RC_GO"), 1.0)
				Audio.sfx("rc_go")
				_dmd.flash(tr("RC_GO"), 1.0, Dmd.GREEN)
			"checkpoint":
				_bg_flash = 1.2
				Audio.sfx("rc_checkpoint")
				# A new song every MUSIC_STAGES stages (D-226), crossfaded in from
				# a little way into it.
				var stage := int(e[1]) + 1
				if _stage_music(stage) != Audio.current_music():
					_crossfade(_stage_music(stage), MUSIC_XFADE, MUSIC_SKIP[MUSIC_RACE.find(_stage_music(stage))])
				# Reached on momentum after TIME UP: the race goes on (D-103).
				var saved: bool = e.size() > 3 and e[3]
				# No CHECKPOINT notice mid-TABLE (D-142): the gate, DMD and sound
				# say it; JUST MADE IT! still shows when it saves the race.
				if saved:
					_center_message(tr("RC_JUST_MADE_IT"), 1.6)
				_dmd_anim("checkpoint", [tr("RC_CHECKPOINT"), tr("RC_EXTENDED") % int(e[2])])
			"finish":
				Audio.sfx("fanfare")
				if _two:   # D-289: first or second across the line
					_center_message(tr("RC_WINNER") if sim.winner == _role else tr("RC_SECOND"), 4.0)
				else:
					_center_message(tr("RC_FINISH"), 4.0)
				_dmd.flash(tr("RC_FINISH"), 4.0, Dmd.YELLOW)
				_bg_flash = 0.6
			"time_up":
				Audio.sfx("rc_time_up")
				_center_message(tr("RC_TIME_UP"), 3.0)
				_dmd.flash(tr("RC_TIME_UP"), 3.0, Dmd.RED)
			"drift_start":
				pass
			"drift_end":
				if int(e[1]) > 0:
					Audio.sfx("rc_drift_bank")
					_drift_label.text = tr("RC_DRIFT_POINTS") % ScoreTable.format_score(int(e[1]))
					_dmd_anim("drift", [tr("RC_DRIFT"), ScoreTable.format_score(int(e[1]))])
					_drift_label.modulate.a = 1.0
			"nitro", "nitro_refill":
				_bg_flash = 0.6
				Audio.sfx("rc_nitro")
				_nitro_pop_t = 0.8   # small notice over the speedometer (D-159)
				_dmd_anim("nitro", [tr("RC_NITRO")])
				_shake = 0.3
			"high_beams":
				_honk(int(e[1]))
			"perfect_start":
				Audio.sfx("rc_perfect")
				Audio.sfx("rc_backfire")
				_dmd_anim("perfect", [tr("RC_PERFECT_START")])
				_bg_flash = 0.6
				_shake = 0.3
			"perfect_shift":
				Audio.sfx("rc_perfect")
				Audio.sfx("rc_backfire")
				_dmd_anim("perfect", [tr("RC_PERFECT_SHIFT")])
				_bg_flash = 0.5
				_shake = 0.25
			"shift":
				Audio.sfx("rc_shift")
				# Upshift: a short exhaust flame + backfire; downshift: tyre smoke
				# + a chirp (D-112).
				if int(e[1]) == Sim.Gear.HIGH:
					_shift_flame_t = 0.16
					Audio.sfx("rc_backfire")
				else:
					_shift_smoke_t = 0.5
					if sim.spin_t <= 0.0:
						Audio.sfx("rc_chirp")
				if sim.spin_t <= 0.0:   # a crash's own downshift shows the crash instead
					_dmd_anim("shift", [int(e[1]) == Sim.Gear.HIGH, tr("RC_GEAR"), tr("RC_GEAR_H"), tr("RC_GEAR_L")])
			"near_miss":
				_bg_flash = 0.4
				Audio.sfx("rc_near_miss")
				_dmd_anim("near_miss", [tr("RC_NEAR_MISS"), "+" + ScoreTable.format_score(5000)])
			"pass":
				pass
			"bump":
				Audio.sfx("rc_bump")
				_shake = maxf(_shake, 0.25)
			"police_spawn":
				_center_message(tr("RC_POLICE"), 1.4)
				_cops_flash = true   # red/blue flashing text (D-158)
				_dmd.flash(tr("RC_POLICE"), 1.4, Dmd.RED)
			"police_ram":
				Audio.sfx("rc_bump")
				_shake = 0.45
				_bg_dark = 0.3
			"police_bumped":   # we ran into the police car (D-198)
				Audio.sfx("rc_bump")
				_shake = 0.3
			"police_hits_reset":   # its rams start counting again (D-198)
				_dmd.flash(tr("RC_RAMS_RESET"), 1.0, Dmd.GREEN)
			"busted":
				_center_message(tr("RC_BUSTED"), 2.5)
				_dmd_anim("fine", [tr("RC_BUSTED"), tr("RC_FINE"), "-" + ScoreTable.format_score(int(e[1]))])
				Audio.sfx("rc_time_up")
			"police_escape":
				_center_message(tr("RC_ESCAPED"), 1.4)
				_dmd.flash(tr("RC_ESCAPED"), 1.2, Dmd.GREEN)
				Audio.sfx("rc_perfect")
			"crash":
				_shift_armed = true   # the SHIFT hint may show again (D-160)
				_bg_dark = 0.8
				Audio.sfx("rc_crash")
				_shake = 0.8
				_dmd_anim("crash", [tr("RC_CRASH")])


# --- world ---------------------------------------------------------------------------
## D-254: the TABLE's shape (base size): 1080x1920 normally, or the screen's
## own shape in the single-screen layout.
func _table_base() -> Vector2i:
	var b := Screens.table_base()
	return Vector2i(b.x / 2, b.y) if _host != null else b   # D-289: half each


func _landscape() -> bool:
	var b := _table_base()
	return b.x > b.y


## The 3D view's low resolution for the pixel modes, at the TABLE's shape: the
## short side 480 (16-BIT) or 270 (8-BIT) pixels, as in portrait.
func _low_res(mode: String) -> Vector2i:
	var short := 270.0 if mode == "nes" else 480.0
	var b := Vector2(_table_base())
	var k := short / minf(b.x, b.y)
	return Vector2i(roundi(b.x * k), roundi(b.y * k))


## The UI layer's base and where it sits on the TABLE (D-254): portrait = the
## whole TABLE; landscape = a 1920x1080 area, centred (16:9 at most); car select
## = a 1080x1920 panel, centred (its art is portrait).
func _ui_base() -> Vector2i:
	if _landscape():
		return Vector2i(1920, 1080)
	return _table_base()


## D-254: the HUD for the TABLE's shape. Landscape: the clock joins the score on
## the left (the DMD sits over the top centre), the tacho at the bottom left,
## gear and speedo at the bottom right, the radar lights out to the sides.
func _hud_layout() -> void:
	if _hud_top == null:
		return
	var land := _landscape()
	var in_left := _hud_mid.get_parent() == _hud_left
	if land and not in_left:
		_hud_top.remove_child(_hud_mid)
		_hud_left.add_child(_hud_mid)
		_hud_left.move_child(_hud_mid, 2)
	elif not land and in_left:
		_hud_left.remove_child(_hud_mid)
		_hud_top.add_child(_hud_mid)
		_hud_top.move_child(_hud_mid, 1)
	_hud_mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hud_gap.visible = land
	# Landscape: the left column hugs the left edge, clear of the DMD.
	for l in _hud_left.find_children("*", "Label", true, false):
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if land else HORIZONTAL_ALIGNMENT_CENTER
	if is_instance_valid(_radar_bar):
		var w := float(_ui_base().x)
		_radar_bar.size = Vector2(w, _radar_bar.custom_minimum_size.y)
		_radar_bar.center_gap = 520.0 if land else 0.0
		_radar_bar.queue_redraw()


## D-283: phones and browsers only; cabinets and the PC build keep full quality.
func _auto_quality() -> bool:
	return (OS.has_feature("web") or OS.has_feature("android") or Config.cli.has("rc-auto-quality")) \
		and not Config.cli.has("rc-full-quality")


## While racing in HD: two measuring windows in a row under about 48 fps take
## the world's quality down one step (never back up: each change is a hitch).
func _watch_quality(delta: float) -> void:
	if not _gfx_hd or not _auto_quality() or _quality >= QUALITY_STEPS.size() - 1 or get_tree().paused:
		return
	if sim.state != Sim.State.RACE or delta > 0.25:   # not on the grid; not a one-off stall
		return
	_q_t += delta
	_q_n += 1
	if _q_t < QUALITY_WINDOW:
		return
	_q_bad = _q_bad + 1 if _q_t / _q_n > QUALITY_SLOW else 0
	_q_t = 0.0
	_q_n = 0
	if _q_bad >= 2:
		_q_bad = 0
		_quality += 1
		print("Turbo Run: quality step %d (frame rate too low)" % _quality)
		_apply_gfx(_gfx_mode)


func _set_reverb(on: bool) -> void:
	if on == _reverb_on:
		return
	_reverb_on = on
	var bus := AudioServer.get_bus_index("SFX")
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == _reverb:
			AudioServer.set_bus_effect_enabled(bus, i, on)


func _on_table_shape() -> void:
	_apply_gfx(_gfx_mode)
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT if _landscape() else Camera3D.KEEP_WIDTH
	_hud_layout()


## The UI layer (D-233): a transparent viewport laid out in TABLE base
## coordinates, shown over the 3D view (and the police wash).
func _build_ui_layer() -> void:
	if _ui_vp != null:
		return
	_ui_vp = SubViewport.new()
	_ui_vp.transparent_bg = true
	_ui_vp.size = Screens.TABLE_BASE
	_ui_vp.size_2d_override = Screens.TABLE_BASE
	_ui_vp.size_2d_override_stretch = true
	_ui_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ui_vp.disable_3d = false
	add_to_table(_ui_vp)
	_ui_root = Control.new()
	_ui_root.size = Vector2(Screens.TABLE_BASE)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_vp.add_child(_ui_root)
	_ui_view = TextureRect.new()
	_ui_view.texture = _ui_vp.get_texture()
	_ui_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ui_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # D-254
	_ui_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_table(_ui_view)
	get_tree().node_added.connect(_on_ui_node_added)
	_set_ui_res()


## Adds a piece of UI to the UI layer (D-233).
func _add_ui(node: Node) -> Node:
	if _ui_vp == null:
		_build_ui_layer()
	_ui_root.add_child(node)
	return node


## The UI layer's resolution for the graphics mode (D-233): full in HD; in
## 8-BIT/16-BIT the 3D view's own low resolution, upscaled with hard pixels,
## and every dot-font label rebuilt for that resolution.
func _set_ui_res() -> void:
	if _ui_vp == null:
		return
	var low := _gfx_mode != "hd"
	var base := _ui_base()   # D-254
	_ui_vp.size_2d_override = base
	_ui_root.size = Vector2(base)
	var res: Vector2i = base
	if low:
		var short := 270.0 if _gfx_mode == "nes" else 480.0
		var k := short / float(mini(base.x, base.y))
		res = Vector2i(roundi(base.x * k), roundi(base.y * k))
	else:
		# Full resolution: the TABLE's own pixels for the area the UI covers.
		var tb := Vector2(_table_base())
		var px := _table_px() / tb
		res = Vector2i(roundi(base.x * px.x), roundi(base.y * px.y))
	_ui_vp.size = res
	_ui_vp.snap_2d_transforms_to_pixel = low
	_ui_vp.snap_2d_vertices_to_pixel = low
	_ui_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST if low \
		else Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	_ui_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if low else CanvasItem.TEXTURE_FILTER_LINEAR
	_ui_px = float(res.x) / float(base.x)
	for n in _ui_root.find_children("*", "Label", true, false):
		_refont(n as Label)


func _refont(l: Label) -> void:
	if l.has_meta("dot_size"):
		l.add_theme_font_override("font", DotText.font(int(l.get_meta("dot_size")), _ui_px))


func _on_ui_node_added(n: Node) -> void:
	if n is Label and _ui_root != null and _ui_root.is_ancestor_of(n):
		_refont(n as Label)


func _build_world() -> void:
	_root = Node3D.new()
	_root.name = "TurboRunWorld"
	# Pixel renderer (D-107): the world renders at PIXEL_RES in its own
	# viewport, shown full-screen with nearest upscaling + a palette/dither
	# pass; the HUD on top stays at full resolution.
	_pix_vp = SubViewport.new()
	_pix_vp.size = PIXEL_RES
	_pix_vp.own_world_3d = true
	_pix_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pix_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_to_table(_pix_vp)
	_pix_vp.add_child(_root)
	var view := TextureRect.new()
	_world_view = view
	view.texture = _pix_vp.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var post := ShaderMaterial.new()
	post.shader = PIXEL_POST
	post.set_shader_parameter("low_res", Vector2(PIXEL_RES))
	post.set_shader_parameter("levels", 32.0)   # D-194: gentler bands (default 24)
	post.set_shader_parameter("dither", 0.45)   # D-194: lighter dither (default 0.6)
	view.material = post
	_retro_post = post
	add_to_table(view)
	_build_ui_layer.call_deferred()
	# Police light wash (D-137): red and blue glows from the screen edges.
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 2:
		var g := Gradient.new()
		var c: Color = Color(0.15, 0.3, 1.0) if i == 0 else Color(1.0, 0.1, 0.08)   # left blue, right red
		g.set_color(0, c if i == 0 else Color(c, 0.0))
		g.set_color(1, Color(c, 0.0) if i == 0 else c)
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 64
		gt.height = 4
		var wash := TextureRect.new()
		wash.texture = gt
		wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wash.stretch_mode = TextureRect.STRETCH_SCALE
		wash.material = add_mat
		wash.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE if i == 0 else Control.PRESET_RIGHT_WIDE)
		if i == 0:
			wash.offset_right = 540
		else:
			wash.offset_left = -540
		wash.modulate.a = 0.0
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_to_table(wash)
		_washes.append(wash)
	var env := WorldEnvironment.new()
	_env = Environment.new()
	# The sky (D-193): procedural, one sun, driven by the time of day.
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	_sky_mat = sky_mat
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32   # lighting uses colours, not the sky's radiance
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.ambient_light_color = Color(0.75, 0.65, 0.8)
	_env.ambient_light_energy = 0.7
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_light_color = Color(0.66, 0.78, 0.92)   # set by the time of day each frame
	_env.fog_depth_begin = 250.0
	_env.fog_depth_end = VIEW_AHEAD - 50.0
	_env.fog_sky_affect = 0.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_hdr_threshold = 1.0
	env.environment = _env
	_root.add_child(env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-28, 160, 0)   # aimed by the time of day each frame (D-193)
	_sun.light_color = Color(1.0, 0.85, 0.7)
	_sun.light_energy = 1.1
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # the sky shader draws its own sun
	# D-253: sun shadows from the 3D models (cars, buildings, lamps, rocks)
	# over the nearby road; flat sprites get blob shadows instead.
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = SHADOW_DISTANCE
	_sun.shadow_blur = 1.5
	_sun.shadow_bias = 0.08
	_sun.shadow_normal_bias = 1.5
	_root.add_child(_sun)

	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = CAM_FOV
	_cam.near = 0.3
	_cam.far = 2600.0   # the sky is drawn at infinity (D-193)
	_root.add_child(_cam)
	_cam.current = true

	_road_mat = ShaderMaterial.new()
	_road_mat.shader = ROAD_SHADER
	# Rain puddles (D-217): a second pass over the road strip.
	_puddle_mat = ShaderMaterial.new()
	_puddle_mat.shader = PUDDLE_SHADER
	_puddle_mat.set_shader_parameter("road_half", Track.ROAD_HALF)
	_puddle_mat.set_shader_parameter("reach", Track.CITY_WALL + 2.5)
	_road_mat.next_pass = _puddle_mat
	_weather = Weather.new()
	_root.add_child(_weather)
	_weather.build(_loop_wav("rain", func(_t: float) -> float: return 0.0, 1.0, 0.45))

	_build_cars()


## Shader warm-up (D-178): pieces built only when they come up mid-race (the
## tunnel's walls, portals and lamps), in front of the camera behind the
## loading bar. Pooled cars, police, night lights and lamps already exist in
## the tree (hidden), and the shell warms those up by itself.
func warmup_nodes() -> Array[Node]:
	var out: Array[Node] = []
	if _cam == null:
		return out
	var holder := Node3D.new()
	holder.position = Vector3(0.0, 0.0, -8.0)
	var i := 0
	for m in [Tunnel.wall_material(), Tunnel.portal_material()]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 1.0)
		q.mesh = qm
		q.material_override = m
		q.position = Vector3(float(i) * 1.2 - 1.0, 0.0, 0.0)
		holder.add_child(q)
		i += 1
	var lamp := MeshInstance3D.new()
	lamp.mesh = Tunnel.light_mesh()
	lamp.position = Vector3(1.5, 0.0, 0.0)
	holder.add_child(lamp)
	_cam.add_child(holder)
	out.append(holder)
	return out


## A car or truck model with the cel car material (+ outline). Materials and
## outline meshes are shared per model.
func _car_instance(hue: float, model: String = CAR_MODEL, texture: String = CAR_TEXTURE) -> Node3D:
	var scene: PackedScene = load(model)
	var node: Node3D = scene.instantiate()
	if not _car_mats.has(model):
		var mat := ShaderMaterial.new()
		mat.shader = CAR_SHADER
		mat.set_shader_parameter("tex", load(texture))
		mat.set_shader_parameter("tex_hd", load(HD_TEXTURES.get(texture, texture)))   # D-195
		mat.set_shader_parameter("hd", _gfx_hd)
		mat.set_shader_parameter("toon", Toon.enabled)
		if WHEELS.has(model):   # D-250: each wheel's rim, and the rim picture
			var wd: Array = WHEELS[model]
			mat.set_shader_parameter("wheels", PackedVector3Array(wd[1]))
			mat.set_shader_parameter("wheel_n", (wd[1] as Array).size())
			mat.set_shader_parameter("rim_tex", load(wd[0]))
		if LAMP_BOXES.has(model):   # where this model's lamps are (D-144)
			var lb: Dictionary = LAMP_BOXES[model]
			for k in lb:
				mat.set_shader_parameter(k, lb[k])
		_car_mats[model] = mat
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.material_override = _car_mats[model]
		InstParam.set_param(mi, "hue", hue)
		if Toon.enabled:
			if not _car_outlines.has(model):
				_car_outlines[model] = Toon.outline_mesh(mi.mesh)
			var ol := MeshInstance3D.new()
			ol.mesh = _car_outlines[model]
			ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(ol)
	return node


## The player's car body for a model (D-205): the model with its night lights,
## tail glows, number plate and the nitro/backfire flames on its exhausts.
## Rebuilt when the chosen car uses a different model.
func _build_body(model: String) -> void:
	if _body_model == model and is_instance_valid(_car_body):
		return
	if is_instance_valid(_car_body):
		_car_body.queue_free()
	_flames.clear()
	_flame_mats.clear()
	_body_model = model
	_car_body = _car_instance(0.0, model, MODEL_TEXTURES[model])
	_player_lights = Night.add_car_lights(_car_body, "car", _puff_texture(), TAIL_AT[MODEL_LIGHTS[model]])
	_place_tails(_car_body, _player_lights, model)
	var plate: Array = PLATES.get(model, PLATES[CAR_MODEL])
	_add_plate(_car_body, plate[0], plate[1])
	_car.add_child(_car_body)
	var pipes: Array = EXHAUSTS.get(model, EXHAUSTS[CAR_MODEL])
	_exhaust_z = (pipes[0] as Vector3).z
	for pipe in pipes:
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.1
		cone.height = 1.0
		cone.radial_segments = 6
		var fm := StandardMaterial3D.new()
		_flame_mats.append(fm)
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(0.5, 0.8, 1.0)
		fm.emission_enabled = true
		fm.emission = Color(0.4, 0.7, 1.0)
		fm.emission_energy_multiplier = 3.0
		cone.material = fm
		flame.mesh = cone
		# On the model's exhaust pipes, so they follow the body's yaw (D-097).
		flame.rotation_degrees = Vector3(-90, 0, 0)  # tip points out the back
		var pv: Vector3 = pipe
		flame.position = Vector3(pv.x, pv.y, pv.z - 0.5)
		flame.visible = false
		_car_body.add_child(flame)
		_flames.append(flame)


func _build_cars() -> void:
	_car = Node3D.new()
	_root.add_child(_car)
	_build_body(CAR_MODELS[_chosen_car])
	_build_puffs()
	for kind in _traffic_pool:
		var count: int = TRAFFIC_POOL if kind == "car" else (HATCH_POOL if kind == "hatch"
			else (HOTHATCH_POOL if kind == "hothatch" else Sim.MAX_TRUCKS))
		for i in count:
			var t: Node3D
			match kind:
				"car": t = _car_instance(0.0)
				"hatch": t = _car_instance(0.0, HATCH_MODEL, HATCH_TEXTURE)
				"hothatch": t = _car_instance(0.0, HOTHATCH_MODEL, HOTHATCH_TEXTURE)
				"truck": t = _car_instance(0.0, TRUCK_MODEL, TRUCK_TEXTURE)
				_: t = _car_instance(0.0, TRUCK2_MODEL, TRUCK2_TEXTURE)
			var light_kind := "truck" if kind.begins_with("truck") else "car"
			_add_headlights(t, light_kind)
			_add_blinkers(t, kind)
			t.set_meta("night", Night.add_car_lights(t, light_kind, _puff_texture(), TAIL_AT.get(kind, Vector3.ZERO)))
			if kind == "car" or kind == "hatch" or kind == "hothatch":
				_place_tails(t, t.get_meta("night"),
					{"hatch": HATCH_MODEL, "hothatch": HOTHATCH_MODEL}.get(kind, CAR_MODEL))
			t.visible = false
			_root.add_child(t)
			_traffic_pool[kind].append(t)
	for i in 4:
		var pk := _build_pickup()
		pk.visible = false
		_root.add_child(pk)
		_pickup_nodes.append(pk)
	_build_police()


func _build_puffs() -> void:
	_puffs = MultiMesh.new()
	_puffs.transform_format = MultiMesh.TRANSFORM_3D
	_puffs.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.billboard_keep_scale = true
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sm.albedo_texture = _puff_texture()
	q.material = sm
	_puffs.mesh = q
	_puffs.instance_count = PUFF_MAX
	_puffs.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _puffs
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	_root.add_child(mmi)


## Rear-wheel puffs in world space: rise, grow and fade (D-100).
func _update_puffs(delta: float, smoking: bool) -> void:
	if smoking:
		_puff_t += delta
		var col := Color(0.75, 0.6, 0.4, 0.5) if sim.offroad else Color(0.95, 0.95, 0.95, 0.45)
		# Fewer puffs when slow, or they pile up into one opaque cloud.
		var every := PUFF_EVERY * clampf(40.0 / maxf(sim.v, 1.0), 1.0, 4.0)
		while _puff_t >= every:
			_puff_t -= every
			for side in [-0.75, 0.75]:
				if _puff_list.size() >= PUFF_MAX:
					_puff_list.pop_front()
				var pos := _car.global_transform * Vector3(side, 0.3, 1.6)
				var vel := Vector3(randf_range(-1, 1), randf_range(1.0, 2.5), randf_range(-1, 1))
				_puff_list.append({"pos": pos, "vel": vel, "age": 0.0, "size": randf_range(0.8, 1.6), "col": col})
	else:
		_puff_t = 0.0
	for i in range(_puff_list.size() - 1, -1, -1):
		var p: Dictionary = _puff_list[i]
		p.age += delta
		if p.age >= PUFF_LIFE:
			_puff_list.remove_at(i)
			continue
		p.vel.y += 0.6 * delta
		p.pos += p.vel * delta
	_puffs.visible_instance_count = _puff_list.size()
	for i in _puff_list.size():
		var p: Dictionary = _puff_list[i]
		var k: float = p.age / PUFF_LIFE
		var sc: float = p.size * lerpf(0.5, 1.7, k)
		_puffs.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * sc), p.pos))
		var c: Color = p.col
		_puffs.set_instance_color(i, Color(c.r, c.g, c.b, c.a * (1.0 - k)))


## Headlight flares at the model's nose (model space: front is +Z), hidden
## until an oncoming driver flashes the high beams (D-105).
func _add_headlights(node: Node3D, kind: String) -> void:
	if _beam_mat == null:
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_beam_mat.billboard_keep_scale = true
		_beam_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_beam_mat.albedo_texture = _puff_texture()
		_beam_mat.albedo_color = Color(1.0, 0.95, 0.7)
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 0.95) if kind == "car" else Vector2(1.3, 1.3)
	var front := 2.25 if kind == "car" else 5.05
	var side := 0.62 if kind == "car" else 0.95
	var up := 0.62 if kind == "car" else 0.95
	var beams := []
	for sx in [-side, side]:
		var b := MeshInstance3D.new()
		b.mesh = q
		b.material_override = _beam_mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.position = Vector3(sx, up, front)
		b.visible = false
		node.add_child(b)
		beams.append(b)
	node.set_meta("beams", beams)


## The hero car's rear number plate, "TRN" (D-114, D-116): California style.
## A cream plate with a red state name, orange stripes and a setting sun, bold
## navy letters and an orange motto, drawn once into a small viewport texture.
func _add_plate(body: Node3D, at := Vector3(0.0, PLATE_Y, PLATE_Z), size := PLATE_SIZE) -> void:
	var plate := MeshInstance3D.new()
	var vp := SubViewport.new()
	vp.size = Vector2i(192, 96)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	plate.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.9, 0.88, 0.8)
	bg.size = Vector2(192, 96)
	vp.add_child(bg)
	var face := ColorRect.new()
	face.color = Color(0.98, 0.97, 0.92)
	face.position = Vector2(4, 4)
	face.size = Vector2(184, 88)
	vp.add_child(face)
	for st in [[30.0, 5.0], [38.0, 3.0]]:
		var stripe := ColorRect.new()
		stripe.color = Color(0.93, 0.6, 0.15)
		stripe.position = Vector2(10, st[0])
		stripe.size = Vector2(172, st[1])
		vp.add_child(stripe)
	var sun := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(96 + cos(a) * 15.0, 22 + sin(a) * 15.0))
	sun.polygon = pts
	sun.color = Color(0.95, 0.62, 0.15)
	vp.add_child(sun)
	var state := _plate_label(tr("RC_PLATE_STATE"), 24, Color(0.85, 0.12, 0.12), 2, 2)
	vp.add_child(state)
	var num := _plate_label(tr("RC_PLATE"), 60, Color(0.08, 0.12, 0.42), 30, 3)
	vp.add_child(num)
	var motto := _plate_label(tr("RC_PLATE_MOTTO"), 12, Color(0.85, 0.52, 0.1), 76, 0)
	vp.add_child(motto)
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.6
	q.material = m
	plate.mesh = q
	plate.position = at
	plate.rotation_degrees = Vector3(0, 180, 0)   # face backwards
	body.add_child(plate)


## One centred line of plate text; `bold` adds a same-colour outline.
func _plate_label(text: String, size: int, col: Color, y: float, bold: int) -> Label:
	var l := UI.label(text, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(192, size + 8)
	l.add_theme_constant_override("outline_size", bold)
	l.add_theme_color_override("font_outline_color", col)
	return l


## Night light under each lamp post (D-113): pool + cone + head glow, following
## the road's pitch so the pool lies on the road.
func _add_lamp_lights(node: Node3D, lamps: Array) -> void:
	var tr_ := sim.track
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Night.lamp_mesh()
	mm.instance_count = lamps.size()
	for i in lamps.size():
		var o: Dictionary = lamps[i]
		var f := tr_.frame(o.s, o.x)
		if o.x < 0.0:
			f.basis = f.basis * Basis(Vector3.UP, PI)
		mm.set_instance_transform(i, f)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visible = Night.level > 0.0
	mmi.add_to_group(NIGHT_GROUP)
	node.add_child(mmi)


## Which mesh draws a track object (D-107): palms, bushes and signs are pixel
## sprites (variants picked from the position, so they're stable); rocks and
## lamps stay low-poly 3D.
func _prop_kind(o: Dictionary) -> String:
	var h := int(absf(o.s * 7.13 + o.x * 3.1) * 10.0)
	match o.kind:
		"palm":
			# Each area has its own trees (D-204, D-216); during a cross-fade
			# they mix by the area weights.
			match _obj_area(o, h):
				"fields":
					return "tree_oak" if h % 3 != 0 else "tree_cypress"
				"desert":
					return "cactus_1"
				"forest":
					return "pine_1" if h % 3 != 0 else "pine_2"
				"snow":
					return "pine_snow"
			return "palm_1" if h % 3 != 0 else "palm_2"
		"bush":
			match _obj_area(o, h):
				"desert":
					return "desert_bush"
				"forest":
					return "fern"
				"snow":
					return "snow_rock"
			return "bush_1" if h % 2 == 0 else "bush_2"
		"rock":
			return "snow_rock" if _obj_area(o, h) == "snow" else "rock"
		"cactus":
			return "cactus_1" if h % 3 == 0 else "cactus_2"
		"chalet":   # the finish town (D-229)
			return ["chalet_1", "chalet_2", "townhouse"][h % 3]
		"crowd":
			return ["crowd_1", "crowd_2", "crowd_3"][h % 3]
		"chevron":   # curve warning: the arrow turns the way the road does.
			# Track: dir = -1 on a left turn (curvature > 0); the sprite's arrow
			# turns right as drawn.
			return "sign_curve_l" if o.dir < 0.0 else "sign_curve"
		"sign":
			return "sign_green"
		"house":   # beach stage (D-204): two beach houses and a surf shop
			return ["house_1", "house_2", "house_3"][h % 3]
	return o.kind


## The area an object belongs to (D-216): during a cross-fade, picked by the
## area weights with the object's own hash, so the change is gradual.
func _obj_area(o: Dictionary, h: int) -> String:
	var a: Dictionary = sim.track.areas(o.s)
	if a.size() == 1:
		return a.keys()[0]
	var r := float(h % 100) / 100.0
	for k in a:
		r -= float(a[k])
		if r < 0.0:
			return k
	return a.keys()[a.size() - 1]


## Police car (D-135): the director's model with a light bar of flashing red
## and blue glows, plus a looping two-tone siren.
func _build_police() -> void:
	_police = _car_instance(0.0, POLICE_MODEL, POLICE_TEXTURE)
	_police.visible = false
	_root.add_child(_police)
	for c in [Color(1.0, 0.1, 0.1), Color(0.15, 0.35, 1.0)]:
		var q := QuadMesh.new()
		q.size = Vector2(1.1, 1.1)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.albedo_texture = _puff_texture()
		m.albedo_color = c
		q.material = m
		var f := MeshInstance3D.new()
		f.mesh = q
		# Over the model's painted bar (D-147): seen from behind, red is on the
		# right and blue on the left (model space is turned 180 degrees).
		f.position = Vector3(-0.35 if c.r > 0.5 else 0.35, 1.52, 0.15)
		_police.add_child(f)
		_flashers.append(f)
	# Night lights like the other cars (D-198).
	_police_night = Night.add_car_lights(_police, "car", _puff_texture(), TAIL_AT["police"])
	_place_tails(_police, _police_night, POLICE_MODEL)
	# Siren light (D-198): the light bar lights the road and the cars around it,
	# red and blue in turn, strongest at night: a coloured light each, plus a
	# soft glow pool on the road (the fake-light look of the lamp pools).
	for c in [Color(1.0, 0.12, 0.1), Color(0.2, 0.4, 1.0)]:
		var l := OmniLight3D.new()
		l.light_color = c
		l.omni_range = 14.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.position = Vector3(-0.35 if c.r > 0.5 else 0.35, 1.9, 0.15)
		_police.add_child(l)
		_siren_lights.append(l)
		var pool := MeshInstance3D.new()
		var pq := PlaneMesh.new()
		pq.size = Vector2(11.0, 11.0)
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.albedo_texture = _puff_texture()
		pm.albedo_color = Color(c, 0.0)
		pm.no_depth_test = false
		pq.material = pm
		pool.mesh = pq
		pool.position = Vector3(-1.2 if c.r > 0.5 else 1.2, 0.08, 0.0)
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_police.add_child(pool)
		_siren_pools.append(pool)
	_siren = AudioStreamPlayer.new()
	_siren.bus = "SFX"
	_siren.stream = _loop_wav("siren", func(t: float) -> float:
		var f := 700.0 if fmod(t, 1.0) < 0.5 else 960.0
		var ph := fmod(t * f, 1.0)
		return ((1.0 if ph < 0.5 else -1.0) * 0.25 + sin(TAU * f * t) * 0.2), 1.0, 0.0)
	_siren.volume_db = -80.0
	add_child(_siren)
	_siren.play()
	_radar_beep_t = 0.0


func _animate_police(delta: float, cam_yaw: float) -> void:
	var tr_ := sim.track
	if sim.police.is_empty():
		_police.visible = false
		for w in _washes:
			(w as CanvasItem).modulate.a = 0.0
		_siren.volume_db = lerpf(_siren.volume_db, -80.0, 0.1)
		return
	var pd: Dictionary = sim.police
	_police.visible = true
	_police.transform = tr_.frame(pd.s, pd.x)
	var h := tr_.heading(pd.s)
	# Swerving in on the hero car: the nose turns towards it (the T-bone).
	# While chasing, its nose points at the hero car (D-142).
	var lean := 0.0
	if pd.state == "chase":
		var ahead := maxf(sim.s - float(pd.s) + 6.0, 4.0)
		lean = clampf(atan2(sim.x - float(pd.x), ahead), -0.9, 0.9)
	# Busted (D-139): it swings 90 degrees across as it stops beside you, in
	# stepped frames, and straightens again as it drives off.
	var swing_to := 0.0
	if pd.state == "bust":
		swing_to = clampf(1.0 - absf(float(pd.v)) / 12.0, 0.0, 1.0)
	_police_swing = move_toward(_police_swing, swing_to, delta * 2.5)
	# Across the lane in front (D-161): it swings the way it cut in.
	var side: float = pd.get("swing", 1.0)
	lean += roundf(_police_swing * 4.0) / 4.0 * PI * 0.5 * side
	_police.basis = _police.basis * Basis(Vector3.UP, _sprite_yaw(h - lean + float(pd.get("sway", 0.0)), cam_yaw) - h) * MODEL_TURN
	# Its wheels turn with its own speed (D-246), stepped like the player's.
	# D-248: seen side-on, a flat blurred disc reads as wheels standing still,
	# so the spokes stay visible: their turning is capped at a rate the eye
	# can follow (like film of a fast wheel) and only half blurred.
	_police_wheel = fmod(_police_wheel + minf(absf(float(pd.v)) / 0.37, WHEEL_MAX) * delta, TAU * 100.0)
	var pstep := _police_wheel if _anim_mult <= 0.0 else floorf(_police_wheel * 3.0 * _anim_mult) / (3.0 * _anim_mult)
	for m in _police.find_children("*", "MeshInstance3D", true, false):
		var pmi := m as MeshInstance3D
		if pmi.material_override != null:
			InstParam.set_param(pmi, "spin", 1.0)
			InstParam.set_param(pmi, "wheel_phase", pstep)
			InstParam.set_param(pmi, "wheel_blur", clampf((absf(float(pd.v)) - 6.0) / 20.0, 0.0, 1.0) * 0.45)
	var ph := fmod(_phase_t, 0.5)
	var lights := sim.police_lights()   # off once it has given up or is driving off (D-145)
	var red_on := lights and ph < 0.25 and (ph < 0.08 or ph > 0.15)
	var blue_on := lights and ph >= 0.25 and (ph < 0.33 or ph > 0.4)
	(_flashers[0] as Node3D).visible = red_on
	(_flashers[1] as Node3D).visible = blue_on
	# Its own head/tail lights at night (D-198), like every other car.
	for m in _police.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).material_override is ShaderMaterial:
			InstParam.set_param(m as MeshInstance3D, "lamps", _lamps)
	_police_night.visible = _lamps > 0.0
	# Siren light around the car (D-198), red and blue in turn, stronger at night.
	var glow := lerpf(0.7, 2.6, _night)
	for i in 2:
		var on: bool = red_on if i == 0 else blue_on
		(_siren_lights[i] as OmniLight3D).light_energy = glow if on else 0.0
		var pm := ((_siren_pools[i] as MeshInstance3D).mesh as PlaneMesh).material as StandardMaterial3D
		pm.albedo_color.a = lerpf(0.18, 0.7, _night) if on else 0.0
	# Screen wash while it's close (D-137): up to 45 % within 25 m.
	var near := 1.0 - clampf((absf(pd.s - sim.s) - 25.0) / 100.0, 0.0, 1.0)
	# Same sides as the light bar seen from behind (D-147): blue left, red right.
	(_washes[0] as CanvasItem).modulate.a = 0.45 * near if blue_on else 0.0
	(_washes[1] as CanvasItem).modulate.a = 0.45 * near if red_on else 0.0
	var d: float = absf(pd.s - sim.s)
	var closing: float = (pd.v - sim.v) * (1.0 if pd.s < sim.s else -1.0)
	_siren.pitch_scale = clampf(SOUND_SPEED / maxf(SOUND_SPEED - closing, 20.0), 0.7, 1.5)
	var siren_db := -4.0 - 26.0 * clampf(d / 200.0, 0.0, 1.0) if lights else -80.0
	_siren.volume_db = lerpf(_siren.volume_db, siren_db, 0.2)


## Radar detector (D-135): beeps faster as a speed camera gets closer, with a
## red LED that lights with each beep (HUD and DMD).
func _update_radar(delta: float) -> void:
	_radar_led = maxf(0.0, _radar_led - delta)
	if sim.radar <= 0.0 or sim.state != Sim.State.RACE:
		_radar_beep_t = 0.0
	else:
		_radar_beep_t -= delta
		if _radar_beep_t <= 0.0:
			_radar_beep_t = lerpf(1.1, 0.09, sim.radar)
			_radar_led = minf(0.07, _radar_beep_t * 0.5)
			_radar_beep()
	if is_instance_valid(_radar_bar):
		_radar_bar.smooth = _gfx_hd   # D-212
		_radar_bar.set_state(sim.radar if sim.state == Sim.State.RACE else 0.0, _radar_led > 0.0)


## Right-hand indicators (D-163): amber glows at the vehicle's own right front
## and rear corners (model space: front +Z, the model's right is -X), flashed
## while it pulls over for the police.
func _add_blinkers(node: Node3D, kind: String) -> void:
	if _blink_mesh == null:
		var q := QuadMesh.new()
		q.size = Vector2(0.55, 0.55)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.albedo_texture = _puff_texture()
		m.albedo_color = Color(1.0, 0.6, 0.05)
		q.material = m
		_blink_mesh = q
	var spots: Array = BLINKERS.get(kind, BLINKERS["car"])
	var list := []
	for sp in spots:
		var b := MeshInstance3D.new()
		b.mesh = _blink_mesh
		b.position = sp
		b.visible = false
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(b)
		list.append(b)
	node.set_meta("blinkers", list)


## Nitro pick-up (D-103, D-115): the 16-bit nitrous tank sprite (blue bottle
## with a big N), a camera-facing billboard that bobs on stepped frames.
func _build_pickup() -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = Sprites.mesh("nitro")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n


## Black and white squares for the finish gate and line (D-221).
func _chequer_texture() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, Color.WHITE if (x / 2 + y / 2) % 2 == 0 else Color(0.05, 0.05, 0.05))
	return ImageTexture.create_from_image(img)


## A chequered stripe across the road at the finish (D-221).
func _finish_line(parent: Node3D, s: float) -> void:
	var f := sim.track.frame(s, 0.0, 0.03)
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(Track.ROAD_HALF * 2.0, 2.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _chequer_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(Track.ROAD_HALF, 1.0, 1.0)
	q.material = m
	mi.mesh = q
	mi.transform = f
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Blob shadows (D-253): a soft dark disc flat on the ground under each sprite
## prop, sized from the sprite's height, a little towards the side away from
## the sun's usual direction.
func _add_blobs(node: Node3D, list: Array, kind: String) -> void:
	if _blob_mat == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_texture = ImageTexture.create_from_image(img)
		_blob_mat.albedo_color = Color(0, 0, 0, 0.45)
		_blob_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_blob_mesh = QuadMesh.new()
		_blob_mesh.size = Vector2.ONE
		_blob_mesh.orientation = PlaneMesh.FACE_Y
		_blob_mesh.material = _blob_mat
	var h: float = float(Sprites.KINDS[kind][1]) if Sprites.KINDS.has(kind) else 3.0
	if h > 30.0:
		return   # distant buttes: no shadow
	var w := clampf(h * 0.45, 0.8, 7.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _blob_mesh
	mm.instance_count = list.size()
	var tr_ := sim.track
	for i in list.size():
		var o: Dictionary = list[i]
		var f := tr_.frame(o.s, o.x, 0.06)
		f.basis = Basis(Vector3.UP, tr_.heading(o.s)).scaled(Vector3(w, 1.0, w * 0.7))
		mm.set_instance_transform(i, f)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)


## Round pixel puff (16 px, hard steps) for tyre smoke and dust.
func _puff_texture() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			var a := 0.0 if d > 1.0 else (1.0 if d < 0.55 else 0.55)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _update_chunks() -> void:
	var first := int(floor((sim.s - VIEW_BEHIND) / CHUNK))
	var last := int(floor((sim.s + VIEW_AHEAD) / CHUNK))
	sim.track.ensure((last + 1) * CHUNK + Track.SAMPLE)
	for k in _chunks.keys():
		if k < first or k > last:
			_chunks[k].queue_free()
			_chunks.erase(k)
	for k in range(maxi(first, 0), last + 1):
		if not _chunks.has(k):
			_chunks[k] = _build_chunk(k)


func _build_chunk(k: int) -> Node3D:
	var node := Node3D.new()
	_root.add_child(node)
	var tr_ := sim.track
	var s0 := k * CHUNK
	var n := int(CHUNK / Track.SAMPLE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := LATERAL.size() + 2   # + a skirt at each outer edge (D-197)
	for i in n + 1:
		var s := s0 + i * Track.SAMPLE
		# On the inside of a curve the ground stops well short of the centre of
		# the turn, or it would fold back over the road (D-094).
		var c := tr_.curvature(s)
		var inside_max := 1e9 if absf(c) < 1e-5 else 0.75 / absf(c)
		var xs: Array = []
		for lx in LATERAL:
			var x: float = lx
			if signf(lx) == -signf(c):   # left turn (c > 0): inside is -x
				x = signf(lx) * minf(absf(lx), maxf(inside_max, Track.ROAD_HALF + Track.RUMBLE + 4.0))
			xs.append(x)
		# Skirts (D-197): the ground strip's outer edges hang a steep slope far
		# down into the fog, so on hills the edge never shows sky under it.
		for j in cols:
			# D-204/D-216: the area weights for the road shader: UV2 = (beach,
			# city), COLOR = (desert, forest, snow).
			var aw := tr_.areas(s)
			var bw := float(aw.get("beach", 0.0))
			st.set_uv2(Vector2(bw, float(aw.get("city", 0.0))))
			st.set_color(Color(float(aw.get("desert", 0.0)), float(aw.get("forest", 0.0)), float(aw.get("snow", 0.0)), 1.0))
			if j == 0 or j == cols - 1:
				var edge: float = xs[0] if j == 0 else xs[xs.size() - 1]
				var side := signf(edge)
				var p := tr_.point(s, edge) + tr_.right(s) * side * SKIRT_OUT
				# The sea stays flat out to the horizon on the beach's left.
				p.y -= SKIRT_DROP * (1.0 - bw if side < 0.0 else 1.0)
				st.set_uv(Vector2(edge + side * SKIRT_OUT, s))
				st.add_vertex(p)
			else:
				st.set_uv(Vector2(xs[j - 1], s))
				st.add_vertex(tr_.point(s, xs[j - 1]))
	for i in n:
		for j in cols - 1:
			var a := i * cols + j
			var b := a + 1
			var c := a + cols
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	road.material_override = _road_mat
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(road)
	# Props, one MultiMesh per kind.
	var by_kind := {}
	for o in tr_.objects_between(s0, s0 + CHUNK):
		var key := _prop_kind(o)
		if not by_kind.has(key):
			by_kind[key] = []
		by_kind[key].append(o)
	# City (D-216): buildings, traffic lights and cross streets are built apart.
	City.build_buildings(node, tr_, by_kind.get("building", []))
	City.build_lights(node, tr_, by_kind.get("tlight", []))
	City.build_junctions(node, tr_, s0, s0 + CHUNK)
	by_kind.erase("building")
	by_kind.erase("tlight")
	for kind in by_kind:
		var list: Array = by_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Sprites.mesh(kind) if Sprites.has(kind) else Scenery.mesh(kind)
		mm.instance_count = list.size()
		for i in list.size():
			var o: Dictionary = list[i]
			var f := tr_.frame(o.s, o.x)
			f.basis = Basis(Vector3.UP, tr_.heading(o.s))
			var h := fmod(absf(o.s * 7.13 + o.x * 3.1), 1.0)
			match kind:
				"pine_1", "pine_2":
					# Forest lines (D-218): tall, taller in the back rows.
					f.basis = Basis.from_scale(Vector3.ONE * (1.05 + h * 0.4 + 0.1 * clampf(float(o.dir) - 1.0, 0.0, 2.0)))
				"palm_1", "palm_2", "pine_snow", "tree_oak", "tree_cypress", "cactus_1":
					f.basis = Basis.from_scale(Vector3.ONE * (0.85 + h * 0.35))
				"crowd_1", "crowd_2", "crowd_3":
					f.basis = Basis.from_scale(Vector3.ONE * (0.92 + h * 0.16))
				"bush_1", "bush_2", "fern", "desert_bush", "cactus_2", "snow_rock":
					f.basis = Basis.from_scale(Vector3.ONE * (0.8 + h * 0.5))
				"mesa":
					f.basis = Basis.from_scale(Vector3.ONE * (0.7 + h * 0.6))
					f.origin.y -= 2.0   # sunk a little into the dunes
				"sign_curve", "sign_curve_l", "sign_green":
					f.basis = Basis.IDENTITY
				"rock":
					f.basis = f.basis * Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * (0.8 + h * 0.6))
				"lamp":
					# Arm over the road: turn (not mirror, which would flip the
					# outline's culling) the left-side lamps.
					if o.x < 0.0:
						f.basis = f.basis * Basis(Vector3.UP, PI)
			f.origin.y -= 0.05
			mm.set_instance_transform(i, f)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		# D-253: 3D props cast real shadows; flat sprites a blob on the ground.
		if Sprites.has(kind):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_blobs(node, list, kind)
		node.add_child(mmi)
		if kind == "lamp":
			_add_lamp_lights(node, list)
	Tunnel.build(node, tr_, s0, s0 + CHUNK)   # D-127
	# Start line and checkpoint gates.
	var cp := ceilf(s0 / Sim.CHECKPOINT_EVERY) * Sim.CHECKPOINT_EVERY
	if s0 <= Sim.START_LINE and s0 + CHUNK > Sim.START_LINE:
		_build_gate(node, Sim.START_LINE, tr("RC_START"))
	if cp >= Sim.CHECKPOINT_EVERY and cp < s0 + CHUNK and cp <= Sim.FINISH_STAGE * Sim.CHECKPOINT_EVERY:
		# The last one is the finish line (D-221).
		var fin := is_equal_approx(cp, Sim.FINISH_STAGE * Sim.CHECKPOINT_EVERY)
		_build_gate(node, cp, tr("RC_FINISH") if fin else tr("RC_CHECKPOINT"), fin)
	return node


func _build_gate(parent: Node3D, s: float, text: String, finish := false) -> void:
	var f := sim.track.frame(s)
	f.basis = Basis(Vector3.UP, sim.track.heading(s))
	var gate := Node3D.new()
	gate.transform = f
	parent.add_child(gate)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.2)
	var w := Track.ROAD_HALF + 2.0
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.8, 8.0, 0.8)
		b.material = mat
		post.mesh = b
		post.position = Vector3(side * w, 4.0, 0.0)
		gate.add_child(post)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(w * 2.0 + 0.8, 2.0, 0.5)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.9, 0.1, 0.2)
	bm.emission_enabled = true
	bm.emission = Color(0.5, 0.05, 0.1)
	if finish:   # D-223: a deep red banner, chequered line on the road below
		bb.size = Vector3(w * 2.0 + 0.8, 3.4, 0.5)
		bm.albedo_color = Color(0.85, 0.05, 0.08)
		bm.emission = Color(0.55, 0.02, 0.04)
		_finish_line(parent, s)
	bb.material = bm
	beam.mesh = bb
	beam.position = Vector3(0, 8.0, 0)
	gate.add_child(beam)
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/pinpixel.ttf")
	label.font_size = 192
	label.pixel_size = 0.009
	label.modulate = Color(1.0, 0.9, 0.3)
	label.outline_size = 24
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = Vector3(0, 8.0, 0.3)
	if finish:   # big yellow letters (D-223)
		label.pixel_size = 0.0145
		label.modulate = Color(1.0, 0.86, 0.1)
		label.outline_modulate = Color(0.35, 0.0, 0.02)
		label.outline_size = 32
		label.position = Vector3(0, 8.2, 0.3)
	gate.add_child(label)


# --- per-frame visuals ----------------------------------------------------------------
## Animation progress t (0..1 over `seconds`) held on ANIM_FPS steps, so crash
## animations play like a few sprite frames instead of smooth motion (D-098).
func _anim_steps(t: float, seconds: float) -> float:
	if _anim_mult <= 0.0:
		return clampf(t, 0.0, 1.0)
	var n := maxf(1.0, seconds * ANIM_FPS * _anim_mult)
	return floorf(clampf(t, 0.0, 1.0) * n) / n


## Rounds x (in units of whole steps of 1/frames) to the mode's frames (D-208).
func _frame_steps(x: float, frames: float) -> float:
	if _anim_mult <= 0.0:
		return x
	var n := frames * _anim_mult
	return roundf(x * n) / n


## The double roll lands harder (D-211).
func turns_bounce(turns: float) -> float:
	return 1.0 + 0.4 * (turns - 1.0)


## Horizontal yaw of the chase camera's view (same convention as Track: 0 = -Z).
func _camera_yaw() -> float:
	var tr_ := sim.track
	var d := tr_.point(sim.s + CAM_LOOK, _cam_x * 0.9) - tr_.point(sim.s - CAM_BACK, _cam_x * 0.85)
	return atan2(-d.x, -d.z)


## Simulated sprite car (D-092): the 3D model only ever shows one of
## SPRITE_ANGLES views relative to the camera, like a pre-rendered sprite set.
func _sprite_yaw(world_yaw: float, cam_yaw: float) -> float:
	if _anim_mult <= 0.0:
		return world_yaw   # HD: smooth (D-208)
	var step := TAU / (SPRITE_ANGLES * _anim_mult)
	return cam_yaw + roundf((world_yaw - cam_yaw) / step) * step


func _animate(delta: float) -> void:
	var tr_ := sim.track
	if _main:
		City.update(Night.level, _gfx_hd, _phase_t)   # D-216
	# Player car on the road frame, yawed by drift/steer, spinning on a crash.
	var f := tr_.frame(sim.s, sim.x)
	_car.transform = f
	# Steering visibly turns the nose even on straights (D-092).
	# The nose points where the car is going (D-124): the angle of its sideways
	# speed against its forward speed, so it never skates sideways while facing
	# straight. Short taps barely build sideways speed, so they don't twitch it.
	# Eased, and faded in with speed, so a flipper held at GO doesn't snap the
	# car sideways (D-128).
	var travel := 0.0
	if not sim.drifting:
		travel = clampf(atan2(sim.lat_v, maxf(sim.v, 12.0)), -MAX_TRAVEL_YAW, MAX_TRAVEL_YAW)
		travel *= clampf(sim.v / 15.0, 0.0, 1.0)
	_travel = move_toward(_travel, travel, delta * 1.8)
	var yaw := deg_to_rad(sim.drift_angle) - _travel + sim.sway   # D-239: side-impact sway
	var crash_p := _anim_steps(sim.crash_progress(), sim.crash_anim)
	if sim.spin_t > 0.0 and not sim.flipping:
		# Spin-out: two full turns stepped like sprite frames, ending nose
		# forward, then stopped (D-098, D-101).
		yaw += crash_p * TAU * 2.0
	elif sim.spin_t > 0.0 and sim.flipping:
		# Roll-over, part 1: slew 90 degrees across the road (D-101) ...
		var turn := clampf(crash_p / FLIP_TURN_END, 0.0, 1.0)
		# ... and while stopped at the end, turn back to face the road.
		if sim.spin_t < FLIP_UNTURN:
			turn = _anim_steps(sim.spin_t / FLIP_UNTURN, FLIP_UNTURN)
		yaw += turn * PI * 0.5 * sim.flip_dir
	# TIME UP (D-105): the car swings 90 degrees and slides to a stop sideways,
	# nose towards the inside of the bend. Turns back if a checkpoint saves it.
	# D-222: past the finish line the car drift-brakes the same way, a little
	# less than sideways (FINISH_DRIFT of 90 degrees), smoking and squealing.
	if sim.state == Sim.State.OVER:
		if _over_dir == 0.0:
			var c := sim.track.curvature(sim.s)
			_over_dir = signf(c) if absf(c) > 1e-4 else (-1.0 if sim.x > 0.0 else 1.0)
		_over_turn = move_toward(_over_turn, 1.0, delta / OVER_TURN_TIME)
	else:
		_over_turn = move_toward(_over_turn, 0.0, delta / OVER_TURN_TIME)
		if _over_turn == 0.0:
			_over_dir = 0.0
	yaw += _frame_steps(_over_turn, OVER_TURN_FRAMES) * PI * 0.5 * _over_dir * (FINISH_DRIFT if sim.finished else 1.0)
	var cam_yaw := _camera_yaw()
	yaw = _sprite_yaw(tr_.heading(sim.s) + yaw, cam_yaw) - tr_.heading(sim.s)
	var bounce := 0.0
	if sim.offroad and sim.v > 5.0:
		bounce = sin(_phase_t * 40.0) * 0.05
	# No lean while driving (a sprite can't lean). A roll-over is the exception:
	# part 2, once sideways, a hop with one full roll about the car's length,
	# so it tumbles towards the front of the road, in FLIP_FRAMES stepped poses
	# (D-098, D-101). Turned +90 (nose left) the right side faces forward, and a
	# positive roll drops the right side: the roll sign follows the turn.
	var roll := 0.0
	var lift := bounce
	if sim.spin_t > 0.0 and sim.flipping:
		var q := clampf((crash_p - FLIP_TURN_END) / (FLIP_ROLL_END - FLIP_TURN_END), 0.0, 1.0)
		# Two rolls and a higher hop at 100+ mph (D-206).
		var turns := float(sim.flip_turns)
		roll = _frame_steps(q * turns, FLIP_FRAMES) * TAU * sim.flip_dir
		lift += 4.0 * FLIP_HOP * (1.0 + 0.6 * (turns - 1.0)) * q * (1.0 - q)
		# D-211: landing, it bounces on its wheels a few times, each lower,
		# with a little side-to-side rock.
		if q >= 1.0:
			_land_t += delta
			var t := _land_t
			if _anim_mult > 0.0:
				var fps := ANIM_FPS * 2.0 * _anim_mult
				t = floorf(t * fps) / fps
			if t < LAND_TIME:
				var k := exp(-t * LAND_DECAY)
				var ph := t * PI / LAND_PERIOD
				lift += absf(sin(ph)) * LAND_HEIGHT * turns_bounce(turns) * k
				roll += sin(ph * 0.5) * LAND_ROCK * k * sim.flip_dir
		else:
			_land_t = 0.0
	else:
		_land_t = 0.0
	var pivot := Vector3(0, 0.65, 0)             # roll around the body's middle
	var rb := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, roll)
	_car_body.transform = Transform3D(rb * MODEL_TURN, Vector3(0, lift, 0) + pivot - rb * pivot)
	var sliding_out := sim.state == Sim.State.OVER and sim.v > 3.0
	_shift_smoke_t = maxf(0.0, _shift_smoke_t - delta)
	_shift_flame_t = maxf(0.0, _shift_flame_t - delta)
	# Immune after a crash (D-125): the car blinks, arcade style.
	_car_body.visible = sim.grace_t <= 0.0 or fmod(_phase_t, 0.16) < 0.1
	# Hero car's own lamps (D-120): night lights, and brake lights when braking.
	var braking := sim.braking or sim.auto_braking or (sim.state == Sim.State.OVER and sim.v > 1.0)
	# Turning wheels (D-143): the phase follows the road speed (radius 0.32 m),
	# stepped at ANIM_FPS like sprite frames; fast = a blurred disc.
	# D-249: the wheels turn for real; capped at WHEEL_MAX so they're seen to
	# turn (faster would strobe between frames).
	_wheel_phase = fmod(_wheel_phase + minf(sim.v / 0.32, WHEEL_MAX) * delta, TAU * 100.0)
	var phase_step := _wheel_phase if _anim_mult <= 0.0 else floorf(_wheel_phase * 3.0 * _anim_mult) / (3.0 * _anim_mult)
	for m in _car_body.find_children("*", "MeshInstance3D", true, false):
		var gi := m as MeshInstance3D
		if gi.material_override != null:   # the body, not its outline shell
			InstParam.set_param(gi, "spin", 1.0)
			InstParam.set_param(gi, "wheel_phase", phase_step)
			InstParam.set_param(gi, "wheel_blur", clampf((sim.v - 6.0) / 20.0, 0.0, 1.0))
			InstParam.set_param(gi, "lamps", _lamps)
			InstParam.set_param(gi, "overhead", _overhead(sim.s))
			InstParam.set_param(gi, "brake", 1.0 if braking else 0.0)
	if _player_lights != null:
		_player_lights.visible = _lamps > 0.0 and not (sim.spin_t > 0.0 and sim.flipping)
		# Brake lights glow bigger than the running lights (D-198).
		for tl in _player_lights.get_meta("tails", []):
			(tl as Node3D).scale = Vector3.ONE * (0.95 if braking else 0.6)
	var smoking := sim.drifting or sliding_out or _shift_smoke_t > 0.0 or (sim.spin_t > 0.0 and not sim.stalled()) or (sim.offroad and sim.v > 12.0)
	_update_puffs(delta, smoking)
	# Revving on the grid spits fire (D-116): pops while held high, and one as
	# the revs drop.
	if sim.state == Sim.State.COUNTDOWN:
		_rev_pop_t -= delta
		var falling := sim.rpm < _last_rpm - 0.005
		if (sim.rpm > 0.7 and not falling and _rev_pop_t <= 0.0) or (falling and _last_rpm > 0.75 and not _rev_popped):
			_shift_flame_t = 0.14
			_rev_pop_t = randf_range(0.18, 0.4)
			_rev_popped = falling
			Audio.sfx("rc_backfire")
		if not falling:
			_rev_popped = false
	_last_rpm = sim.rpm
	# A perfect shift's boost blasts a long orange flame for its whole push (D-117).
	var blast := sim.perfect_t > 0.0 and not sim.boosting
	var burning := sim.boosting or blast or _shift_flame_t > 0.0
	# Nitro burns blue; upshift and rev pops are short and yellow (D-116).
	var pop := not sim.boosting and not blast
	for m in _flame_mats:
		var fm := m as StandardMaterial3D
		if blast:
			fm.albedo_color = Color(1.0, 0.6, 0.2)
			fm.emission = Color(1.0, 0.4, 0.1)
		else:
			fm.albedo_color = Color(1.0, 0.85, 0.3) if pop else Color(0.5, 0.8, 1.0)
			fm.emission = Color(1.0, 0.6, 0.15) if pop else Color(0.4, 0.7, 1.0)
	for fl in _flames:
		fl.visible = burning
		if burning:
			var short := 0.32 if pop else 1.0
			var sy := (0.8 + randf() * 0.7) * short
			fl.scale = Vector3(1.0, sy, 1.0)
			fl.position.z = _exhaust_z - 0.5 * sy   # keep the cone's base on the pipe
	# Traffic
	var used := {"car": 0, "hatch": 0, "hothatch": 0, "truck": 0, "truck2": 0}
	for t in sim.traffic:
		var kind: String = t.get("kind", "car")
		if kind == "truck" and int(t.id) % 2 == 1:
			kind = "truck2"   # two truck models, fixed per vehicle (D-121)
		elif kind == "car" and int(t.id) % 5 in [1, 3]:
			kind = "hatch"    # the hatchback in the mix (D-136)
		elif kind == "car" and int(t.id) % 5 == 4:
			kind = "hothatch"   # the hot hatch too (D-205)
		var pool: Array = _traffic_pool[kind]
		if used[kind] >= pool.size():
			continue
		var node: Node3D = pool[used[kind]]
		used[kind] += 1
		node.visible = true
		node.transform = tr_.frame(t.s, t.x)
		var h := tr_.heading(t.s)
		var wy := h + (PI if t.v < 0.0 else 0.0) + float(t.get("sway", 0.0))   # oncoming faces us (D-099); D-239 sway
		node.basis = node.basis * Basis(Vector3.UP, _sprite_yaw(wy, cam_yaw) - h) * MODEL_TURN
		if kind == "car" or kind == "hatch" or kind == "hothatch":
			for m in node.find_children("*", "MeshInstance3D", true, false):
				InstParam.set_param((m as MeshInstance3D), "hue", t.hue)
				InstParam.set_param((m as MeshInstance3D), "overhead", _overhead(t.s))
				InstParam.set_param((m as MeshInstance3D), "lamps", maxf(_night, 1.0 if sim.track.in_tunnel(t.s) else 0.0))
		# D-250: their wheels turn too (rate capped like the player's).
		var tph := fposmod(_phase_t * minf(absf(float(t.v)) / 0.4, WHEEL_MAX) + float(t.id) * 1.3, TAU * 100.0)
		for m in node.find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).material_override != null:
				InstParam.set_param((m as MeshInstance3D), "spin", 1.0)
				InstParam.set_param((m as MeshInstance3D), "wheel_phase", tph)
		(node.get_meta("night") as Node3D).visible = _lamps > 0.0
		var blink_on: bool = t.get("blink", false) and fmod(_phase_t + t.id * 0.17, 0.7) < 0.35
		for bl in node.get_meta("blinkers", []):
			(bl as Node3D).visible = blink_on
		# High beams: flash-flash ... pause (D-105).
		var ph := fmod(_phase_t + t.id * 0.13, 0.7)
		var beam_on: bool = t.get("flash", false) and (ph < 0.1 or (ph > 0.2 and ph < 0.3))
		for b in node.get_meta("beams", []):
			(b as Node3D).visible = beam_on
	for kind in _traffic_pool:
		for i in range(used[kind], _traffic_pool[kind].size()):
			(_traffic_pool[kind][i] as Node3D).visible = false
	_animate_rival(delta, cam_yaw)
	_animate_police(delta, cam_yaw)
	_update_radar(delta)
	# Nitro tanks bob on stepped frames (D-103, D-115).
	for i in _pickup_nodes.size():
		var pk: Node3D = _pickup_nodes[i]
		if i < sim.pickups.size():
			var pd: Dictionary = sim.pickups[i]
			pk.visible = true
			var st := _phase_t if _anim_mult <= 0.0 else floorf(_phase_t * ANIM_FPS * _anim_mult) / (ANIM_FPS * _anim_mult)
			pk.transform = Transform3D(Basis.IDENTITY, tr_.point(pd.s, pd.x, 0.35 + 0.3 * absf(sin(st * 4.0))))
		else:
			pk.visible = false
	# Chase camera: behind and above, looking down the road; FOV opens with speed.
	# Camera follows the road exactly along s; only its sideways offset lags.
	if not _cam_ready:
		_cam_x = sim.x
		_cam_ready = true
	_cam_x = lerpf(_cam_x, sim.x, 1.0 - exp(-delta * 6.0))
	var target := tr_.point(sim.s - CAM_BACK, _cam_x * 0.85, CAM_HEIGHT)
	var look := tr_.point(sim.s + CAM_LOOK, _cam_x * 0.9, 0.5)
	_cam_pos = target
	_shake = maxf(0.0, _shake - delta)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
	_cam.position = _cam_pos + shake
	_cam.look_at(look, Vector3.UP)
	# Pitch so the car stays at the same height on screen as before (D-098).
	var to_car := _cam.global_basis.inverse() * (tr_.point(sim.s, sim.x, 0.6) - _cam.position)
	var below := atan2(-to_car.y, -to_car.z)
	_cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(CAM_CAR_DEG) - below)
	_cam.rotate_object_local(Vector3.BACK, deg_to_rad(-sim.drift_angle * 0.12))
	if Config.cli.has("rc-look-up"):   # dev: tilt up (degrees) to check the sky's top (D-190)
		_cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(float(str(Config.cli["rc-look-up"]))))
	var fov := CAM_FOV + sim.v / Sim.MAX_SPEED * 6.0 + (8.0 if sim.boosting else (5.0 if sim.perfect_t > 0.0 else 0.0))
	_cam.fov = lerpf(_cam.fov, fov, 1.0 - exp(-delta * 4.0))


# --- HUD -----------------------------------------------------------------------------
func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_ui(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 62   # below the radar bar (D-139)
	top.offset_left = 40
	top.offset_right = -40
	_hud.add_child(top)
	var left := UI.vstack(4)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_child(UI.label(tr("RC_SCORE"), 36, UI.CYAN))
	_score_label = UI.label("0", 48)
	left.add_child(_score_label)
	# Drift points under the score (D-146); fades by alpha, so its slot stays.
	_drift_label = UI.label("", 36, UI.YELLOW)
	_drift_label.custom_minimum_size.y = 44
	_drift_label.modulate.a = 0.0
	left.add_child(_drift_label)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	_hud_top = top
	_hud_left = left
	var mid := UI.vstack(0)
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	_time_caption = UI.label(tr("RC_POSITION" if _two else "RC_TIME"), 36, UI.YELLOW)
	mid.add_child(_time_caption)
	_time_label = UI.label("45", 144, UI.YELLOW)
	mid.add_child(_time_label)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mid)
	_hud_mid = mid
	var right := UI.vstack(4)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	_stage_label = UI.label("", 36, UI.CYAN)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_stage_label)
	_mode_label = UI.label("", 36, UI.GREY)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_mode_label)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)

	# Bottom dashboard (D-103): tachometer | gear + nitro | speedometer, drawn
	# in the director's segmented-dial style. Fixed-size slots: changing values
	# never move anything (D-096).
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -390
	bottom.offset_bottom = -24
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 0)
	_hud.add_child(bottom)
	# Tachometer: 0..8 x1000 rpm, red from 7.
	var tbox := UI.vstack(0)
	tbox.alignment = BoxContainer.ALIGNMENT_END
	_tacho = Dial.new()
	var tl := []
	for i in 9:
		if i % 2 == 0:
			tl.append([i / 8.0, str(i)])
	_tacho.setup(DIAL_R, 16, tl, 7.0 / 8.0, UI.YELLOW)   # same size as the speedo (D-149)
	# Perfect-shift band, just before the red (D-116).
	_tacho.good_from = _tach_of(Sim.PERFECT_FROM)
	_tacho.good_to = _tach_of(Sim.PERFECT_TO)
	tbox.add_child(_tacho)
	# Shift lamp (D-197): between the 4, the 6 and the hub.
	_tacho.lamp_at = (_tacho.hub() + _tacho.label_pos(4.0 / 8.0) + _tacho.label_pos(6.0 / 8.0)) / 3.0
	var rpm_l := UI.label(tr("RC_RPM"), 24, UI.GREY)
	rpm_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rpm_l.custom_minimum_size.x = _tacho.custom_minimum_size.x
	tbox.add_child(rpm_l)
	bottom.add_child(tbox)
	_hud_bottom = bottom
	# D-254: in landscape a gap pushes the gear and speedo to the right side.
	_hud_gap = Control.new()
	_hud_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_gap.visible = false
	bottom.add_child(_hud_gap)
	# Gear indicator + shift light + nitro timer.
	var gbox := UI.vstack(6)
	gbox.alignment = BoxContainer.ALIGNMENT_END
	gbox.custom_minimum_size.x = 200
	# Gear lever in an H/L gate (D-110).
	_gear_lever = GearLever.new()
	gbox.add_child(_gear_lever)
	_nitro_label = UI.label(tr("RC_NITRO"), 24, UI.CYAN)
	_nitro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nitro_label.modulate.a = 0.0
	gbox.add_child(_nitro_label)
	var strip_bg := Control.new()
	strip_bg.custom_minimum_size = Vector2(160, 12)
	strip_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_nitro_strip = ColorRect.new()
	_nitro_strip.color = UI.CYAN
	_nitro_strip.size = Vector2(0, 12)
	strip_bg.add_child(_nitro_strip)
	gbox.add_child(strip_bg)
	bottom.add_child(gbox)
	# Speedometer: 0..360 km/h, digital readout under the hub.
	var sbox := UI.vstack(0)
	sbox.alignment = BoxContainer.ALIGNMENT_END
	_speedo = Dial.new()
	var sl := []
	for k in range(0, SPEEDO_MAX + 1, 40):   # mph (D-147)
		sl.append([k / float(SPEEDO_MAX), str(k)])
	_speedo.setup(DIAL_R, 24, sl, 2.0, UI.CYAN)
	sbox.add_child(_speedo)
	_speed_label = UI.label("0", 60, UI.WHITE)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.custom_minimum_size = Vector2(160, 0)
	_speed_label.position = _speedo.hub() + Vector2(-80, 24)
	_speedo.add_child(_speed_label)
	_nitro_pop = UI.styled_label(tr("RC_NITRO"), TITLE_FONT, 1)
	_nitro_pop.custom_minimum_size = Vector2(320, 0)
	_nitro_pop.position = _speedo.hub() + Vector2(-160, -DIAL_R - 70.0)
	_nitro_pop.modulate.a = 0.0
	_speedo.add_child(_nitro_pop)
	var kmh := UI.label(tr("RC_KMH"), 24, UI.GREY)
	kmh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kmh.custom_minimum_size.x = _speedo.custom_minimum_size.x
	sbox.add_child(kmh)
	bottom.add_child(sbox)

	# SHIFT nag with a little shifter beside it, pushing L -> H (D-151).
	var nag := HBoxContainer.new()
	nag.alignment = BoxContainer.ALIGNMENT_CENTER
	nag.add_theme_constant_override("separation", 24)
	nag.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	nag.offset_left = -500
	nag.offset_right = 500
	nag.offset_top = -330
	nag.offset_bottom = -110
	_shift_big = UI.label(tr("RC_SHIFT"), 144, UI.RED)
	_shift_big.modulate.a = 0.0
	# Fixed slot; the word moves inside it (D-158), so nothing else shifts.
	var slot := Control.new()
	slot.add_child(_shift_big)
	_shift_slot = slot
	_shift_big.position = Vector2(0, SHIFT_RISE)
	nag.add_child(slot)
	_nag_lever = GearLever.new()
	_nag_lever.modulate.a = 0.0
	nag.add_child(_nag_lever)
	_hud.add_child(nag)
	_frozen_label = UI.label(tr("RC_DEBUG_FROZEN"), 24, UI.CYAN)
	_frozen_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_frozen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frozen_label.offset_left = -300
	_frozen_label.offset_right = 300
	_frozen_label.offset_top = 270
	_frozen_label.modulate.a = 1.0 if _freeze_time else 0.0
	_hud.add_child(_frozen_label)
	# Radar detector light bar at the top, under the clock (D-137).
	_radar_bar = RadarBar.new()
	_radar_bar.position = Vector2(0, 2)
	_radar_bar.size = Vector2(1080, _radar_bar.custom_minimum_size.y)
	_hud.add_child(_radar_bar)




## Tunnel lamp light falling on a car at s (D-153): peaks right under each
## ceiling lamp (Tunnel.LIGHT_EVERY apart), fading over a few metres.
func _overhead(s_at: float) -> float:
	if not sim.track.in_tunnel(s_at):
		return 0.0
	var d := absf(fposmod(s_at + Tunnel.LIGHT_EVERY * 0.5, Tunnel.LIGHT_EVERY) - Tunnel.LIGHT_EVERY * 0.5)
	return clampf(1.0 - d / 6.0, 0.0, 1.0)


## Tachometer needle 0..1: idle at 1/8, the gear's top speed near the end.
func _tach_value() -> float:
	return _tach_of(sim.rpm)


func _tach_of(rpm: float) -> float:
	return lerpf(0.11, 1.0, rpm)


func _gear_text(g: int) -> String:
	return tr("RC_GEAR_L") if g == Sim.Gear.LOW else tr("RC_GEAR_H")


## The 4-button layout is in use: the operator set it, or a magna save was
## pressed this session (D-189).
func _four_buttons() -> bool:
	if _touch_play():
		return false
	return _manual_locked or (sim != null and sim.manual) or _seen_magna


## D-283: playing on the touch overlay, which has the two flippers and LAUNCH
## only (D-282): no magna saves, so the 2-button mode and shorter help texts.
func _touch_play() -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("touch_controls"):
		if n.overlay and n.left.visible:
			return true
	return false


func _show_mode() -> void:
	_mode_label.text = tr("RC_MODE_MANUAL") if sim.manual else tr("RC_MODE_AUTO")


func _center_message(text: String, seconds: float) -> void:
	if is_instance_valid(_center):
		_center.queue_free()
	_cops_flash = false
	var l := UI.styled_label(text, TITLE_FONT, 4)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset_bottom = -300
	_add_ui(l)
	_center = l
	_center_t = seconds


func _update_hud(delta: float) -> void:
	if _two:   # D-289: no clock; the race position instead
		_time_label.text = tr("RC_FIRST") if _leading() else tr("RC_SECOND")
		UI.set_color(_time_label, UI.YELLOW if _leading() else UI.WHITE)
	else:
		_time_label.text = str(ceili(sim.time_left))
	var low := sim.time_left < 10.0 and not _two
	UI.set_color(_time_label, UI.RED if low and fmod(sim.time_left, 0.5) < 0.25 else UI.YELLOW)
	if low and sim.state == Sim.State.RACE and ceili(sim.time_left) != _last_tick:
		_last_tick = ceili(sim.time_left)
		Audio.sfx("rc_tick")
	_score_label.text = ScoreTable.format_score(sim.score)
	_stage_label.text = tr("RC_FINISH") if sim.finished else tr("RC_STAGE") % (sim.checkpoints + 1)
	_speed_label.text = str(sim.speed_mph())
	UI.set_color(_speed_label, UI.CYAN if sim.boosting else UI.WHITE)
	_speedo.set_value(sim.v * Sim.MPH / SPEEDO_MAX)
	_tacho.set_value(_tach_value())
	var countdown := sim.state == Sim.State.COUNTDOWN
	_tacho.good_from = _tach_of(Sim.START_FROM if countdown else Sim.PERFECT_FROM)
	_tacho.good_to = _tach_of(Sim.START_TO if countdown else Sim.PERFECT_TO)
	# Shift lamp (D-197): red while a perfect shift (or, on the grid, a perfect
	# start) is on: the revs are in the green band, in L.
	var in_band := sim.rpm >= (Sim.START_FROM if countdown else Sim.PERFECT_FROM) 		and sim.rpm < (Sim.START_TO if countdown else Sim.PERFECT_TO)
	_tacho.lamp_on = in_band and (countdown or (sim.gear == Sim.Gear.LOW and sim.state == Sim.State.RACE))
	_update_rev_hint(countdown)
	_gear_lever.set_gear(sim.gear == Sim.Gear.HIGH)
	var shift_now := sim.gear == Sim.Gear.LOW and sim.rpm >= Sim.REDLINE
	# Held at the redline in L for SHIFT_NAG s: a big blinking SHIFT in the
	# middle of the screen, in the timer's font (D-116).
	_redline_t = _redline_t + delta if shift_now and sim.state == Sim.State.RACE else 0.0
	# Only the first time after the start or a crash (D-160): once shown and
	# then resolved, it stays off until the next crash.
	var nagging := _shift_armed and _redline_t >= SHIFT_NAG
	if nagging:
		_shift_shown = true
	elif _shift_shown and _redline_t == 0.0:
		_shift_armed = false
		_shift_shown = false
	_shift_big.modulate.a = 1.0 if nagging and fmod(_phase_t, 0.4) < 0.25 else 0.0
	# Looping rise (D-158): up SHIFT_RISE px in 4 stepped frames, then back.
	var rise := floorf(fmod(_phase_t, 0.5) / 0.5 * 4.0) / 4.0
	_shift_big.position.y = SHIFT_RISE * (1.0 - rise)
	var need := _shift_big.get_combined_minimum_size() + Vector2(0, SHIFT_RISE)
	if _shift_slot.custom_minimum_size != need:   # size the slot once the label is laid out
		_shift_slot.custom_minimum_size = need
	_nag_lever.modulate.a = 1.0 if nagging else 0.0
	if nagging:   # demo loop: sit in L, push up to H, hold; restart at L instantly (D-155)
		var ph := fmod(_redline_t, 1.2)
		if ph < 0.5:
			if _nag_lever.high:
				_nag_lever.snap_low()
		else:
			_nag_lever.set_gear(true)
	_nitro_label.modulate.a = 1.0 if sim.boosting else 0.0
	_nitro_strip.size.x = roundf(160.0 * sim.boost_t / Sim.NITRO_TIME)
	if sim.drifting:
		_drift_label.text = tr("RC_DRIFT_POINTS") % ScoreTable.format_score(int(sim.drift_points / 10.0) * 10)
		_drift_label.modulate.a = 1.0
	else:
		_drift_label.modulate.a = maxf(0.0, _drift_label.modulate.a - delta * 0.8)
	_nitro_pop_t = maxf(0.0, _nitro_pop_t - delta)
	_nitro_pop.modulate.a = 1.0 if _nitro_pop_t > 0.0 and fmod(_nitro_pop_t, 0.2) > 0.06 else 0.0
	if _cops_flash and is_instance_valid(_center):
		var red := fmod(_phase_t, 0.24) < 0.12
		_center.self_modulate = Color(1.0, 0.25, 0.2) if red else Color(0.35, 0.5, 1.0)
	if _center_t > 0.0:
		_center_t -= delta
		if _center_t <= 0.0 and is_instance_valid(_center):
			_center.queue_free()
	_dmd_t -= delta
	if _dmd_t <= 0.0 and sim.state != Sim.State.COUNTDOWN:
		_dmd_t = 0.12
		_dmd.show_custom(_draw_dmd_dash)
	if not _two:
		score_changed.emit(0, sim.score)


## 2P: this view's player is ahead (or won).
func _leading() -> bool:
	if sim.winner >= 0:
		return sim.winner == _role
	return float(sim.player_get(_role, "s")) >= float(sim.player_get(1 - _role, "s"))


## DMD while the cops chase (D-162): a side view, our car on the right and the
## police car behind at a gap that follows the real distance (up to 150 m),
## its light bar flashing; the road dashes scroll with our speed. Distance in
## feet top left, speed top right.
func _draw_dmd_chase(p) -> void:
	var pd: Dictionary = sim.police
	var d := maxf(0.0, sim.s - float(pd.s))
	var t := _phase_t
	p.line(0, 29, 127, 29, Color(0.3, 0.3, 0.35))
	var scroll := fmod(sim.s * 1.5, 16.0)
	for i in 9:
		var dx := 128.0 - fmod(i * 16.0 + scroll, 144.0)
		p.line(dx, 31, dx + 6, 31, Color(0.5, 0.5, 0.55))
	# D-245: the player's own car (D-243) and the police car's sprite.
	_anims._player(p, 108, 24)
	var px := 108.0 - 24.0 - clampf(d / 150.0, 0.0, 1.0) * 78.0
	_anims._police(p, px, 24, t)
	var red := fmod(t, 0.24) < 0.12
	# Speed lines behind the police car.
	for i in 3:
		p.line(px - 6 - i * 2, 24 + i * 2, px - 10 - i * 4 - fmod(t * 40.0, 4.0), 24 + i * 2, Color(0.35, 0.35, 0.4))
	var ft := roundi(d * 3.281)
	p.text(tr("RC_DMD_FT") % ft, 2, 2, 1, Dmd.RED if d < 30.0 and red else Dmd.YELLOW)
	var spd := tr("RC_DMD_MPH") % sim.speed_mph()
	p.text(spd, 126 - p.text_width(spd), 2, 1, Dmd.WHITE)
	if _radar_led > 0.0:
		p.disc(64, 4, 1.6, Dmd.RED)


## DMD during the countdown (D-154): REV UP! and the count on the left; a
## pixel tachometer on the right whose needle follows the player's revs, with
## the perfect-start window in green (red past it). It wobbles at idle.
func _draw_dmd_revup(p) -> void:
	if sim == null or sim.state != Sim.State.COUNTDOWN:
		return
	var t := _phase_t
	p.text(tr("RC_REV_UP"), 2, 2, 2, Dmd.YELLOW if fmod(t, 0.5) < 0.32 else Dmd.WHITE)
	p.text(str(maxi(1, ceili(sim.countdown))), 2, 19, 1, Dmd.WHITE)
	# Dial: centre bottom right, sweeping 180 degrees.
	const C := Vector2(104, 29)
	const R := 22.0
	for i in 19:
		var f := i / 18.0
		var a := PI + f * PI
		var col := Color(0.25, 0.27, 0.3)
		if f >= Sim.START_FROM and f < Sim.START_TO:
			col = Dmd.GREEN
		elif f >= Sim.START_TO:
			col = Dmd.RED
		for k in 3:
			var r := R - k
			p.dot(C.x + cos(a) * r, C.y + sin(a) * r, col)
	var v := sim.rpm
	if sim.throttle <= 0.0:
		v = 0.08 + 0.03 * sin(t * 25.0)   # idle wobble
	var na := PI + clampf(v, 0.0, 1.0) * PI
	var in_band := sim.rpm >= Sim.START_FROM and sim.rpm < Sim.START_TO
	p.line(C.x, C.y, C.x + cos(na) * (R - 4), C.y + sin(na) * (R - 4), Dmd.GREEN if in_band else Dmd.WHITE)
	p.disc(C.x, C.y, 1.5, Dmd.WHITE)


## REV! hint (D-197): while the countdown runs, a hand to the right of the
## tachometer points left at its green band with REV! above it, bobbing; it
## goes when the race starts.
func _update_rev_hint(countdown: bool) -> void:
	if _rev_hint == null:
		_rev_hint = Control.new()
		_rev_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rev_hand = TextureRect.new()
		_rev_hand.texture = load(REV_HAND)
		_rev_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_rev_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rev_hand.size = Vector2(_rev_hand.texture.get_size()) * 2.0
		_rev_hint.add_child(_rev_hand)
		var lab := UI.styled_label(tr("RC_REV_HINT"), TITLE_FONT, 2)
		lab.position = Vector2(4, -94)
		_rev_hint.add_child(lab)
		_hud.add_child(_rev_hint)
	var show := countdown and _phase == "race"
	_rev_hint.modulate.a = 1.0 if show else 0.0
	if not show:
		return
	# The fingertip (the hand's left edge, middle) a little outside the green
	# band; it pokes towards it 3 times, then holds still (D-209).
	var band := (_tach_of(Sim.START_FROM) + _tach_of(Sim.START_TO)) * 0.5
	var target: Vector2 = _tacho.global_position - _hud.global_position + _tacho.arc_point(band)
	var poke := 0.0
	if _phase_t < REV_POKES * TAU / REV_POKE_RATE:
		poke = 0.5 - 0.5 * cos(_phase_t * REV_POKE_RATE)   # 0 out, 1 in
	var bob := REV_HAND_GAP - 18.0 * poke
	_rev_hint.position = target + Vector2(bob, -_rev_hand.size.y * 0.5)


## DMD dashboard (D-103): segmented speedometer dial (the director's icon
## style) on the left, digital speed + score, gear box and clock on the right,
## and a horizontal tachometer bar along the bottom (red zone = shift up).
func _draw_dmd_dash(p) -> void:
	if sim == null:
		return
	if sim.police_lights():
		_draw_dmd_chase(p)   # D-162
		return
	# Radar detector LED (D-135), top-left corner.
	if _radar_led > 0.0:
		p.disc(2, 2, 1.6, Dmd.RED)
	const HUB := Vector2(17, 22)
	const R := 16.0
	const SEGS := 11
	var a_from := Dial.SWEEP_FROM
	var a_to := Dial.SWEEP_TO
	var speed_f := clampf(sim.v * Sim.MPH / SPEEDO_MAX, 0.0, 1.0)
	for y in range(int(HUB.y - R) - 1, 32):
		for xx in range(0, 36):
			var d := Vector2(xx + 0.5, y + 0.5) - HUB
			var r := d.length()
			var a := atan2(d.y, d.x)
			if a < a_from - 0.01:
				a += TAU
			if a < a_from or a > a_to or r > R:
				continue
			var f := (a - a_from) / (a_to - a_from)
			var i := mini(int(f * SEGS), SEGS - 1)
			var fi := (i + 0.5) / SEGS
			var k := clampf((fi - 0.15) / 0.85, 0.0, 1.0)
			var depth := lerpf(1.6, 5.0, k)
			var seg_pos := f * SEGS - i
			var gap := lerpf(0.5, 0.18, k)
			if r < R - depth or seg_pos < gap * 0.5 or seg_pos > 1.0 - gap * 0.5:
				continue
			var lit := speed_f >= fi
			var c := (Dmd.CYAN if not sim.boosting else Dmd.WHITE) if lit else Color(0.16, 0.18, 0.22)
			p.dot(xx, y, c)
	var na := lerpf(a_from, a_to, speed_f)
	var tip := HUB + Vector2(cos(na), sin(na)) * (R - 2.0)
	p.line(HUB.x, HUB.y, tip.x, tip.y, Dmd.WHITE)
	p.ring(HUB.x, HUB.y, 2.0, Dmd.WHITE)
	p.dot(HUB.x, HUB.y, Color.BLACK)
	# Digital speed + score
	var spd := str(sim.speed_mph())
	p.text(spd, 72 - p.text_width(spd, 2), 1, 2, Dmd.CYAN if sim.boosting else Dmd.WHITE)
	p.text(tr("RC_KMH"), 74, 8, 1, Dmd.DIM)
	var sc := ScoreTable.format_score(sim.score)
	p.text(sc, 104 - p.text_width(sc), 17, 1, Dmd.YELLOW)
	# Gear box
	var g := _gear_text(sim.gear)
	var gc := Dmd.YELLOW if sim.gear == Sim.Gear.LOW else Dmd.WHITE
	p.block(106, 0, 22, 1, gc)
	p.block(106, 18, 22, 1, gc)
	p.block(106, 0, 1, 19, gc)
	p.block(127, 0, 1, 19, gc)
	p.text(g, 117 - p.text_width(g, 2) / 2.0, 3, 2, gc)
	# Clock
	var low := sim.time_left < 10.0
	var t := str(ceili(sim.time_left))
	p.text(t, 127 - p.text_width(t), 21, 1, Dmd.RED if low and fmod(_phase_t, 0.5) < 0.25 else Dmd.YELLOW)
	# Tachometer bar: 13 cells, red from 7/8; blinks when it's time to shift.
	const CELLS := 13
	var tach := _tach_value()
	var shift_now := sim.gear == Sim.Gear.LOW and sim.rpm >= Sim.REDLINE
	for i in CELLS:
		var f := (i + 0.5) / CELLS
		var red := f >= 7.0 / 8.0
		var on := tach >= f
		var c := Color(0.16, 0.18, 0.22)
		var cd := sim.state == Sim.State.COUNTDOWN   # the start window on the grid (D-128)
		var good := f >= _tach_of(Sim.START_FROM if cd else Sim.PERFECT_FROM) 			and f < _tach_of(Sim.START_TO if cd else Sim.PERFECT_TO)
		if on:
			c = Dmd.RED if red else (Dmd.WHITE if good else (Dmd.YELLOW if f > 0.6 else Dmd.GREEN))
		elif red:
			c = Color(0.35, 0.08, 0.1)
		elif good:
			c = Color(0.1, 0.35, 0.15)   # perfect-shift band (D-116)
		if shift_now and fmod(_phase_t, 0.24) < 0.12:
			c = Dmd.RED
		p.block(38 + i * 5, 27, 4, 5, c)


func _build_backglass() -> void:
	# Director's backglass art with two light groups (D-109): the logo and the
	# lights (headlights, truck lights, sparks, stars), driven by the race.
	add_to_backglass(UI.fill(Color.BLACK))
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = load(BG_DIR + "backglass_off.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BACKGLASS_SHADER
	_bg_mat.set_shader_parameter("on_tex", load(BG_DIR + "backglass_on.png"))
	_bg_mat.set_shader_parameter("mask_tex", load(BG_DIR + "backglass_mask.png"))
	_bg_mat.set_shader_parameter("logo_mask_tex", load(BG_DIR + "backglass_mask_logo.png"))
	art.material = _bg_mat
	add_to_backglass(art)


## Time of day (D-193): the race's progress sets the hour (games/racer/sky.gd):
## stages 1-3 day, 4-5 sunset, 6-9 night, dawn in 10. The sun and moon move,
## the sky, light, ambient and fog take the palette of the sun's elevation, and
## the fake lights (car beams, tail lights, lamp pools) come on as it gets dark.
## --rc-tod=<progress> / --rc-sunset / --rc-night pick a time for screenshots.
func _update_night(delta: float) -> void:
	var p := _tod_progress()
	_tod_p = p if _tod_p < 0.0 else move_toward(_tod_p, p, delta * 0.5)   # smooths jumps (new race, debug skips)
	var hour := TimeOfDay.hour_at(_tod_p)
	var el := TimeOfDay.sun_elevation(hour)
	_night = TimeOfDay.night_level(el)
	# Tunnels (D-127): lights on and daylight dimmed while inside, any stage;
	# the effects bus gets a reverb.
	var in_t := sim != null and sim.in_tunnel
	_tunnel_k = move_toward(_tunnel_k, 1.0 if in_t else 0.0, delta / 0.4)
	_lamps = maxf(_night, _tunnel_k)
	if _reverb != null:
		_reverb.wet = 0.45 * _tunnel_k
		_set_reverb(_tunnel_k > 0.0)
	if _main and absf(_lamps - _lamps_shown) > 0.002:   # (shared materials: player 1's view, D-289)
		_lamps_shown = _lamps
		Night.set_level(_lamps)
		get_tree().call_group(NIGHT_GROUP, "set_visible", _lamps > 0.0)
		Sprites.set_night(_night)
	var pal := TimeOfDay.palette(el)
	var fog: Color = (pal.horizon as Color).lerp(pal.ridge_far, 0.35)
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("sun_dir", TimeOfDay.sun_dir(hour))
		_sky_mat.set_shader_parameter("moon_dir", TimeOfDay.moon_dir(hour))
		for k in ["zenith", "horizon", "glow", "cloud_lit", "cloud_shade", "ridge_far", "ridge_near"]:
			_sky_mat.set_shader_parameter(k, pal[k])
		_sky_mat.set_shader_parameter("glow_strength", pal.glow_k)
		_sky_mat.set_shader_parameter("sun_col", pal.sun)
		_sky_mat.set_shader_parameter("ground", fog)
		_sky_mat.set_shader_parameter("stars", 1.0 - smoothstep(-14.0, -4.0, el))
		_sky_mat.set_shader_parameter("moon", 1.0 - smoothstep(-6.0, -1.0, el))
	var dim := 1.0 - 0.85 * _tunnel_k
	# Weather (D-217): overcast skies, closer fog, dimmer sun; rain wets the
	# road and fills the puddles; particles fall around the camera.
	var wt: Dictionary = sim.track.weather(sim.s) if sim != null and _phase != "attract" else {}
	if Config.cli.has("rc-weather"):   # dev: force a weather for screenshots
		wt = {str(Config.cli["rc-weather"]): 1.0}
	for k in _wx:
		_wx[k] = move_toward(float(_wx[k]), float(wt.get(k, 0.0)), delta * 0.6)
	var overcast := maxf(maxf(float(_wx.rain), float(_wx.snow)), float(_wx.fog) * 0.8)
	var haze := float(_wx.haze)
	if _sky_mat != null and (overcast > 0.0 or haze > 0.0):
		var grey := func(c: Color, k: float) -> Color:
			var l := c.get_luminance()
			return c.lerp(Color(l, l, l * 1.05), k)
		_sky_mat.set_shader_parameter("zenith", grey.call(pal.zenith, 0.85 * overcast).darkened(0.25 * overcast).lerp(HAZE_COL.darkened(0.2), 0.5 * haze))
		_sky_mat.set_shader_parameter("horizon", grey.call(pal.horizon, 0.8 * overcast).lerp(HAZE_COL, 0.7 * haze))
		_sky_mat.set_shader_parameter("cloud_lit", grey.call(pal.cloud_lit, 0.7 * overcast).darkened(0.3 * overcast).lerp(HAZE_COL.lightened(0.3), 0.5 * haze))
		_sky_mat.set_shader_parameter("cloud_shade", grey.call(pal.cloud_shade, 0.7 * overcast).darkened(0.35 * overcast).lerp(HAZE_COL.darkened(0.1), 0.5 * haze))
		_sky_mat.set_shader_parameter("sun_col", (pal.sun as Color) * (1.0 - overcast))
		_sky_mat.set_shader_parameter("glow_strength", float(pal.glow_k) * (1.0 - overcast))
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("cloud_cover", lerpf(0.56, 0.12, overcast))
	fog = fog.lerp(Color(fog.get_luminance(), fog.get_luminance(), fog.get_luminance() * 1.04), 0.6 * overcast)
	fog = fog.lerp(HAZE_COL * clampf(fog.get_luminance() * 1.6, 0.2, 1.0), 0.8 * haze)
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("ground", fog)
	var fog_b := 250.0
	var fog_e := VIEW_AHEAD - 50.0
	for k in WEATHER_FOG:
		var w := float(_wx[k])
		if w > 0.0:
			fog_b = minf(fog_b, lerpf(250.0, (WEATHER_FOG[k] as Vector2).x, w))
			fog_e = minf(fog_e, lerpf(VIEW_AHEAD - 50.0, (WEATHER_FOG[k] as Vector2).y, w))
	_env.fog_depth_begin = fog_b
	_env.fog_depth_end = fog_e
	dim *= 1.0 - 0.55 * overcast
	_road_mat.set_shader_parameter("wet", _wx.rain)
	_puddle_mat.set_shader_parameter("wet", _wx.rain)
	if _cam != null and _cam.is_inside_tree() and _weather.is_inside_tree():
		var ahead := _cam.global_position - _cam.global_basis.z * 16.0 + Vector3(0.0, 4.0, 0.0)
		_weather.update(_wx.rain, _wx.snow, ahead, _tunnel_k > 0.5)
	_env.fog_light_color = fog
	_env.ambient_light_color = pal.amb
	_env.ambient_light_energy = float(pal.amb_e) * (1.0 - 0.5 * _tunnel_k)
	# The light comes from the sun while it's up, then from the moon.
	var from: Vector3 = TimeOfDay.sun_dir(hour) if el > -4.0 else TimeOfDay.moon_dir(hour)
	if from.y < 0.05:
		from = Vector3(from.x, 0.05, from.z).normalized()
	_sun.basis = Basis.looking_at(-from, Vector3.UP)
	_sun.light_color = pal.light
	_sun.light_energy = float(pal.light_e) * dim
	# Shadows (D-253): full by day, faint by moonlight, none in tunnels.
	_sun.shadow_opacity = clampf(1.0 - _night * 0.75, 0.0, 1.0) * (1.0 - _tunnel_k) * SHADOW_STRENGTH * \
		(1.0 - 0.6 * float(_wx.get("rain", 0.0)) - 0.6 * float(_wx.get("snow", 0.0)) - 0.8 * float(_wx.get("fog", 0.0)))
	if _blob_mat != null:
		_blob_mat.albedo_color = Color(0, 0, 0, 0.45 * _sun.shadow_opacity / SHADOW_STRENGTH + 0.12)


## Race progress for the time of day: stages played plus how far into this one.
func _tod_progress() -> float:
	if Config.cli.has("rc-tod"):
		return float(str(Config.cli["rc-tod"]))
	if Config.cli.has("rc-night"):
		return 7.0
	if Config.cli.has("rc-sunset"):
		return 4.6
	if _phase == "attract" or sim == null:
		return 0.5
	var into := 1.0 - clampf((sim.next_checkpoint - sim.s) / Sim.CHECKPOINT_EVERY, 0.0, 1.0)
	return float(sim.checkpoints) + into


## Radar beep (D-215): its own player on a dry bus with the SFX bus's volume,
## so the tunnel reverb on SFX doesn't touch it (the detector is in the car).
func _radar_beep() -> void:
	var sfx := AudioServer.get_bus_index("SFX")
	var dry := AudioServer.get_bus_index(DRY_BUS)
	if dry < 0:
		dry = AudioServer.bus_count
		AudioServer.add_bus(dry)
		AudioServer.set_bus_name(dry, DRY_BUS)
		AudioServer.set_bus_send(dry, "Master")
	if sfx >= 0:
		AudioServer.set_bus_volume_db(dry, AudioServer.get_bus_volume_db(sfx))
		AudioServer.set_bus_mute(dry, AudioServer.is_bus_mute(sfx))
	if _radar_player == null:
		_radar_player = AudioStreamPlayer.new()
		_radar_player.bus = DRY_BUS
		_radar_player.stream = Audio._sounds.get("rc_radar")
		add_child(_radar_player)
	_radar_player.play()


func _exit_tree() -> void:
	if _two and _main:
		CabinetInput.set_two_player(false)   # D-289: player 2's keys go back to 1P
	get_tree().call_group("touch_controls", "set_labels", {})   # D-219
	if Screens.table_shape_changed.is_connected(_on_table_shape):
		Screens.table_shape_changed.disconnect(_on_table_shape)

	# Take the tunnel reverb off the shared effects bus (D-127).
	var bus := AudioServer.get_bus_index("SFX")
	if _reverb != null and bus >= 0:
		for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, i) == _reverb:
				AudioServer.remove_bus_effect(bus, i)
	super._exit_tree()


## Debug builds only (DebugTools, D-057): F freezes / unfreezes the race clock
## (D-118). Shown on the HUD so it isn't left on by accident.
func _on_debug_action(action: StringName) -> void:
	if action == &"spawn_police":
		# Debug O (D-138): a police car comes from behind right away.
		if sim != null and _phase == "race" and sim.state == Sim.State.RACE and sim.police.is_empty():
			sim.police = {"s": sim.s - Sim.POLICE_BEHIND, "x": sim.x, "v": sim.v, "state": "chase", "t": 0.0}
			_center_message(tr("RC_POLICE"), 1.4)
			_cops_flash = true   # red/blue flashing text (D-158)
			_dmd.flash(tr("RC_POLICE"), 1.4, Dmd.RED)
		return
	if action == &"skip_stage":
		_debug_skip_to_night()
		return
	if action != &"fire_line":
		return
	_freeze_time = not _freeze_time
	if sim != null:
		sim.freeze_time = _freeze_time
	if is_instance_valid(_frozen_label):
		_frozen_label.modulate.a = 1.0 if _freeze_time else 0.0


## Debug S (D-121): jump to stage 5 (night falls) without driving there.
func _debug_skip_to_night() -> void:
	if sim == null or _phase != "race" or sim.checkpoints >= Night.NIGHT_STAGE - 1:
		return
	sim.checkpoints = Night.NIGHT_STAGE - 1
	sim.next_checkpoint = sim.s + Sim.CHECKPOINT_EVERY
	sim.time_left = maxf(sim.time_left, 60.0)
	_dmd.flash(tr("RC_STAGE") % (sim.checkpoints + 1), 1.0, Dmd.CYAN)


## Plays one of the DMD event animations (D-115) with its translated texts.
func _dmd_anim(name: String, args: Array) -> void:
	_dmd.play(Callable(_anims, name).bindv(args), DmdAnims.DURATIONS[name])


## Backglass lights each frame (D-109). Attract: the logo blinks slowly, the
## lights are on. Race: both on; nitro, checkpoints and near misses flash the
## lights; a crash knocks them out briefly. Game over: only the logo stays.
func _update_backglass(delta: float) -> void:
	if _bg_mat == null:
		return
	_bg_flash = maxf(0.0, _bg_flash - delta)
	_bg_dark = maxf(0.0, _bg_dark - delta)
	var lights := 1.0
	var logo := 1.0
	if _phase == "attract":
		logo = 1.0 if fmod(_phase_t, 1.2) < 0.8 else 0.0
	elif _finale_t >= 0.0 or (sim != null and sim.state == Sim.State.OVER):
		lights = 0.0
	if _bg_dark > 0.0:
		lights = 0.0 if fmod(_bg_dark, 0.16) < 0.1 else 0.3
	elif _bg_flash > 0.0:
		lights = 1.0 if fmod(_bg_flash, 0.1) < 0.05 else 0.2
		logo = maxf(logo, lights)
	_bg_mat.set_shader_parameter("levels", Vector4(lights, 0.0, 0.0, logo))


func _logo_rect(width: float) -> TextureRect:
	var tex: Texture2D = load(LOGO)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(width, width * tex.get_height() / tex.get_width())
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r


# --- audio ---------------------------------------------------------------------------
## Looping engine and tyre-squeal streams, generated here (Synth makes one-shots).
func _build_audio_loops() -> void:
	# Engine (D-116): three layers mixed by rpm and speed, 16/32-bit style rather
	# than realistic. Each loop holds a whole number of cycles (0.4 s).
	# Body: a firing-pulse train (80 Hz) with uneven cylinders and a sub tone.
	_engine = AudioStreamPlayer.new()
	_engine.bus = "SFX"
	_engine.stream = _loop_wav("engine", func(t: float) -> float:
		var fire := t * 80.0
		var ph := fmod(fire, 1.0)
		var amp: float = [1.0, 0.82, 0.94, 0.78][int(fire) % 4]
		var pulse := exp(-ph * 5.0) * (sin(TAU * ph * 2.0) * 0.7 + sin(TAU * ph * 5.0) * 0.25)
		return pulse * amp * 0.75 + sin(TAU * 40.0 * t) * 0.22, 0.4, 0.04)
	_engine.volume_db = -8.0
	add_child(_engine)
	# Whine: soft harmonics of 160 Hz, rising with the revs.
	_engine_hi = AudioStreamPlayer.new()
	_engine_hi.bus = "SFX"
	_engine_hi.stream = _loop_wav("engine_hi", func(t: float) -> float:
		var v := 0.0
		for n in range(1, 7):
			v += sin(TAU * 160.0 * n * t) / n * (1.0 if n % 2 == 1 else -0.6)
		return v * 0.32, 0.4, 0.0)
	_engine_hi.volume_db = -60.0
	add_child(_engine_hi)
	# Wind: filtered noise that grows with speed.
	_wind = AudioStreamPlayer.new()
	_wind.bus = "SFX"
	_wind.stream = _loop_wav("wind", func(_t: float) -> float: return 0.0, 1.0, 0.7)
	_wind.volume_db = -60.0
	add_child(_wind)
	_engine_hi.play()
	_wind.play()
	# Passing traffic (D-134): a buzzy engine loop per nearby vehicle.
	var buzz := _loop_wav("buzz", func(t: float) -> float:
		var ph := fmod(t * 110.0, 1.0)
		# D-192: brighter (upper harmonics) so it cuts through the hero's engine.
		return (ph * 2.0 - 1.0) * 0.3 + sin(TAU * 220.0 * t) * 0.18 + sin(TAU * 55.0 * t) * 0.2 			+ sin(TAU * 440.0 * t) * 0.12 + sin(TAU * 660.0 * t) * 0.07, 0.4, 0.06)
	for i in PASSERS:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		pl.stream = buzz
		pl.volume_db = -80.0
		add_child(pl)
		pl.play()
		_passers.append(pl)
	_skid = AudioStreamPlayer.new()
	_skid.bus = "SFX"
	_skid.stream = _loop_wav("skid", func(t: float) -> float:
		return sin(TAU * 950.0 * t + sin(TAU * 25.0 * t) * 2.0) * 0.25, 0.4, 0.5)
	_skid.volume_db = -80.0
	add_child(_skid)
	_build_horn()   # D-213: synthesised up front, not at the first honk
	_engine.play()
	_skid.play()


func _build_horn() -> void:
	_horn = AudioStreamPlayer.new()
	_horn.bus = "SFX"
	add_child(_horn)
	for pat in HORN_PATTERNS:
		_horn_waves.append(_horn_wav(pat))


## An oncoming car honks (D-213): one of the patterns, from that car.
func _honk(id: int) -> void:
	if _horn == null:
		_build_horn()
	_horn_id = id
	_horn.stream = _horn_waves[randi() % _horn_waves.size()]
	_horn_volume_pitch(true)
	_horn.play()


func _update_horn() -> void:
	if _horn != null and _horn.playing:
		_horn_volume_pitch(false)
		_pass_duck = maxf(_pass_duck, HORN_DUCK_DB)   # make room for it (D-214)


func _horn_volume_pitch(snap: bool) -> void:
	var t: Dictionary = {}
	for c in sim.traffic:
		if int(c.id) == _horn_id:
			t = c
			break
	if t.is_empty():
		_horn.volume_db = move_toward(_horn.volume_db, -60.0, 3.0)
		return
	var ds: float = t.s - sim.s
	var d := Vector2(ds, float(t.x) - sim.x).length()
	var closing: float = (sim.v - float(t.v)) * signf(ds if absf(ds) > 0.5 else 1.0)
	var pitch := clampf(HORN_SOUND_SPEED / maxf(HORN_SOUND_SPEED - closing, 60.0), 0.7, 1.5)
	# D-214: a gentle falloff (about 2.4 dB per doubling past 15 m), so a honk
	# from 170 m away still cuts through the engine (was 6 dB: about -24 dB there).
	var vol := 0.0 - 8.0 * log(maxf(d, 15.0) / 15.0) / log(10.0) - 20.0 * clampf((d - HORN_RANGE) / 60.0, 0.0, 1.0)
	if snap:
		_horn.pitch_scale = pitch
		_horn.volume_db = vol
	else:
		_horn.pitch_scale = lerpf(_horn.pitch_scale, pitch, 0.35)
		_horn.volume_db = lerpf(_horn.volume_db, vol, 0.35)


## One cycle of a horn tone (D-213): harmonics at 1/k, boosted around the
## nasal resonance; read back as a wavetable so the synthesis stays cheap.
func _horn_table(f0: float) -> PackedFloat32Array:
	var n := 512
	var table := PackedFloat32Array()
	table.resize(n)
	var k := 1
	while k * f0 < 11000.0:
		var w := 1.0 / k * (1.0 + 2.2 * exp(-pow((k * f0 - HORN_FORMANT) / 700.0, 2.0)))
		for j in n:
			table[j] += sin(TAU * j * k / n) * w
		k += 1
	return table


## Synthesises one honk pattern (mono 16-bit, 32 kHz).
func _horn_wav(pattern: Array) -> AudioStreamWAV:
	var rate := 32000
	var last: Array = pattern[pattern.size() - 1]
	var n := int((float(last[0]) + float(last[1]) + 0.08) * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + pattern.size()
	for press in pattern:
		var t0: float = press[0]
		var len: float = press[1]
		var i0 := int(t0 * rate)
		var i1 := mini(n, int((t0 + len + 0.05) * rate))
		for ti in HORN_TONES.size():
			var f0: float = HORN_TONES[ti]
			var table := _horn_table(f0)
			var tn := table.size()
			var ph := rng.randf()
			var jitter := 0.0
			for i in range(i0, i1):
				var t := float(i - i0) / rate
				# Diaphragm scoop: starts ~4 % flat, settles in 25 ms; slight jitter.
				jitter = clampf(jitter + rng.randf_range(-1.0, 1.0) * 0.0004, -0.004, 0.004)
				var f := f0 * (1.0 - 0.04 * exp(-t / 0.025)) * (1.0 + jitter)
				ph = fmod(ph + f / rate, 1.0)
				var x := ph * tn
				var j := int(x)
				var v := lerpf(table[j % tn], table[(j + 1) % tn], x - j)
				var env := clampf(t / 0.008, 0.0, 1.0) * clampf((t0 + len - (t0 + t)) / 0.035 + 1.0, 0.0, 1.0)
				buf[i] += v * env * (1.0 if ti == 0 else 0.85)
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		# Soft clipping gives the horn its grit.
		var v := tanh(buf[i] / peak * 1.6) / tanh(1.6) * 0.8
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


## Doppler engine noise from the nearest traffic (D-134). Pitch follows the
## closing speed (an exaggerated "speed of sound" so it's clearly arcade), the
## volume falls off with distance; trucks rumble lower.
func _update_passers() -> void:
	var near: Array = []
	_pass_duck = 0.0
	if sim != null and sim.state != Sim.State.COUNTDOWN:
		for t in sim.traffic:
			var ds: float = t.s - sim.s
			var d := Vector2(ds, t.x - sim.x).length()
			if d < PASS_RANGE:
				near.append([d, t])
		near.sort_custom(func(a, b): return a[0] < b[0])
	for i in _passers.size():
		var pl: AudioStreamPlayer = _passers[i]
		if i >= near.size():
			pl.volume_db = lerpf(pl.volume_db, -80.0, 0.2)
			continue
		var d: float = near[i][0]
		var t: Dictionary = near[i][1]
		var ds: float = t.s - sim.s
		# Closing speed: positive while it approaches us, negative once past.
		var closing: float = (sim.v - t.v) * signf(ds if absf(ds) > 0.5 else 1.0)
		var doppler := clampf(SOUND_SPEED / maxf(SOUND_SPEED - closing, 20.0), 0.5, 2.2)
		var base := 0.55 if t.get("kind", "car") == "truck" else 0.85
		pl.pitch_scale = lerpf(pl.pitch_scale, base * doppler, 0.5)   # a sharp drop at the pass
		var target := -2.0 - 30.0 * clampf(d / PASS_RANGE, 0.0, 1.0)
		pl.volume_db = lerpf(pl.volume_db, target, 0.3)
		if i == 0:   # the nearest car ducks the hero's engine and the wind (D-192)
			_pass_duck = PASS_DUCK_DB * clampf(1.0 - d / PASS_DUCK_RANGE, 0.0, 1.0)


static var _loop_cache := {}   # name -> stream, kept for the session


## `key` names the loop: it's generated once per session (sample by sample in
## script, slow on a phone) and reused when the game starts again (D-277).
func _loop_wav(key: String, gen: Callable, seconds: float, noise: float) -> AudioStreamWAV:
	if _loop_cache.has(key):
		return _loop_cache[key]
	var rate := 32000
	var n := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.25)
		var smp := clampf(float(gen.call(t)) + lp * noise, -1.0, 1.0)
		data.encode_s16(i * 2, int(smp * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	_loop_cache[key] = wav
	return wav


func _update_audio() -> void:
	if _engine == null:
		return
	var rpm := sim.rpm
	var pitch := 0.55 + rpm * 1.5 + (0.2 if sim.boosting else 0.0)
	if rpm > 0.97 and fmod(_phase_t * 18.0, 1.0) < 0.5:
		pitch -= 0.15   # rev limiter bouncing (D-112)
	var revving := sim.state == Sim.State.COUNTDOWN and sim.throttle > 0.0
	_engine.pitch_scale = pitch
	_engine_hi.pitch_scale = pitch
	_engine.volume_db = -11.0 + sim.throttle * 3.0 - rpm * 3.0 + (3.0 if revving else 0.0) + ENGINE_GAIN_DB - _pass_duck
	_engine_hi.volume_db = -34.0 + rpm * 22.0 + sim.throttle * 2.0 + (2.0 if revving else 0.0) + ENGINE_GAIN_DB - _pass_duck
	_update_passers()
	_update_horn()
	_wind.volume_db = -46.0 + clampf(sim.v / Sim.MAX_SPEED, 0.0, 1.3) * 28.0 - _pass_duck
	var squeal := sim.drifting or (sim.state == Sim.State.OVER and sim.v > 3.0) 		or (sim.spin_t > 0.0 and not sim.stalled()) or sim.auto_braking
	_skid.volume_db = lerpf(_skid.volume_db, -10.0 if squeal else -60.0, 0.2)
	# D-235: the attract demo (and the menus over it) is music only.
	if _phase in ["attract", "gfx", "stage", "select"]:   # D-236: car select too
		for pl in [_engine, _engine_hi, _wind, _skid, _siren, _horn] + _passers:
			if pl != null:
				(pl as AudioStreamPlayer).volume_db = -80.0
	# D-283: a loop too quiet to hear is paused, so the mixer skips it.
	for pl in [_engine, _engine_hi, _wind, _skid, _siren] + _passers:
		if pl != null:
			var quiet: bool = (pl as AudioStreamPlayer).volume_db < -58.0
			if (pl as AudioStreamPlayer).stream_paused != quiet:
				(pl as AudioStreamPlayer).stream_paused = quiet
