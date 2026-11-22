## Audio autoload: buses (Music, SFX, Callouts), volumes from the operator settings,
## a small SFX player pool, and built-in synthesized UI sounds (no asset files).
## Music is always OGG (D-023).
extends Node

const Synth = preload("res://core/util/synth.gd")
const BUSES := ["Music", "SFX", "Callouts"]
const POOL := 8

## Built-in UI sounds, 16-bit style (D-050): name -> synth spec (core/util/synth.gd).
const ECHO := [0.09, 0.32, 0.6]
const UI_SOUNDS := {
	"move": {"voices": [[{"f": [1320.0, 1320.0], "t": 0.035, "w": "pulse12", "v": 0.2}]],
		"echo": [0.06, 0.25, 0.5]},
	"select": {"voices": [[{"f": [880.0, 880.0], "t": 0.14, "w": "pulse25", "v": 0.22, "arp": [0, 7, 12], "arp_rate": 28.0}]],
		"echo": ECHO},
	"back": {"voices": [[{"f": [880.0, 440.0], "t": 0.12, "w": "pulse25", "v": 0.22}]], "echo": [0.07, 0.25, 0.5]},
	"coin": {"voices": [[{"f": [988.0, 988.0], "t": 0.07, "w": "square", "v": 0.22, "env": "hold"},
		{"f": [1319.0, 1319.0], "t": 0.45, "w": "square", "v": 0.22}]], "echo": ECHO},
	"error": {"voices": [[{"f": [140.0, 120.0], "t": 0.28, "w": "saw", "v": 0.3, "vib": [18.0, 0.6], "lp": 0.3, "env": "lin"}]]},
	"start": {"voices": [
		[{"f": [523.0, 523.0], "t": 0.07, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [659.0, 659.0], "t": 0.07, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [784.0, 784.0], "t": 0.07, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1047.0, 1047.0], "t": 0.4, "w": "pulse25", "v": 0.22, "vib": [6.0, 0.25]}],
		[{"f": [131.0, 131.0], "t": 0.21, "w": "triangle", "v": 0.35, "env": "hold"},
		 {"f": [262.0, 262.0], "t": 0.4, "w": "triangle", "v": 0.35}]], "echo": ECHO},
	"letter": {"voices": [[{"f": [1568.0, 1568.0], "t": 0.035, "w": "triangle", "v": 0.35}]]},
	"fanfare": {"voices": [
		[{"f": [784.0, 784.0], "t": 0.1, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [784.0, 784.0], "t": 0.1, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1047.0, 1047.0], "t": 0.12, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1319.0, 1319.0], "t": 0.6, "w": "pulse25", "v": 0.22, "vib": [6.0, 0.3]}],
		[{"f": [196.0, 196.0], "t": 0.2, "w": "triangle", "v": 0.35, "env": "hold"},
		 {"f": [262.0, 262.0], "t": 0.72, "w": "triangle", "v": 0.35}]], "echo": ECHO},
}

## Shared music (D-033). Game-specific tracks live in each game module.
const MUSIC_MAIN := "res://assets/audio/music/main/legends.ogg"

var _music: AudioStreamPlayer
var _music_path := ""
var _music_tween: Tween
var _pool: Array[AudioStreamPlayer] = []
var _sounds := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	apply_volumes()
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for sound_name in UI_SOUNDS:
		_sounds[sound_name] = Synth.make(UI_SOUNDS[sound_name])


## Re-reads operator volumes (0..10) into the buses.
func apply_volumes() -> void:
	var map := {"Master": "volume_master", "Music": "volume_music", "SFX": "volume_sfx", "Callouts": "volume_sfx"}
	for bus in map:
		var idx := AudioServer.get_bus_index(bus)
		if idx == -1:
			continue
		var v := clampi(int(Config.get_value("operator", map[bus])), 0, 10)
		AudioServer.set_bus_mute(idx, v == 0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.01) / 10.0))


func register_sfx(sound_name: String, stream: AudioStream) -> void:
	_sounds[sound_name] = stream


## Plays a sound effect. Returns its player, so a long sound can be cut short
## with stop_sfx() (e.g. a charge-up that is released early).
func sfx(sound_name: String) -> AudioStreamPlayer:
	var t0 := Time.get_ticks_usec()
	var p := _sfx(sound_name)
	var us := Time.get_ticks_usec() - t0
	if us > 8000:
		DebugTools.mark("slow sfx '%s' %d ms" % [sound_name, us / 1000])
	return p


func _sfx(sound_name: String) -> AudioStreamPlayer:
	var stream: AudioStream = _sounds.get(sound_name)
	if stream == null:
		push_warning("Audio: unknown sfx '%s'" % sound_name)
		return null
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return p
	_pool[0].stream = stream
	_pool[0].play()
	return _pool[0]


## Stops a sound started by sfx(), if it is still that sound playing.
func stop_sfx(player: AudioStreamPlayer, sound_name: String = "") -> void:
	if player == null or not player.playing:
		return
	if not sound_name.is_empty() and player.stream != _sounds.get(sound_name):
		return  # the player was reused for another sound meanwhile
	player.stop()


## Plays a looping music track (res:// path to an .ogg), fading out whatever is
## playing. Calling it again with the same path keeps the track going.
func play_music(path: String, fade: float = 1.0) -> void:
	if path == _music_path and _music.playing:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Audio: cannot load music '%s'" % path)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_path = path
	_fade_to(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play()
		_tween_volume(0.0, fade), fade)


func stop_music(fade: float = 1.0) -> void:
	_music_path = ""
	_fade_to(func(): _music.stop(), fade)


func current_music() -> String:
	return _music_path


func _fade_to(then: Callable, fade: float) -> void:
	if _music_tween:
		_music_tween.kill()
	if not _music.playing or fade <= 0.0:
		then.call()
		return
	_music_tween = _tween_volume(-40.0, fade * 0.5)
	_music_tween.finished.connect(then)


func _tween_volume(db: float, seconds: float) -> Tween:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", db, maxf(seconds, 0.01))
	return _music_tween
