extends TestCase

const IDLE := {"x": 0, "j": 0, "b": 0}


func _sim(cfg: Dictionary = {}) -> VolleySim:
	var sim := VolleySim.new()
	sim.reset(cfg if not cfg.is_empty() else VolleySim.make_config())
	return sim


func _run(sim: VolleySim, ticks: int, inputs: Array = [IDLE, IDLE]) -> void:
	for _i in ticks:
		sim.step(inputs)


## Deterministic pseudo-random inputs (LCG) as a function of the tick number.
func _scripted_inputs(tick: int) -> Array:
	var a := (tick * 1103515245 + 12345) & 0x7fffffff
	var b := (tick * 1664525 + 1013904223) & 0x7fffffff
	return [
		{"x": ((a >> 8) % 201) - 100, "j": (a >> 4) & 1, "b": 1 if (a % 997) == 0 else 0},
		{"x": ((b >> 8) % 201) - 100, "j": (b >> 4) & 1, "b": 1 if (b % 991) == 0 else 0},
	]


func _all_finite(value: Variant) -> bool:
	if value is Dictionary:
		for k in value:
			if not _all_finite(value[k]):
				return false
	elif value is Array:
		for v in value:
			if not _all_finite(v):
				return false
	elif value is float:
		return is_finite(value)
	return true


func test_serve_countdown_then_play() -> void:
	var sim := _sim()
	expect_eq(int(sim.s["phase"]), VolleySim.Phase.SERVE, "starts in SERVE")
	expect(bool(sim.s["ball"]["frozen"]), "ball held during serve")
	expect_eq(sim.serve_countdown_sec(), 5, "countdown starts at 5")
	_run(sim, VolleySim.SERVE_TICKS - 1)
	expect_eq(int(sim.s["phase"]), VolleySim.Phase.SERVE, "still serving one tick early")
	_run(sim, 1)
	expect_eq(int(sim.s["phase"]), VolleySim.Phase.PLAY, "PLAY after countdown")
	expect(not bool(sim.s["ball"]["frozen"]), "ball released in PLAY")


func test_dropped_ball_scores_for_opponent() -> void:
	var sim := _sim() # left serves, ball drops on the left half
	_run(sim, VolleySim.SERVE_TICKS)
	var guard := 0
	while int(sim.s["phase"]) == VolleySim.Phase.PLAY and guard < 600:
		sim.step([IDLE, IDLE])
		guard += 1
	expect_eq(int(sim.s["phase"]), VolleySim.Phase.POINT, "rally ended")
	expect_eq(int(sim.s["score_r"]), 1, "right scores when ball lands on left")
	expect_eq(int(sim.s["score_l"]), 0, "left stays at 0")
	expect(not bool(sim.s["serving_left"]), "scorer serves next")
	expect_eq(int(sim.s["point_serial"]), 1, "point serial increments")


func test_point_leads_to_next_serve_or_match_end() -> void:
	var sim := _sim()
	_run(sim, VolleySim.SERVE_TICKS)
	while int(sim.s["phase"]) == VolleySim.Phase.PLAY:
		sim.step([IDLE, IDLE])
	_run(sim, VolleySim.POINT_TICKS)
	expect_eq(int(sim.s["phase"]), VolleySim.Phase.SERVE, "next serve after point delay")
	expect(float(sim.s["ball"]["x"]) > 0.0, "ball served on the scorer's (right) side")

	var quick := _sim(VolleySim.make_config(1))
	_run(quick, VolleySim.SERVE_TICKS)
	while int(quick.s["phase"]) == VolleySim.Phase.PLAY:
		quick.step([IDLE, IDLE])
	_run(quick, VolleySim.POINT_TICKS)
	expect_eq(int(quick.s["phase"]), VolleySim.Phase.MATCH_END, "win_score 1 ends the match")
	expect_eq(int(quick.s["winner"]), 1, "right side wins")
	expect(quick.is_match_over(), "is_match_over")


func test_net_blocks_ball() -> void:
	var sim := _sim()
	_run(sim, VolleySim.SERVE_TICKS)
	var ball: Dictionary = sim.s["ball"]
	ball["x"] = -2.0
	ball["y"] = 1.2
	ball["vx"] = 14.0
	ball["vy"] = 0.0
	var crossed := false
	for _i in 40:
		sim.step([IDLE, IDLE])
		if int(sim.s["phase"]) != VolleySim.Phase.PLAY:
			break
		if float(sim.s["ball"]["x"]) > 0.0:
			crossed = true
	expect(not crossed, "ball must not tunnel through the net")


