extends TestCase

## Rules and physics of the deterministic sim: serve, scoring, match end, net, zones, jump.

const SETUP_PATH := "res://src/common/setups/local_2p.tres"


func _new_sim(team_sizes: Array = [1, 1], seed_value: int = 42) -> VolleySim:
	var setup := load(SETUP_PATH) as MatchSetup
	var config := setup.to_sim_config()
	config["team_sizes"] = team_sizes
	config["seed"] = seed_value
	var sim := VolleySim.new()
	sim.reset(config)
	return sim


func _idle(sim: VolleySim) -> Array:
	var inputs: Array = []
	for _i in sim.player_count():
		inputs.append(VolleySim.neutral_input())
	return inputs


func test_serve_then_play() -> void:
	var sim := _new_sim()
	expect_eq(int(sim.state["phase"]), VolleySim.Phase.SERVE, "starts with a serve")
	var ball: Dictionary = sim.state["balls"][0]
	expect(bool(ball["frozen"]), "serve ball hangs")
	expect_eq(float(ball["y"]), 5.0, "serve height")
	var delay := int(sim.cfg["rules"]["serve_delay_ticks"])
	for _t in delay:
		sim.step(_idle(sim))
	expect_eq(int(sim.state["phase"]), VolleySim.Phase.PLAY, "play after the serve delay")
	expect(not bool(sim.state["balls"][0]["frozen"]), "ball released")


func test_ball_on_floor_scores_for_other_team() -> void:
	var sim := _new_sim()
	var server := int(sim.state["serving_team"])
	# Move every blob far from the ball so the serve drops untouched on the server side.
	for _t in 1200:
		var inputs: Array = []
		for player in sim.state["players"]:
			var away := -100 if float(player["x"]) > float(sim.state["balls"][0]["x"]) else 100
			inputs.append({"x": -away, "j": 0, "a": 0})
		sim.step(inputs)
		if int(sim.state["point_serial"]) > 0:
			break
	expect_eq(int(sim.state["point_serial"]), 1, "one point scored")
	var scores: Array = sim.state["scores"]
	expect_eq(int(scores[1 - server]), 1, "the other team scored")
	expect_eq(int(scores[server]), 0, "server team did not score")
	expect_eq(int(sim.state["phase"]), VolleySim.Phase.POINT, "point pause")
	expect_eq(int(sim.state["serving_team"]), 1 - server, "scorer serves next")


func test_match_ends_at_win_score() -> void:
	var sim := _new_sim()
	var guard := 0
	while not sim.is_match_over() and guard < 60 * 60 * 10:
		var inputs: Array = []
		for player in sim.state["players"]:
			var away := -100 if float(player["x"]) > float(sim.state["balls"][0]["x"]) else 100
			inputs.append({"x": -away, "j": 0, "a": 0})
		sim.step(inputs)
		guard += 1
	expect(sim.is_match_over(), "match ended")
	var winner := int(sim.state["winner_team"])
	expect(winner == 0 or winner == 1, "winner set")
	expect_eq(int(sim.state["scores"][winner]), 7, "winner has 7")


func test_net_stops_low_ball() -> void:
	var sim := _new_sim()
	var ball: Dictionary = sim.state["balls"][0]
	sim.state["phase"] = VolleySim.Phase.PLAY
	ball["frozen"] = false
	ball["x"] = -2.0
	ball["y"] = 1.0
	ball["vx"] = 30.0
	ball["vy"] = 0.0
	# Park the blobs far away so only the net can touch the ball.
	for player in sim.state["players"]:
		player["x"] = -6.0 if int(player["team"]) == 0 else 6.0
	var crossed := false
	for _t in 30:
		sim.step(_idle(sim))
		if float(sim.state["balls"][0]["x"]) > 0.0 and float(sim.state["balls"][0]["y"]) < 2.4:
			crossed = true
	expect(not crossed, "a low fast ball never tunnels through the net")


func test_players_stay_in_their_zone() -> void:
	var sim := _new_sim()
	for _t in 240:
		sim.step([{"x": 100, "j": 0, "a": 0}, {"x": -100, "j": 0, "a": 0}])
	var limits0 := sim.player_limits(0)
	var limits1 := sim.player_limits(1)
	expect(float(sim.state["players"][0]["x"]) <= float(limits0[1]) + 0.0001, "team 0 stops before the net")
	expect(float(sim.state["players"][1]["x"]) >= float(limits1[0]) - 0.0001, "team 1 stops before the net")
	expect(float(limits0[1]) < 0.0 and float(limits1[0]) > 0.0, "net gap on both sides")


func test_jump_apex() -> void:
	var sim := _new_sim()
	var top := 0.0
	for t in 90:
		sim.step([{"x": 0, "j": 1 if t == 0 else 0, "a": 0}, VolleySim.neutral_input()])
		top = maxf(top, float(sim.state["players"][0]["y"]))
	expect(top > 2.5 and top < 4.5, "jump apex 2.5..4.5 m (got %.2f)" % top)
	expect(sim.is_on_floor(0), "lands again")


func test_three_team_geometry() -> void:
	var sim := _new_sim([1, 1, 1])
	expect_eq((sim.state["zones"] as Array).size(), 3, "three zones")
	expect_eq((sim.state["nets"] as Array).size(), 2, "two nets")
	for i in 3:
		var player: Dictionary = sim.state["players"][i]
		var zone: Dictionary = sim.state["zones"][i]
		expect(float(player["x"]) > float(zone["x_min"]) and float(player["x"]) < float(zone["x_max"]), "player %d starts in its zone" % i)


func test_two_by_two_spreads_players() -> void:
	var sim := _new_sim([2, 2])
	expect_eq(sim.player_count(), 4, "four players")
	var a := float(sim.state["players"][0]["x"])
	var b := float(sim.state["players"][1]["x"])
	expect(absf(a - b) > 1.0, "teammates start apart")
