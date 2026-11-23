## 16-bit era sound-effect synthesizer (D-050): builds AudioStreamWAV effects in
## code, so no audio assets/licences are needed. 32 kHz like the SNES APU.
##
## make(spec) accepts:
##   - Array of segments (one voice, played back to back), or
##   - Dictionary {voices: Array of segment-Arrays (mixed together),
##                 echo: [delay_s, feedback, mix], reverb: [decay_s, mix],
##                 crush: bits, gain: float}
## reverb (D-079): a small Schroeder room (4 combs + 2 allpasses) whose tail
## takes about decay_s to fade by 60 dB; mix is the wet level.
## A segment is either the legacy Array [f0, f1, dur, wave?, vol?] or a Dictionary:
##   f: [f0, f1] Hz (exponential glide) | t: seconds | w: wave | v: volume 0..1
##   a: attack s | env: "exp" | "lin" | "hold" | arp: [semitones..] | arp_rate: Hz
##   vib: [rate_hz, depth_semitones] | lp: 0..1 low-pass amount (1 = darkest)
##   duty: 0..1 for "pulse" | gap: silence after the segment, s
## Waves: square, pulse25, pulse12, pulse, triangle, saw, sine, noise (white,
## sample & hold at f), lfsr (NES-style 15-bit periodic noise clocked at f).
extends RefCounted

const RATE := 32000

static var _cache := {}


static func make(spec: Variant) -> AudioStreamWAV:
	var key := var_to_str(spec)
	if _cache.has(key):
		return _cache[key]
	var w := _build(spec)
	_cache[key] = w
	return w


## Starts synthesizing `specs` on worker threads, so a game's sounds are made
## while its loading screen loads files instead of in one long stall when it
## starts (synthesis runs in script, sample by sample). Returns a job for
## many_done() / finish_many(); null when there's nothing to do or the build
## has no threads (the browser), where make() does the work as before.
static func begin_many(specs: Array) -> Variant:
	if not OS.has_feature("threads"):
		return null
	var todo: Array = []
	var seen := {}
	for spec in specs:
		var key := var_to_str(spec)
		if not _cache.has(key) and not seen.has(key):
			seen[key] = true
			todo.append([key, spec, null])
	if todo.is_empty():
		return null
	var job := {"todo": todo}
	job["id"] = WorkerThreadPool.add_group_task(func(i: int) -> void:
		todo[i][2] = _build(todo[i][1]), todo.size(), -1, false, "PinGames sfx synthesis")
	return job


static func many_done(job: Variant) -> bool:
	return job == null or job.has("done") or WorkerThreadPool.is_group_task_completed(job["id"])


## Waits for a begin_many() job and stores its sounds, so make() finds them.
static func finish_many(job: Variant) -> void:
	if job == null or job.has("done"):
		return
	WorkerThreadPool.wait_for_group_task_completion(job["id"])
	job["done"] = true   # the pool forgets the group once it has been waited for
	for t in job["todo"]:
		if t[2] != null:
			_cache[t[0]] = t[2]


static func _build(spec: Variant) -> AudioStreamWAV:
	var voices: Array = []
	var echo: Array = []
	var reverb: Array = []
	var crush := 0
	var gain := 1.0
	if spec is Dictionary:
		voices = spec.get("voices", [])
		echo = spec.get("echo", [])
		reverb = spec.get("reverb", [])
		crush = int(spec.get("crush", 0))
		gain = float(spec.get("gain", 1.0))
	else:
		voices = [spec]
	var mix := PackedFloat32Array()
	for v in voices:
		var buf := _voice(v)
		if buf.size() > mix.size():
			var old := mix.size()
			mix.resize(buf.size())
			for i in range(old, mix.size()):
				mix[i] = 0.0
		for i in buf.size():
			mix[i] += buf[i]
	if echo.size() >= 2:
		mix = _echo(mix, float(echo[0]), float(echo[1]), float(echo[2]) if echo.size() > 2 else 0.5)
	if reverb.size() >= 2:
		mix = _reverb(mix, float(reverb[0]), float(reverb[1]))
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	var levels := pow(2.0, crush - 1) if crush > 0 else 0.0
	for i in mix.size():
		var s := tanh(mix[i] * gain)  # soft clip
		if levels > 0.0:
			s = round(s * levels) / levels
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func _reverb(dry: PackedFloat32Array, decay: float, wet: float) -> PackedFloat32Array:
	var n := dry.size() + int(decay * RATE)
	var input := dry.duplicate()
	input.resize(n)
	for i in range(dry.size(), n):
		input[i] = 0.0
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	# Parallel feedback combs (mutually prime delays, ~30-40 ms), with damping.
	for d_ms in [29.7, 37.1, 41.1, 43.7]:
		var d := int(d_ms * 0.001 * RATE)
		var fb := pow(0.001, (d_ms * 0.001) / maxf(decay, 0.05))
		var buf := PackedFloat32Array()
		buf.resize(d)
		buf.fill(0.0)
		var lp := 0.0
		for i in n:
			var y := buf[i % d]
			lp = y * 0.6 + lp * 0.4
			buf[i % d] = input[i] + lp * fb
			out[i] += y * 0.25
	# Two series allpasses to diffuse the echoes into a smooth tail.
	for d_ms in [5.0, 1.7]:
		var d := int(d_ms * 0.001 * RATE)
		var buf := PackedFloat32Array()
		buf.resize(d)
		buf.fill(0.0)
		for i in n:
			var b := buf[i % d]
			var x := out[i]
			var y := -0.7 * x + b
			buf[i % d] = x + 0.7 * y
			out[i] = y
	for i in n:
		out[i] = input[i] + out[i] * wet
	return out


