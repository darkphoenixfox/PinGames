## Audio autoload: buses (Music, SFX, Callouts), volumes from the operator settings,
## a small SFX player pool, and built-in synthesized UI sounds (no asset files).
## Music is always OGG (D-023).
extends Node

const Synth = preload("res://core/util/synth.gd")
const BUSES := ["Music", "SFX", "Callouts"]
const POOL := 8

## Built-in UI sounds: name -> synth segments (see core/util/synth.gd).
const UI_SOUNDS := {
	"move": [[880.0, 880.0, 0.035, "square", 0.18]],
	"select": [[660.0, 660.0, 0.05], [990.0, 990.0, 0.09]],
	"back": [[660.0, 440.0, 0.1]],
	"coin": [[988.0, 988.0, 0.07], [1319.0, 1319.0, 0.3]],
	"error": [[160.0, 120.0, 0.25, "square", 0.3]],
	"start": [[523.0, 523.0, 0.07], [659.0, 659.0, 0.07], [784.0, 784.0, 0.07], [1047.0, 1047.0, 0.2]],
	"letter": [[1200.0, 1200.0, 0.03, "triangle", 0.3]],
	"fanfare": [[784.0, 784.0, 0.1], [784.0, 784.0, 0.1], [1047.0, 1047.0, 0.12], [1319.0, 1319.0, 0.35]],
}

var _music: AudioStreamPlayer
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


func sfx(sound_name: String) -> void:
	var stream: AudioStream = _sounds.get(sound_name)
	if stream == null:
		push_warning("Audio: unknown sfx '%s'" % sound_name)
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_pool[0].stream = stream
	_pool[0].play()


func play_music(stream: AudioStream) -> void:
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()
