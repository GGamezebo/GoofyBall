class_name DeterminismProbe
extends Resource

## Cross-platform determinism check: runs the sim for `ticks` with scripted integer inputs
## (no floats in the input generator) and compares the final state hash with `expected_hash`,
## which was recorded on the reference PC. Same hash on Windows and Android = same physics.

@export var setup: MatchSetup
@export var ticks: int = 3600
## Recorded by `tests/cases/test_determinism.gd` (prints it when it differs).
@export var expected_hash: int = 0


## Returns {"hash": int, "expected": int, "ok": bool, "tick": int, "scores": Array}.
func run() -> Dictionary:
	var sim := VolleySim.new()
	sim.reset(setup.to_sim_config())
	var count := sim.player_count()
	for tick in ticks:
		var inputs: Array = []
		for player in count:
			inputs.append(scripted_input(tick, player))
		sim.step(inputs)
	var value := sim.state_hash()
	return {
		"hash": value,
		"expected": expected_hash,
		"ok": value == expected_hash,
		"tick": int(sim.state["tick"]),
		"scores": (sim.state["scores"] as Array).duplicate(),
	}


## Integer LCG: the stick changes every 20 ticks, jumps come in short bursts.
static func scripted_input(tick: int, player: int) -> Dictionary:
	var block := tick / 20
	var v := (block * 1103515245 + 12345 + player * 7919) & 0x7FFFFFFF
	v = (v * 1103515245 + 12345) & 0x7FFFFFFF
	var x := (v % 201) - 100
	var jump := 1 if ((v >> 8) % 5 == 0 and tick % 20 < 8) else 0
	return {"x": x, "j": jump, "a": 0}
