## Turbo Run contact effects (D-510): what flies off when two vehicles touch.
##  - sparks: thin white-hot streaks from the contact point, riding along with
##    the car and trailing back from it (shaders/spark.gdshader);
##  - shards: a few flat pieces of bodywork showing the car's own texture and
##    paint, thrown low, which bounce once on the road, skid and are left behind;
##  - smoke: a light wisp from a scrape, a dark puff and a trail from a crash.
## One per view, a child of the view's world root. Positions are kept in track
## coordinates (s along the road, x across it, h above it).
extends Node3D

const SPARK_SHADER := preload("res://games/racer/shaders/spark.gdshader")
const SHARD_SHADER := preload("res://games/racer/shaders/shard.gdshader")

const SPARKS := 100              # per contact (a crash: SPARKS_BIG)
const SPARKS_BIG := 150
const SHARDS := 6                # per vehicle in a bump or ram (a crash: SHARDS_BIG)
const SHARDS_BIG := 13
const SHARDS_MAX := 80           # alive at once, in one view
const SHARD_R := Vector2(0.06, 0.13)    # m, a piece's radius (a crash: up to 1.3x; D-511: doubled, they were too small to see)
const SHARD_LIFE := 5.0          # s
const SHARD_BEHIND := 14.0       # m behind the view's car: gone
const GRAVITY := 15.0            # m/s2
const BOUNCE := 0.42             # upward speed kept on the first bounces
const BOUNCE_MIN := 1.2          # m/s: slower than this, it stays down
const ROAD_GRIP := 9.0           # m/s2 a piece on the road loses along it (D-511: was 30, gone in a blink)
const GROUND := 0.02             # m: a piece lying on the road
const CELLS := 48                # the texture is searched on a CELLS x CELLS grid
const HUE_STEP := 0.02           # shard materials are shared between paints this close

var game: Node                   # the view: its `sim` and `_role`
var _shards: Array = []          # each: {node, s, x, h, vs, vx, vh, axis, ang, spin, yaw, life, down}
var _followers: Array = []       # emitters that move with a car: {node, who, s, x, h, v, stop, t}
var _rng := RandomNumberGenerator.new()

static var _cells := {}          # texture path -> UV centres of its paintwork
static var _shard_mats := {}
static var _spark_mat: ShaderMaterial
static var _spark_mesh: QuadMesh


# --- the car's texture ------------------------------------------------------------------
## Where a texture's paintwork is: the UV centres of the grid cells with a
## strong colour (how the car shader tells paint from glass, tyres and chrome,
## D-312). A texture with hardly any (a grey truck) gives its lit cells; one
## in `two_tone` (the police car) its white and its black cells, half each.
static func paint_cells(path: String, two_tone: bool = false) -> PackedVector2Array:
	if _cells.has(path):
		return _cells[path]
	var paint := PackedVector2Array()
	var lit := PackedVector2Array()
	var white := PackedVector2Array()
	var black := PackedVector2Array()
	var tex := load(path) as Texture2D
	if tex != null:
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		for cy in CELLS:
			for cx in CELLS:
				var uv := Vector2((cx + 0.5) / CELLS, (cy + 0.5) / CELLS)
				var c := img.get_pixel(int(uv.x * img.get_width()), int(uv.y * img.get_height()))
				if c.a < 0.5:
					continue
				if c.s > 0.4 and c.v > 0.3:
					paint.append(uv)
				if c.v > 0.25:
					lit.append(uv)
				if c.s < 0.2 and c.v > 0.75:
					white.append(uv)
				elif c.v < 0.15:
					black.append(uv)
	var out := paint
	if two_tone and not white.is_empty() and not black.is_empty():
		out = PackedVector2Array()
		for i in mini(white.size(), black.size()):
			out.append(white[i * white.size() / mini(white.size(), black.size())])
			out.append(black[i * black.size() / mini(white.size(), black.size())])
	elif paint.size() * 12 < CELLS * CELLS:
		out = lit
	if out.is_empty():
		out = PackedVector2Array([Vector2(0.5, 0.5)])
	_cells[path] = out
	return out


