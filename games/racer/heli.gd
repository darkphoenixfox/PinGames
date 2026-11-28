## TURBO RUN news helicopter (D-436): at the first checkpoint and the first in
## the city (D-437) it comes over the camera from behind (in at the top of the
## screen, D-488), flies ahead nose first, swings round to face the player's
## car and hovers ahead of it (filming), drifting a little sideways, then flies
## at the camera and over it (D-437: was turning away and climbing off).
## D-488: its nose and bank follow the way it is moving against the car.
## Its blades are blurred discs (scripts/tools/gen_rotor_blur.py) spun on the
## hubs. This node is the body's holder; the game places it on the road each
## frame from `s`, `x`, `h`, `yaw`, `pitch` and `roll` (stepped like the other
## models in 8-BIT/16-BIT), and plays the chopper sound from `loudness()`.
extends Node3D

const MODEL := "res://assets/models/racer/heli.glb"
const TEXTURE := "res://assets/models/racer/heli_albedo.png"
const ROTOR_TEX := "res://assets/textures/racer/rotor_blur.png"
## Model space (nose +Z, from renders of the prepared 11 m model).
const MAIN_HUB := Vector3(0.0, 3.66, 1.86)
const MAIN_R := 5.0
const TAIL_HUB := Vector3(0.45, 2.38, -4.65)
const TAIL_R := 0.85
const MAIN_SPIN := 2.6   # turns per second of the blurred disc
const TAIL_SPIN := 4.5

const IN_TIME := 3.0
const HOVER_TIME := 4.5
const OUT_TIME := 2.6
const OUT_PAST := 75.0    # D-437: m it closes in on the car, ending well behind the camera
const OUT_CLIMB := 9.0    # m it rises on the way, passing over the camera
const AHEAD := 16.0       # m ahead of the car while hovering (D-440: was 28)
const HEIGHT := 5.5       # m above the road while hovering (D-440: was 7)
const IN_BEHIND := 24.0   # D-488: m behind the car where it comes from (the camera is 8 m behind)
const IN_HEIGHT := 16.0   # and how high: above the top of the screen until it is ahead
const IN_TURN := 0.5      # of the fly-in: from here it swings round to face the car
const SWING_DEG := 25.0   # the sideways turn while hovering
const DRIFT := 2.0        # m: half its sideways drift while hovering
const DRIFT_RATE := 0.6   # rad/s of that drift

var phase := ""           # "", "in", "hover", "out"
var t := 0.0
## Pose on the road: distance along it and sideways (m), height (m); yaw is
## the turn away from facing the car (radians), pitch nose-down, roll bank.
var s := 0.0
var x := 0.0
var h := 0.0
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
## D-517: extra height, set by the game: it rises over an overpass (or a tunnel
## mouth) in its way and comes back down after it.
var lift := 0.0
var _side := 1.0
var _main: Node3D
var _tail: Node3D


## Adds the body (built by the game, so it uses the cars' shader) and rotors.
func setup(body: Node3D) -> void:
	add_child(body)
	var tex: Texture2D = load(ROTOR_TEX)
	_main = _rotor(tex, MAIN_R)
	_main.position = MAIN_HUB
	add_child(_main)
	_tail = _rotor(tex, TAIL_R)
	_tail.position = TAIL_HUB
	_tail.rotation = Vector3(0.0, 0.0, PI * 0.5)   # the disc stands upright, across the tail
	add_child(_tail)
	visible = false


