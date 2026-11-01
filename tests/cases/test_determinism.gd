extends TestCase

## Same seed + same inputs = same state hash; save/load in the middle changes nothing;
## the recorded cross-platform probe hash still matches on this machine.

const SETUP_PATH := "res://src/common/setups/local_2p.tres"
const PROBE_PATH := "res://src/features/volley_sim/determinism_probe.tres"


func _run(ticks: int, seed_value: int) -> int:
	var setup := (load(SETUP_PATH) as MatchSetup).duplicate(true) as MatchSetup
	setup.match_seed = seed_value
	var sim := VolleySim.new()
	sim.reset(setup.to_sim_config())
	for tick in ticks:
		sim.step([DeterminismProbe.scripted_input(tick, 0), DeterminismProbe.scripted_input(tick, 1)])
	return sim.state_hash()


func test_same_inputs_same_hash() -> void:
	var a := _run(3000, 1234)
	var b := _run(3000, 1234)
	expect_eq(a, b, "two runs give the same hash")
	expect(a != _run(3000, 999), "another seed gives another hash")


func test_save_load_midway() -> void:
	var setup := (load(SETUP_PATH) as MatchSetup).duplicate(true) as MatchSetup
	setup.match_seed = 77
	var sim := VolleySim.new()
	sim.reset(setup.to_sim_config())
	for tick in 1000:
		sim.step([DeterminismProbe.scripted_input(tick, 0), DeterminismProbe.scripted_input(tick, 1)])
	var saved := sim.save_state()
	for tick in range(1000, 2000):
		sim.step([DeterminismProbe.scripted_input(tick, 0), DeterminismProbe.scripted_input(tick, 1)])
	var straight := sim.state_hash()
	sim.load_state(saved)
	for tick in range(1000, 2000):
		sim.step([DeterminismProbe.scripted_input(tick, 0), DeterminismProbe.scripted_input(tick, 1)])
	expect_eq(sim.state_hash(), straight, "load + replay = straight run")


func test_probe_matches_recorded_hash() -> void:
	var probe := load(PROBE_PATH) as DeterminismProbe
	var result := probe.run()
	if not bool(result["ok"]):
		print("[determinism] probe hash %d, recorded %d (scores %s) — update expected_hash if the sim changed on purpose"
			% [result["hash"], result["expected"], str(result["scores"])])
	expect(bool(result["ok"]), "probe hash equals the recorded one")
	var scores: Array = result["scores"]
	expect(int(scores[0]) + int(scores[1]) > 0, "probe actually plays rallies")