static func shard_material(path: String, hue: float) -> ShaderMaterial:
	var key := "%s:%d" % [path, roundi(hue / HUE_STEP)]
	if not _shard_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHARD_SHADER
		m.set_shader_parameter("tex", load(path))
		m.set_shader_parameter("hue", hue)
		_shard_mats[key] = m
	return _shard_mats[key]


static func spark_material() -> ShaderMaterial:
	if _spark_mat == null:
		_spark_mat = ShaderMaterial.new()
		_spark_mat.shader = SPARK_SHADER
	return _spark_mat


# --- shards -----------------------------------------------------------------------------
## One step of a shard's flight (pure, so the tests can run it): it falls,
## bounces while it still has the speed to, then lies on the road and skids
## to a stop.
static func step_shard(d: Dictionary, dt: float) -> void:
	d.life = float(d.life) + dt
	if d.down:
		d.vs = move_toward(float(d.vs), 0.0, ROAD_GRIP * dt)
		d.vx = move_toward(float(d.vx), 0.0, ROAD_GRIP * 0.4 * dt)
	else:
		d.vh = float(d.vh) - GRAVITY * dt
		d.vs = float(d.vs) * (1.0 - 0.15 * dt)
		d.ang = float(d.ang) + float(d.spin) * dt
	d.s = float(d.s) + float(d.vs) * dt
	d.x = float(d.x) + float(d.vx) * dt
	d.h = float(d.h) + float(d.vh) * dt
	if not d.down and float(d.h) <= GROUND:
		d.h = GROUND
		if float(d.vh) < -BOUNCE_MIN:
			d.vh = -float(d.vh) * BOUNCE
			d.vs = float(d.vs) * 0.93
			d.vx = float(d.vx) * 0.6
			d.spin = float(d.spin) * 0.6
		else:
			d.vh = 0.0
			d.down = true