func test_blob_stays_on_own_half_and_jumps() -> void:
	var sim := _sim()
	_run(sim, 200, [{"x": 100, "j": 0, "b": 0}, {"x": -100, "j": 0, "b": 0}])
	var l: Dictionary = sim.s["p"][0]
	var r: Dictionary = sim.s["p"][1]
	expect(float(l["x"]) <= -VolleySim.NET_LIMIT_X + 0.0001, "left blob clamped at the net")
	expect(float(r["x"]) >= VolleySim.NET_LIMIT_X - 0.0001, "right blob clamped at the net")

	var jumper := _sim()
	jumper.step([{"x": 0, "j": 1, "b": 0}, IDLE])
	expect(float(jumper.s["p"][0]["vy"]) > 0.0, "jump gives upward velocity")
	var peak := 0.0
	for _i in 120:
		jumper.step([IDLE, IDLE])
		peak = maxf(peak, float(jumper.s["p"][0]["y"]))
	expect(peak > 2.0 and peak < 4.0, "jump apex is sensible (%f)" % peak)
	expect(jumper.is_on_floor(0), "lands again")


func test_blast_once_per_round_and_edge_triggered() -> void:
	var sim := _sim()
	_run(sim, VolleySim.SERVE_TICKS)
	var ball: Dictionary = sim.s["ball"]
	ball["x"] = -3.0
	ball["y"] = 3.0
	ball["vx"] = 0.0
	ball["vy"] = 0.0
	expect(sim.can_blast(0), "blast available on own half")
	expect(not sim.can_blast(1), "right blob has no blast offline")
	var hold := {"x": 0, "j": 0, "b": 1}
	sim.step([hold, IDLE])
	expect(bool(sim.s["p"][0]["dead"]), "blob exploded")
	expect_eq(int(sim.s["blast_serial"]), 1, "blast serial")
	expect(float(sim.s["ball"]["vx"]) > 0.0, "ball is pushed toward the opponent")
	sim.step([hold, IDLE])
	expect_eq(int(sim.s["blast_serial"]), 1, "held button does not re-fire")
	expect(not sim.can_blast(0), "no second blast in the same round")


func test_timeout_explodes_ball() -> void:
	var sim := _sim(VolleySim.make_config(7, 5.0, 3, 1.0, 0.5))
	_run(sim, VolleySim.SERVE_TICKS)
	# Keep the ball safely in the air so only the clock can end the rally.
	var ended := false
	for _i in 120:
		var ball: Dictionary = sim.s["ball"]
		if int(sim.s["phase"]) == VolleySim.Phase.PLAY:
			ball["y"] = 4.0
			ball["vy"] = 0.0
		sim.step([IDLE, IDLE])
		if int(sim.s["phase"]) == VolleySim.Phase.POINT:
			ended = true
			break
	expect(ended, "rally ended by the clock")
	expect_eq(int(sim.s["msg"]), VolleySim.Msg.TIMEUP, "time-up message")
	expect(bool(sim.s["ball"]["hidden"]), "ball exploded")
	expect_eq(int(sim.s["explode_serial"]), 1, "explode serial")


func test_too_many_touches_is_a_fault() -> void:
	var sim := _sim(VolleySim.make_config(7, 5.0, 2))
	_run(sim, VolleySim.SERVE_TICKS)
	for n in 3:
		var ball: Dictionary = sim.s["ball"]
		var blob: Dictionary = sim.s["p"][0]
		sim.s["ball"]["last_touch"] = -1
		ball["x"] = float(blob["x"])
		ball["y"] = float(blob["y"]) + 0.7
		ball["vx"] = 0.0
		ball["vy"] = -1.0
		sim.step([IDLE, IDLE])
		if int(sim.s["phase"]) != VolleySim.Phase.PLAY:
			break
	expect_eq(int(sim.s["msg"]), VolleySim.Msg.TOUCHES, "third touch with max 2 faults")
	expect_eq(int(sim.s["score_r"]), 1, "fault gives the opponent the point")


func test_determinism_and_rollback_roundtrip() -> void:
	var a := _sim()
	var b := _sim()
	var snapshot: Dictionary = {}
	for t in range(1, 3001):
		var inp := _scripted_inputs(t)
		a.step(inp)
		b.step(inp)
		if t == 1000:
			snapshot = b.save_state()
		expect(t % 500 != 0 or a.s == b.s, "identical state at tick %d" % t)
	expect(a.s == b.s, "same inputs, same final state")
	expect(_all_finite(a.s), "no NaN/inf in state")

	# Roll b back to tick 1000 and replay the same inputs: must land on the same state.
	b.load_state(snapshot)
	expect_eq(int(b.s["tick"]), 1000, "restored tick")
	for t in range(1001, 3001):
		b.step(_scripted_inputs(t))
	expect(a.s == b.s, "rollback + resimulation reproduces the original state")
	expect(a.s.hash() == b.s.hash(), "state hash matches")