func _rotor(tex: Texture2D, r: float) -> Node3D:
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(r * 2.0, r * 2.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	q.material = m
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	holder.set_meta("disc", mi)
	return holder


func active() -> bool:
	return phase != ""


## Starts the fly-in; `side` (+1 / -1) is the side it swings round by and drifts to.
func start(side: float) -> void:
	phase = "in"
	t = 0.0
	lift = 0.0
	_side = signf(side) if side != 0.0 else 1.0
	visible = true


## Advances the flight; car_s / car_x: the player's car on the road.
func update(delta: float, car_s: float, car_x: float) -> void:
	if phase == "":
		return
	t += delta
	(_main.get_meta("disc") as Node3D).rotate_y(-TAU * MAIN_SPIN * delta)
	(_tail.get_meta("disc") as Node3D).rotate_y(TAU * TAIL_SPIN * delta)
	var hover_x := car_x * 0.6
	match phase:
		"in":
			# D-488: over the camera from behind, nose first and nose down,
			# overtaking the car; it flares (nose up) as it slows, then swings
			# round by its side to face the car, banking into the turn.
			var k := clampf(t / IN_TIME, 0.0, 1.0)
			var e := 1.0 - (1.0 - k) * (1.0 - k)   # fast in, easing to a stop
			var turn := smoothstep(IN_TURN, 1.0, k)
			s = car_s + lerpf(-IN_BEHIND, AHEAD, e)
			x = hover_x
			h = lerpf(IN_HEIGHT, HEIGHT, smoothstep(0.0, 1.0, e))
			yaw = _side * PI * (1.0 - turn)   # PI = nose ahead, the way it flies; 0 = facing the car
			pitch = deg_to_rad(12.0) * (1.0 - smoothstep(0.0, 0.4, k)) \
				- deg_to_rad(10.0) * sin(PI * clampf((k - 0.3) / 0.45, 0.0, 1.0))
			roll = _side * deg_to_rad(12.0) * sin(PI * turn)
			if k >= 1.0:
				phase = "hover"
				t = 0.0
		"hover":
			s = car_s + AHEAD + 1.5 * sin(t * 0.9)
			# D-488: it drifts out to its side and back; its nose and bank go
			# with its sideways speed (they ran at another rate, so half the
			# time it leaned and turned against its own movement).
			var go := sin(t * DRIFT_RATE)   # its sideways speed, -1..1 (towards its side)
			x = hover_x + _side * DRIFT * (1.0 - cos(t * DRIFT_RATE))
			h = HEIGHT + 0.6 * sin(t * 1.3)
			yaw = _side * deg_to_rad(SWING_DEG) * go     # the nose a little into the drift
			pitch = deg_to_rad(2.0) * sin(t * 0.7)
			roll = -_side * deg_to_rad(6.0) * go         # leaning the way it goes (facing us, its left is our right)
			if t >= HOVER_TIME:
				phase = "out"
				t = 0.0
		"out":
			# D-437: it noses down and flies at the camera, gathering speed,
			# and passes low over it (the camera is 8 m behind the car).
			var k := clampf(t / OUT_TIME, 0.0, 1.0)
			var e := k * k
			s = car_s + AHEAD + 1.5 * sin(HOVER_TIME * 0.9) - OUT_PAST * e
			# D-488: straight at us from where it hovered (no side-step), its
			# nose and bank easing level from the drift.
			var go_end := sin(HOVER_TIME * DRIFT_RATE)
			var level := 1.0 - smoothstep(0.0, 0.4, k)
			x = hover_x + _side * DRIFT * (1.0 - cos(HOVER_TIME * DRIFT_RATE))
			h = HEIGHT + 0.6 * sin(HOVER_TIME * 1.3) + OUT_CLIMB * e
			yaw = _side * deg_to_rad(SWING_DEG) * go_end * level
			pitch = deg_to_rad(18.0) * smoothstep(0.0, 0.35, k)   # nose down, coming at us
			roll = -_side * deg_to_rad(6.0) * go_end * level
			if k >= 1.0:
				phase = ""
				visible = false


## 0..1: how loud the chopper is (fades in as it arrives, out as it goes).
func loudness() -> float:
	match phase:
		"in":
			return clampf(t / 0.6, 0.0, 1.0)   # D-488: it comes over us: loud almost at once
		"hover":
			return 1.0
		"out":   # loudest as it passes over, then gone behind
			var k := clampf(t / OUT_TIME, 0.0, 1.0)
			return 1.0 if k < 0.65 else 1.0 - (k - 0.65) / 0.35
	return 0.0


# --- the chopper sound (D-441) -----------------------------------------------------
## A seamless 2 s loop, made once and kept: blade slaps (a sharp crack of
## band-passed noise over a low thump, 11 a second: two blades at 5.5 turns a
## second, each pass a little different), the rotor's wash (low rumbling noise
## that swells with every pass), the tail rotor's faster buzz and a faint
## turbine whine. Filtered noise, so nothing is harsh; soft-clipped and
## normalised. The noise runs past the loop's end and that tail is blended into
## the start, so the loop joins without a click.
const SND_RATE := 32000
const SND_SECONDS := 2.0
const BLADE_HZ := 11.0       # passes a second (22 in the loop: a whole number)
const TAIL_HZ := 55.0
static var _sound: AudioStreamWAV


static func chopper_sound() -> AudioStreamWAV:
	if _sound != null:
		return _sound
	var n := int(SND_SECONDS * SND_RATE)
	var fade := int(0.05 * SND_RATE)
	var total := n + fade
	var rng := RandomNumberGenerator.new()
	rng.seed = 436
	var out := PackedFloat32Array()
	out.resize(total)
	# One-pole filter coefficients.
	var k_wash := 1.0 - exp(-TAU * 380.0 / SND_RATE)    # wash: low-passed noise
	var k_slap_lo := 1.0 - exp(-TAU * 1700.0 / SND_RATE) # slap: band 250..1700 Hz
	var k_slap_hi := 1.0 - exp(-TAU * 250.0 / SND_RATE)
	var k_tail_lo := 1.0 - exp(-TAU * 3200.0 / SND_RATE) # tail: band 900..3200 Hz
	var k_tail_hi := 1.0 - exp(-TAU * 900.0 / SND_RATE)
	var k_mix := 1.0 - exp(-TAU * 2400.0 / SND_RATE)    # the whole mix, low-passed twice
	var m1 := 0.0
	var m2 := 0.0
	var wash := 0.0
	var s_lo := 0.0
	var s_hi := 0.0
	var t_lo := 0.0
	var t_hi := 0.0
	var gains := PackedFloat32Array()   # each blade pass a little different
	for i in int(BLADE_HZ * SND_SECONDS) + 2:
		gains.append(rng.randf_range(0.8, 1.0))
	var peak := 0.0
	for i in total:
		var t := float(i) / SND_RATE
		var tl := fmod(t, SND_SECONDS)   # the loop's own time (the tail repeats the start)
		var pass_f := tl * BLADE_HZ
		var pass_i := int(pass_f)
		var ph := pass_f - float(pass_i)          # 0..1 through one blade pass
		var since := ph / BLADE_HZ                # seconds since the slap
		var g := gains[pass_i % gains.size()]
		var env := (1.0 - exp(-since / 0.0025)) * exp(-since / 0.045) * g
		var noise := rng.randf_range(-1.0, 1.0)
		s_lo += (noise - s_lo) * k_slap_lo
		s_hi += (s_lo - s_hi) * k_slap_hi
		var slap := (s_lo - s_hi) * 2.6 * env
		var thump := sin(TAU * (62.0 - 18.0 * minf(since / 0.06, 1.0)) * since) * exp(-since / 0.05) * g * 0.6
		wash += (rng.randf_range(-1.0, 1.0) - wash) * k_wash
		var swell := 0.6 + 0.4 * exp(-ph * 3.0)
		var wash_s := wash * 2.2 * swell
		var tph := fmod(tl * TAIL_HZ, 1.0)
		t_lo += (rng.randf_range(-1.0, 1.0) - t_lo) * k_tail_lo
		t_hi += (t_lo - t_hi) * k_tail_hi
		var tail := (t_lo - t_hi) * 0.35 * (0.35 + 0.65 * exp(-tph * 6.0))
		var whine := (sin(TAU * 5800.0 * tl + 0.8 * sin(TAU * 3.0 * tl)) * 0.008 + sin(TAU * 7350.0 * tl) * 0.004)
		m1 += (slap + thump + wash_s + tail - m1) * k_mix
		m2 += (m1 - m2) * k_mix
		var v := m2 + whine   # the whine stays above the filter, faint
		out[i] = v
		peak = maxf(peak, absf(v))
	# Blend the noise's run-on into the start, so the loop joins smoothly.
	for i in fade:
		var w := float(i) / fade
		out[i] = out[i] * w + out[n + i] * (1.0 - w)
	var data := PackedByteArray()
	data.resize(n * 2)
	var norm := 1.0 / maxf(peak, 0.001)
	for i in n:
		var v := out[i] * norm
		v = v / (1.0 + 0.35 * absf(v)) * 1.35   # gentle soft clip
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SND_RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	_sound = wav
	return wav


# --- night lights (D-442) ----------------------------------------------------------
## At night: position lights (red on its left, green on its right, white on
## the tail), a red beacon on the roof that flashes once a second, and a
## searchlight under the nose that follows the player's car, with a visible
## beam. Model space, from renders of the prepared model (nose +Z, left +X).
const LIGHT_LEFT := Vector3(1.39, 2.24, -3.0)    # stabiliser tip, red
const LIGHT_RIGHT := Vector3(-1.39, 2.24, -3.0)  # green
const LIGHT_TAIL := Vector3(0.0, 2.2, -5.45)     # white
const BEACON := Vector3(0.0, 3.2, 1.1)
const SEARCH := Vector3(0.0, 0.42, 3.9)   # below the camera pod, so the lamp shows
const SEARCH_ANGLE := 9.0       # degrees, half the beam
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
void fragment() {
	// Bright down the middle of the beam, fading at its edges and far end.
	float edge = abs(dot(NORMAL, VIEW));
	ALBEDO = vec3(1.0, 0.95, 0.82) * strength * edge * edge * mix(0.15, 1.0, UV.y);
}
"""
var _lights: Node3D
var _beacon: MeshInstance3D
var _spot: SpotLight3D
var _beam: Node3D
var _beam_mat: ShaderMaterial
var _night_k := 0.0


func _build_lights() -> void:
	_lights = Node3D.new()
	_lights.visible = false
	add_child(_lights)
	for pair in [[LIGHT_LEFT, Color(1.0, 0.08, 0.05)], [LIGHT_RIGHT, Color(0.1, 1.0, 0.25)], [LIGHT_TAIL, Color(1.0, 1.0, 0.95)]]:
		_lights.add_child(_lamp(pair[0], pair[1], 0.13))
	_beacon = _lamp(BEACON, Color(1.0, 0.05, 0.03), 0.16)
	_lights.add_child(_beacon)
	_lights.add_child(_lamp(SEARCH, Color(1.0, 0.97, 0.85), 0.2))
	_spot = SpotLight3D.new()
	_spot.position = SEARCH
	_spot.light_color = Color(1.0, 0.96, 0.85)
	_spot.light_energy = 12.0
	_spot.spot_range = 70.0
	_spot.spot_angle = SEARCH_ANGLE
	_spot.spot_attenuation = 0.6
	_spot.shadow_enabled = false
	_lights.add_child(_spot)
	_beam = Node3D.new()
	_beam.position = SEARCH
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.height = 1.0
	cm.bottom_radius = 0.01                                 # at the lamp
	cm.top_radius = tan(deg_to_rad(SEARCH_ANGLE))           # one unit away
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	_beam_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BEAM_SHADER
	_beam_mat.shader = sh
	cm.material = _beam_mat
	cone.mesh = cm
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # its +Y (wide end) along -Z
	cone.position = Vector3(0.0, 0.0, -0.5)
	_beam.add_child(cone)
	_lights.add_child(_beam)


func _lamp(pos: Vector3, c: Color, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * 3.0   # HDR: the environment's glow picks it up
	sm.material = m
	mi.mesh = sm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Each frame while out: `night` 0..1 switches the lights on as it gets dark;
## the searchlight and its beam aim at `target` (the player's car, world space).
func night_lights(night: float, target: Vector3) -> void:
	if _lights == null:
		_build_lights()
	_night_k = clampf((night - 0.3) / 0.4, 0.0, 1.0)
	_lights.visible = _night_k > 0.0 and active()
	if not _lights.visible:
		return
	_beacon.visible = fmod(t + 0.3, 1.0) < 0.12
	var from := to_global(SEARCH)
	var to := target - from
	var dist := to.length()
	if dist < 1.0:
		return
	var up := Vector3.UP if absf(to.normalized().y) < 0.95 else Vector3.FORWARD
	_spot.global_transform = Transform3D(Basis.looking_at(to, up), from)
	_spot.light_energy = 12.0 * _night_k
	_spot.spot_range = dist + 15.0
	var bl := dist + 4.0   # the beam reaches just past the car
	_beam.global_transform = Transform3D(Basis.looking_at(to, up).scaled(Vector3.ONE * bl), from)
	_beam_mat.set_shader_parameter("strength", 0.35 * _night_k)