## A flat, irregular piece (3 to 5 corners) showing the texture around `uv`.
func _shard_mesh(radius: float, uv: Vector2) -> ArrayMesh:
	var n := _rng.randi_range(3, 5)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var ring: Array = []
	var a0 := _rng.randf() * TAU
	for i in n:
		var a := a0 + (i + _rng.randf_range(-0.3, 0.3)) * TAU / n
		ring.append(Vector2(cos(a), sin(a)) * _rng.randf_range(0.45, 1.0))
	var patch := 0.6 / CELLS   # the patch stays about inside its cell
	for i in n:
		for p in [Vector2.ZERO, ring[i], ring[(i + 1) % n]]:
			verts.append(Vector3(p.x, p.y, 0.0) * radius)
			uvs.append(uv + p * patch)
			normals.append(Vector3(0.0, 0.0, 1.0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = normals
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## Pieces of one vehicle (its texture `path` and paint `hue`), thrown from
## (s, x) low and to `side` (+1 = the road's right, its own side).
func shards(s: float, x: float, path: String, hue: float, side: float, car_v: float, big: bool, two_tone: bool = false) -> void:
	var cells := paint_cells(path, two_tone)
	var mat := shard_material(path, hue)
	var k := 1.5 if big else 1.0
	for i in (SHARDS_BIG if big else SHARDS):
		var node := MeshInstance3D.new()
		node.mesh = _shard_mesh(_rng.randf_range(SHARD_R.x, SHARD_R.y * (1.3 if big else 1.0)), cells[_rng.randi() % cells.size()])
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.top_level = true
		add_child(node)
		# D-511: they leave at nearly the car's speed, so they stay in view
		# beside and behind it, and spread both ways across the road (thrown
		# only to their vehicle's own side they went under it, unseen).
		var d := {"node": node, "s": s + _rng.randf_range(-0.6, 0.6), "x": x, "h": _rng.randf_range(0.3, 0.7),
			"vs": car_v * _rng.randf_range(0.88, 0.99), "vx": side * _rng.randf_range(0.0, 1.2) * k + _rng.randf_range(-2.4, 2.4) * k,
			"vh": _rng.randf_range(1.6, 3.6) * k,
			"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(),
			"ang": _rng.randf() * TAU, "spin": _rng.randf_range(8.0, 26.0), "yaw": _rng.randf() * TAU, "life": 0.0, "down": false}
		if (d.axis as Vector3).length_squared() < 0.01:
			d.axis = Vector3.UP
		_shards.append(d)
		_place(d)
	while _shards.size() > SHARDS_MAX:
		var old: Dictionary = _shards.pop_front()
		(old.node as Node).queue_free()


func _place(d: Dictionary) -> void:
	var node: MeshInstance3D = d.node
	var basis_ := Basis(Vector3.UP, float(d.yaw)) * Basis(Vector3.RIGHT, -PI * 0.5) if d.down \
		else Basis(d.axis as Vector3, float(d.ang))
	node.global_transform = Transform3D(basis_, game.sim.track.point(float(d.s), float(d.x), float(d.h)))


# --- sparks -----------------------------------------------------------------------------
## Sparks from the point (s, x) on player `who`'s car (-1: on nobody, moving
## at car_v): they stream for a moment, back from the contact and down.
func sparks(who: int, s: float, x: float, car_v: float, big: bool) -> void:
	var em := CPUParticles3D.new()   # (GPU particles don't move in our TABLE viewports)
	em.one_shot = true
	em.explosiveness = 0.8           # D-511: nearly all at the moment of the hit (spread over their whole life they felt late)
	em.amount = SPARKS_BIG if big else SPARKS
	em.lifetime = 0.42
	em.lifetime_randomness = 0.55
	em.local_coords = true           # they ride along with the car (D-303)
	em.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	var tr_ = game.sim.track
	var fwd: Vector3 = (tr_.point(s + 1.0, 0.0, 0.0) - tr_.point(s, 0.0, 0.0)).normalized()
	# Back from the contact in a cone, tipped up a little: the camera looks
	# along the road, so it is the spread that shows the streaks' length.
	em.direction = (-fwd + Vector3.UP * 0.22).normalized()
	em.spread = 26.0
	em.initial_velocity_min = maxf(car_v * 0.04, 2.0)
	em.initial_velocity_max = maxf(car_v * 0.22, 6.0)   # D-511: was half the car's speed: they shot metres up into the sky
	em.damping_min = 3.0
	em.damping_max = 9.0
	em.gravity = Vector3(0.0, -14.0, 0.0)
	em.scale_amount_min = 0.35
	em.scale_amount_max = 1.5
	# D-513: light golden yellow, cooling through gold and orange to red.
	var heat := Gradient.new()
	heat.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
	heat.colors = PackedColorArray([Color(1.0, 0.95, 0.65), Color(1.0, 0.86, 0.42), Color(1.0, 0.6, 0.15), Color(1.0, 0.3, 0.05, 0.85), Color(0.55, 0.06, 0.0, 0.0)])
	em.color_ramp = heat
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(1.0, 1.0)   # the shader gives it its width and length
		_spark_mesh.material = spark_material()
	em.mesh = _spark_mesh
	_follow(em, who, s, x, 0.45, car_v, em.lifetime, em.lifetime + 0.5)
	em.restart()


# --- smoke ------------------------------------------------------------------------------
## All smoke and dust is our own pooled puffs in one MultiMesh (D-511), as the
## tyre smoke is (D-100): a CPUParticles3D emitter draws a stray black puff at
## its origin, the "black circle" on a smoking car (D-464, D-474, D-486).
const PUFFS_MAX := 256
var _puffs: MultiMesh
var _puff_list: Array = []       # each: {pos, vel, age, life, size, grow, col, rise, damp}
var _rates := {}                 # steady sources: key -> the time owed


func _build_puffs() -> void:
	_puffs = MultiMesh.new()
	_puffs.transform_format = MultiMesh.TRANSFORM_3D
	_puffs.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.billboard_keep_scale = true
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sm.albedo_texture = game._smoke_texture()   # soft (D-474)
	q.material = sm
	_puffs.mesh = q
	_puffs.instance_count = PUFFS_MAX
	_puffs.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _puffs
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	mmi.top_level = true
	add_child(mmi)


## One puff at `pos` (world), moving at `vel`: `size` m across times `grow`
## (from, to) over its `life`; it fades in over its first fifth, then out.
func puff(pos: Vector3, vel: Vector3, col: Color, size: float, grow: Vector2, life: float, rise: float = 0.7, damp: float = 2.0) -> void:
	if _puff_list.size() >= PUFFS_MAX:
		_puff_list.pop_front()
	_puff_list.append({"pos": pos, "vel": vel, "age": 0.0, "life": life, "size": size, "grow": grow, "col": col, "rise": rise, "damp": damp})


## How many puffs a steady source (`key`) owes this frame at `rate` a second.
func owed(key: String, rate: float, dt: float) -> int:
	var t: float = float(_rates.get(key, 0.0)) + dt * rate
	var n := int(t)
	_rates[key] = t - n
	return mini(n, 8)


func _jitter(k: float) -> Vector3:
	return Vector3(_rng.randf_range(-k, k), _rng.randf_range(-k, k), _rng.randf_range(-k, k))


func _forward(s: float) -> Vector3:
	var tr_ = game.sim.track
	return (tr_.point(s + 1.0, 0.0, 0.0) - tr_.point(s, 0.0, 0.0)).normalized()


## Road dust where two vehicles touch (D-292).
func dust(s: float, x: float, car_v: float, big: bool) -> void:
	var k := 1.6 if big else 1.0
	var at: Vector3 = game.sim.track.point(s, x, 0.3)
	var fwd := _forward(s) * car_v * 0.6
	for i in int(8 * k):
		puff(at + _jitter(0.3), fwd + Vector3(_rng.randf_range(-2, 2), _rng.randf_range(0.5, 3.0), _rng.randf_range(-2, 2)) * k,
			Color(0.72, 0.66, 0.58, 0.36), 0.7 * _rng.randf_range(0.5, 1.0) * k, Vector2(0.5, 1.4), 1.1, 0.6, 2.5)


## A scrape: a thin light wisp trailing from the contact for a moment.
func scrape_smoke(who: int, s: float, x: float, car_v: float) -> void:
	_follow(null, who, s, x, 0.35, car_v, 0.35, 0.35, {"rate": 24.0, "col": Color(0.86, 0.86, 0.9, 0.2), "size": 0.6, "grow": Vector2(0.6, 1.5), "life": 0.9, "keep": 0.8})


## A crash: a grey puff where it happened, and smoke trailing from the car.
func crash_smoke(who: int, s: float, x: float, car_v: float) -> void:
	var at: Vector3 = game.sim.track.point(s, x, 0.6)
	var fwd := _forward(s) * car_v * 0.5
	for i in 10:
		puff(at + _jitter(0.4), fwd + Vector3(_rng.randf_range(-2.5, 2.5), _rng.randf_range(1.0, 4.0), _rng.randf_range(-2.5, 2.5)),
			Color(0.5, 0.5, 0.53, 0.3), _rng.randf_range(0.8, 1.2), Vector2(0.9, 2.4), 1.6)
	_follow(null, who, s, x, 0.7, car_v, 1.8, 1.8, {"rate": 12.0, "col": Color(0.62, 0.62, 0.65, 0.22), "size": 0.8, "grow": Vector2(0.8, 2.0), "life": 1.2, "keep": 0.7})


## A damaged car's smoke (D-464): `n` puffs from `at` (world), thrown forward
## at a little under its speed `v` so they trail a short way behind it.
func car_smoke(at: Vector3, s: float, v: float, col: Color, n: int) -> void:
	var fwd := _forward(s)
	for i in n:
		puff(at + _jitter(0.3), fwd * v * _rng.randf_range(0.86, 0.9) + Vector3(0.0, v * 0.07, 0.0) + _jitter(0.4),
			col, _rng.randf_range(0.7, 1.1), Vector2(0.5, 2.6), 1.0, 1.8, 0.0)


## Something that keeps its place on player `who`'s car (or, who < 0, moves
## along the road at v) for `t` s: a spark emitter `em`, or (em = null) a
## smoke source that puffs for `stop` s as `smoke` says.
func _follow(em: CPUParticles3D, who: int, s: float, x: float, h: float, v: float, stop: float, t: float, smoke: Dictionary = {}) -> void:
	if em != null:
		em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		em.top_level = true
		add_child(em)
	var f := {"node": em, "who": who, "s": s, "x": x, "h": h, "v": v, "stop": stop, "t": t, "smoke": smoke, "owed": 0.0}
	if who >= 0:   # kept as an offset from that car
		f.s = s - float(game.sim.player_get(who, "s"))
		f.x = x - float(game.sim.player_get(who, "x"))
	_followers.append(f)
	_place_follower(f)


## Where a follower is now: [its s, its place in the world].
func _follower_at(f: Dictionary) -> Array:
	var s := float(f.s)
	var x := float(f.x)
	if int(f.who) >= 0:
		s += float(game.sim.player_get(int(f.who), "s"))
		x += float(game.sim.player_get(int(f.who), "x"))
	return [s, game.sim.track.point(s, x, float(f.h))]


func _place_follower(f: Dictionary) -> void:
	if f.node != null:
		(f.node as Node3D).global_transform = Transform3D(Basis.IDENTITY, _follower_at(f)[1])


func clear() -> void:
	for d in _shards:
		(d.node as Node).queue_free()
	for f in _followers:
		if f.node != null:
			(f.node as Node).queue_free()
	_shards.clear()
	_followers.clear()
	_puff_list.clear()
	_rates.clear()


func _process(dt: float) -> void:
	if game == null or game.sim == null:
		return
	var view_s := float(game.sim.player_get(int(game._role), "s"))
	var i := 0
	while i < _shards.size():
		var d: Dictionary = _shards[i]
		step_shard(d, dt)
		if float(d.life) > SHARD_LIFE or float(d.s) < view_s - SHARD_BEHIND:
			(d.node as Node).queue_free()
			_shards.remove_at(i)
			continue
		_place(d)
		i += 1
	i = 0
	while i < _followers.size():
		var f: Dictionary = _followers[i]
		f.t = float(f.t) - dt
		f.stop = float(f.stop) - dt
		if float(f.t) <= 0.0:
			if f.node != null:
				(f.node as Node).queue_free()
			_followers.remove_at(i)
			continue
		if int(f.who) < 0:
			f.s = float(f.s) + float(f.v) * dt
		_place_follower(f)
		var sm: Dictionary = f.smoke
		if not sm.is_empty() and float(f.stop) > 0.0:
			f.owed = float(f.owed) + dt * float(sm.rate)
			var at: Array = _follower_at(f)
			var v := float(game.sim.player_get(int(f.who), "v")) if int(f.who) >= 0 else float(f.v)
			var fwd := _forward(float(at[0])) * v * float(sm.keep)
			while float(f.owed) >= 1.0:
				f.owed = float(f.owed) - 1.0
				puff((at[1] as Vector3) + _jitter(0.25), fwd + Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(0.3, 1.4), _rng.randf_range(-0.8, 0.8)),
					sm.col, float(sm.size) * _rng.randf_range(0.8, 1.2), sm.grow, float(sm.life))
		i += 1
	_step_puffs(dt)


func _step_puffs(dt: float) -> void:
	if _puffs == null:
		if _puff_list.is_empty():
			return
		_build_puffs()
	for j in range(_puff_list.size() - 1, -1, -1):
		var p: Dictionary = _puff_list[j]
		p.age = float(p.age) + dt
		if float(p.age) >= float(p.life):
			_puff_list.remove_at(j)
			continue
		var vel: Vector3 = p.vel
		vel *= maxf(0.0, 1.0 - float(p.damp) * dt)
		vel.y += float(p.rise) * dt
		p.vel = vel
		p.pos = (p.pos as Vector3) + vel * dt
	_puffs.visible_instance_count = _puff_list.size()
	for j in _puff_list.size():
		var p: Dictionary = _puff_list[j]
		var k: float = float(p.age) / float(p.life)
		var g: Vector2 = p.grow
		_puffs.set_instance_transform(j, Transform3D(Basis.from_scale(Vector3.ONE * float(p.size) * lerpf(g.x, g.y, k)), p.pos))
		var c: Color = p.col
		_puffs.set_instance_color(j, Color(c.r, c.g, c.b, c.a * minf(k / 0.2, 1.0) * (1.0 - k)))
