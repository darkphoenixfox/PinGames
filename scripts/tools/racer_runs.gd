## Turbo Run full-race simulations: plays whole games headless with the sim's
## autopilot (the attract driver; no nitro, cautious), clock running, on each
## car over many track seeds, and reports how far they get and how the police
## chases go. Relative numbers between cars and rules; a good human is faster.
## Run: <godot> --headless --path . --script scripts/tools/racer_runs.gd [-- --runs=N]
extends SceneTree

const Sim = preload("res://games/racer/sim.gd")
const DT := 1.0 / 60.0
const MAX_TIME := 1800.0   # s of race per game at most


func _init() -> void:
	var runs := 20
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.get_slice("=", 1))
	print("runs per car: %d" % runs)
	for car in Sim.CARS.size():
		var stages: Array = []
		var scores: Array = []
		var times: Array = []
		var chases := 0
		var busts := 0
		var escapes := 0
		var rams := 0
		var resets := 0
		var crashes := 0
		var traps := 0
		var chase_len: Array = []
		var to_catch: Array = []
		for sd in range(1, runs + 1):
			seed(sd * 7919 + car)
			var sim = Sim.new()
			sim.setup(sd)
			sim.car = car
			sim.time_left = sim.start_time()
			sim.autopilot = true
			var t := 0.0
			var chase_t := -1.0
			var caught_logged := false
			while not sim.done and t < MAX_TIME:
				sim.step(DT, false, false)
				t += DT
				if chase_t >= 0.0:
					chase_t += DT
					if not caught_logged and not sim.police.is_empty() and bool(sim.police.get("caught", false)):
						caught_logged = true
						to_catch.append(chase_t)
				for e in sim.events:
					match e[0]:
						"trap":
							traps += 1
						"police_spawn":
							chases += 1
							chase_t = 0.0
							caught_logged = false
						"busted":
							busts += 1
							if chase_t >= 0.0:
								chase_len.append(chase_t)
							chase_t = -1.0
						"police_escape":
							escapes += 1
							if chase_t >= 0.0:
								chase_len.append(chase_t)
							chase_t = -1.0
						"police_ram":
							rams += 1
						"police_hits_reset":
							resets += 1
						"crash":
							crashes += 1
			stages.append(sim.checkpoints + 1)
			scores.append(sim.score)
			times.append(t)
		var spec: Dictionary = Sim.CARS[car]
		print("")
		print("== %s (top %d mph, start %ds) ==" % [spec.name, roundi(float(spec.top) * Sim.MPH), int(spec.time)])
		print("  stage reached: avg %.1f, min %d, max %d   (%s)" % [_avg(stages), _min(stages), _max(stages), _hist(stages)])
		print("  race length:   avg %.0f s   score avg %s" % [_avg(times), _fmt(int(_avg(scores)))])
		print("  speed traps triggered: %d   crashes: %d (%.1f per game)" % [traps, crashes, crashes / float(runs)])
		print("  police chases: %d (%.2f per game)   busted %d   escaped %d   unresolved %d" % [chases, chases / float(runs),
			busts, escapes, chases - busts - escapes])
		if not chase_len.is_empty():
			print("  chase length:  avg %.1f s, min %.1f, max %.1f" % [_avg(chase_len), _min(chase_len), _max(chase_len)])
		if not to_catch.is_empty():
			print("  time to catch up (within 25 m): avg %.1f s over %d chases" % [_avg(to_catch), to_catch.size()])
		print("  rams: %d   ram counts reset (got away / too slow): %d" % [rams, resets])
	quit()


func _avg(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(1.0, a.size())


func _min(a: Array) -> float:
	return a.min() if not a.is_empty() else 0.0


func _max(a: Array) -> float:
	return a.max() if not a.is_empty() else 0.0


func _hist(a: Array) -> String:
	var h := {}
	for v in a:
		h[int(v)] = int(h.get(int(v), 0)) + 1
	var keys := h.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("S%d:%d" % [k, h[k]])
	return " ".join(parts)


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