static func _voice(segments: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for seg in segments:
		out.append_array(_segment(_normalize(seg)))
	return out


static func _normalize(seg: Variant) -> Dictionary:
	if seg is Dictionary:
		return seg
	var a: Array = seg
	return {"f": [a[0], a[1]], "t": a[2], "w": a[3] if a.size() > 3 else "square",
		"v": a[4] if a.size() > 4 else 0.25, "env": "legacy"}


static func _segment(d: Dictionary) -> PackedFloat32Array:
	var f: Array = d.get("f", [440.0, 440.0])
	var f0 := float(f[0])
	var f1 := float(f[1]) if f.size() > 1 else f0
	var dur := float(d.get("t", 0.1))
	var wave := str(d.get("w", "square"))
	var vol := float(d.get("v", 0.25))
	var attack := float(d.get("a", 0.004))
	var env := str(d.get("env", "exp"))
	var arp: Array = d.get("arp", [])
	var arp_rate := float(d.get("arp_rate", 24.0))
	var vib: Array = d.get("vib", [])
	var lp := clampf(float(d.get("lp", 0.0)), 0.0, 0.98)
	var duty := float(d.get("duty", 0.5))
	match wave:
		"pulse25":
			duty = 0.25
		"pulse12":
			duty = 0.125
	var n := int(dur * RATE)
	var gap := int(float(d.get("gap", 0.0)) * RATE)
	var out := PackedFloat32Array()
	out.resize(n + gap)
	var phase := 0.0
	var held := 0.0
	var lfsr := 0x7FFF
	var lp_state := 0.0
	var alpha := 1.0 - lp
	for i in n:
		var tt := float(i) / RATE
		var u := float(i) / maxf(1.0, n - 1)
		var freq := f0 * pow(f1 / f0, u) if f0 > 0.0 and f1 > 0.0 else lerpf(f0, f1, u)
		if not arp.is_empty():
			freq *= pow(2.0, float(arp[int(tt * arp_rate) % arp.size()]) / 12.0)
		if vib.size() >= 2:
			freq *= pow(2.0, float(vib[1]) * sin(TAU * float(vib[0]) * tt) / 12.0)
		var step := freq / RATE
		phase += step
		var wrapped := phase >= 1.0
		phase = fmod(phase, 1.0)
		var s := 0.0
		match wave:
			"triangle":
				s = 4.0 * absf(phase - 0.5) - 1.0
			"saw":
				s = 2.0 * phase - 1.0
			"sine":
				s = sin(TAU * phase)
			"noise":
				if wrapped or i == 0:
					held = randf() * 2.0 - 1.0
				s = held
			"lfsr":
				if wrapped or i == 0:
					var bit := (lfsr ^ (lfsr >> 1)) & 1
					lfsr = (lfsr >> 1) | (bit << 14)
					held = 1.0 if (lfsr & 1) == 1 else -1.0
				s = held
			_:
				s = 1.0 if phase < duty else -1.0
		# Envelope
		var e := 1.0
		if env == "legacy":
			e = minf(1.0, i / 40.0) * (1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4)
		else:
			var att := clampf(tt / maxf(attack, 0.0001), 0.0, 1.0)
			match env:
				"lin":
					e = att * (1.0 - u)
				"hold":
					e = att * clampf((dur - tt) / 0.02, 0.0, 1.0)
				_:
					e = att * exp(-5.5 * u)
		# One-pole low-pass
		lp_state += alpha * (s - lp_state)
		out[i] = lp_state * vol * e
	for i in gap:
		out[n + i] = 0.0
	return out


## SNES-style feedback echo: e[n] = fb * (x[n-d] + e[n-d]); y = x + wet * e.
## The output is extended so ~3 repeats can ring out.
static func _echo(buf: PackedFloat32Array, delay_s: float, feedback: float, wet: float) -> PackedFloat32Array:
	var d := maxi(1, int(delay_s * RATE))
	var total := buf.size() + d * 3
	var e := PackedFloat32Array()
	e.resize(total)
	var out := PackedFloat32Array()
	out.resize(total)
	for i in total:
		var x := buf[i] if i < buf.size() else 0.0
		var ev := 0.0
		if i >= d:
			var xd := buf[i - d] if i - d < buf.size() else 0.0
			ev = feedback * (xd + e[i - d])
		e[i] = ev
		out[i] = x + wet * ev
	return out
