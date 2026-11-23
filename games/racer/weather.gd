## TURBO RUN weather (D-217): rain streaks and snowflakes around the camera
## (CPU particles in world space, so the car drives through them), and a rain
## hiss. The game drives it each frame with the track's weather weights; sky,
## fog, light and the road's wetness/puddles are set by the game.
extends Node3D

const RAIN_AMOUNT := 1400
const SNOW_AMOUNT := 2200

var _rain: CPUParticles3D
var _snow: CPUParticles3D
var _hiss: AudioStreamPlayer
var rain := 0.0
var snow := 0.0


func _init() -> void:
	name = "Weather"


func build(hiss_stream: AudioStream) -> void:
	_rain = CPUParticles3D.new()
	_rain.amount = RAIN_AMOUNT
	_rain.lifetime = 0.7
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(22.0, 9.0, 30.0)
	_rain.direction = Vector3(0.0, -1.0, 0.0)
	_rain.spread = 4.0
	_rain.gravity = Vector3.ZERO
	_rain.initial_velocity_min = 26.0
	_rain.initial_velocity_max = 32.0
	_rain.particle_flag_align_y = true
	_rain.mesh = _streak_mesh(0.025, 0.9, Color(0.78, 0.84, 0.95, 0.42))
	_rain.emitting = false
	add_child(_rain)
	_snow = CPUParticles3D.new()
	_snow.amount = SNOW_AMOUNT
	_snow.lifetime = 3.2
	_snow.local_coords = false
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(20.0, 8.0, 30.0)
	_snow.direction = Vector3(0.3, -1.0, 0.0)
	_snow.spread = 25.0
	_snow.gravity = Vector3(0.0, -1.0, 0.0)
	_snow.initial_velocity_min = 2.0
	_snow.initial_velocity_max = 4.0
	_snow.mesh = _flake_mesh()
	_snow.emitting = false
	add_child(_snow)
	_hiss = AudioStreamPlayer.new()
	_hiss.bus = "SFX"
	_hiss.stream = hiss_stream
	_hiss.volume_db = -80.0
	add_child(_hiss)


## Each frame: weights (0..1), where to centre the particles (just ahead of
## the camera), and whether we're in a tunnel (nothing falls in there).
func update(rain_w: float, snow_w: float, at: Vector3, sheltered: bool) -> void:
	rain = rain_w
	snow = snow_w
	global_position = at
	_rain.emitting = rain_w > 0.05 and not sheltered
	_snow.emitting = snow_w > 0.05 and not sheltered
	# Fewer drops while it sets in (amount can't change without a restart, so
	# the drops fade with their colour instead).
	(_rain.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = 0.42 * clampf(rain_w * 1.3, 0.0, 1.0)
	(_snow.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = 0.9 * clampf(snow_w * 1.3, 0.0, 1.0)
	var target := -80.0 if rain_w <= 0.01 else linear_to_db(rain_w) - 12.0 - (10.0 if sheltered else 0.0)
	_hiss.volume_db = lerpf(_hiss.volume_db, target, 0.08)
	if rain_w > 0.01 and not _hiss.playing:
		_hiss.play()
	elif rain_w <= 0.01 and _hiss.playing and _hiss.volume_db < -60.0:
		_hiss.stop()


## A thin crossed pair of quads (an X seen from above), so a streak reads from
## any side; Y is its length (CPU particles align Y with their velocity).
func _streak_mesh(w: float, h: float, col: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		var a: Vector3 = axis * w
		var up := Vector3(0, h * 0.5, 0)
		var v := [-a - up, a - up, a + up, -a + up]
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(v[i])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	st.set_material(m)
	return st.commit()


func _flake_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.17, 0.17)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1, 1, 1, 0.9)
	q.material = m
	return q
