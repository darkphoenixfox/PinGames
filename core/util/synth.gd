## Tiny chiptune synthesizer: builds AudioStreamWAV sound effects from code, so UI
## sounds need no asset files. A sound is a list of segments:
##   [freq_start_hz, freq_end_hz, duration_s, wave("square"|"triangle"|"noise"), volume]
## (wave and volume are optional).
extends RefCounted

const RATE := 22050


static func make(segments: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for seg in segments:
		data.append_array(_segment(seg))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


static func _segment(seg: Array) -> PackedByteArray:
	var f0: float = seg[0]
	var f1: float = seg[1]
	var dur: float = seg[2]
	var wave: String = seg[3] if seg.size() > 3 else "square"
	var vol: float = seg[4] if seg.size() > 4 else 0.25
	var n := int(dur * RATE)
	var out := PackedByteArray()
	out.resize(n * 2)
	var phase := 0.0
	var noise := 0.0
	for i in n:
		var t := float(i) / maxf(1.0, n - 1)
		var f := lerpf(f0, f1, t)
		phase = fmod(phase + f / RATE, 1.0)
		var v := 0.0
		match wave:
			"triangle":
				v = 4.0 * absf(phase - 0.5) - 1.0
			"noise":
				if phase < f / RATE:
					noise = randf() * 2.0 - 1.0
				v = noise
			_:
				v = 1.0 if phase < 0.5 else -1.0
		# Short attack, decay over the last 40%.
		var env := minf(1.0, i / 40.0) * (1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4)
		out.encode_s16(i * 2, int(clampf(v * vol * env, -1.0, 1.0) * 32767.0))
	return out
