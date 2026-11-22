## Turbo Run clock balance: drives each car with the sim's autopilot
## (clock frozen) over several track seeds and prints how long each checkpoint
## section takes, next to the time that car gets, so the slack can be compared.
## Run: <godot> --headless --path . --script scripts/tools/racer_balance.gd
extends SceneTree

const Sim = preload("res://games/racer/sim.gd")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8]
const CHECKPOINTS := 8
const DT := 1.0 / 60.0


func _init() -> void:
	for car in Sim.CARS.size():
		var sums: Array = []
		sums.resize(CHECKPOINTS)
		sums.fill(0.0)
		var counts: Array = []
		counts.resize(CHECKPOINTS)
		counts.fill(0)
		var crashes := 0
		for sd in SEEDS:
			seed(sd)
			var sim = Sim.new()
			sim.setup(sd)
			sim.car = car
			sim.autopilot = true
			sim.freeze_time = true
			var t := 0.0
			var last := 0.0
			var cp := 0
			var was_crashed := false
			while cp < CHECKPOINTS and t < 900.0:
				sim.step(DT, false, false)
				if sim.state == Sim.State.RACE:
					t += DT
				var crashed: bool = sim.crash_anim > 0.0
				if crashed and not was_crashed:
					crashes += 1
				was_crashed = crashed
				if sim.checkpoints > cp:
					sums[cp] += t - last
					counts[cp] += 1
					last = t
					cp = sim.checkpoints
		var spec: Dictionary = Sim.CARS[car]
		var line := "%-14s start %2ds |" % [spec.name, int(spec.time)]
		var probe = Sim.new()
		probe.car = car
		var slack := float(spec.time)
		for k in CHECKPOINTS:
			var avg: float = sums[k] / maxi(1, counts[k])
			probe.checkpoints = k
			slack -= avg
			line += " cp%d %4.1fs" % [k + 1, avg]
			slack += probe.checkpoint_bonus() if k < CHECKPOINTS - 1 else 0.0
		line += " | crashes %d" % crashes
		print(line)
	quit()
