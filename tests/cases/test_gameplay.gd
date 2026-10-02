extends TestCase

## Feel / playability checks: bots must be able to rally, and the real game scene
## must run offline end to end.


func _bot_match(win_score: int, max_ticks: int) -> Dictionary:
	var sim := VolleySim.new()
	sim.reset(VolleySim.make_config(win_score, 5.0, 3, 20.0, 5.0, [false, false], [false, false]))
	var left := AiOpponent.new()
	left.side = 0
	var right := AiOpponent.new()
	right.side = 1
	var longest_rally := 0
	var rally_touches := 0
	var seen_touch := 0
	var seen_point := 0
	var timeouts := 0
	var faults := 0
	var ticks := 0
	while ticks < max_ticks and not sim.is_match_over():
		sim.step([left.decide(sim.s), right.decide(sim.s)])
		ticks += 1
		var touches := int(sim.s["touch_serial"])
		rally_touches += touches - seen_touch
		seen_touch = touches
		var points := int(sim.s["point_serial"])
		if points != seen_point:
			seen_point = points
			longest_rally = maxi(longest_rally, rally_touches)
			rally_touches = 0
			if int(sim.s["msg"]) == VolleySim.Msg.TIMEUP:
				timeouts += 1
			elif int(sim.s["msg"]) == VolleySim.Msg.TOUCHES:
				faults += 1
	return {
		"ticks": ticks, "over": sim.is_match_over(), "longest": longest_rally,
		"timeouts": timeouts, "faults": faults, "score": [int(sim.s["score_l"]), int(sim.s["score_r"])],
	}


func test_bots_can_rally_and_finish_a_match() -> void:
	var r := _bot_match(3, 60 * 60 * 6)
	print("[gameplay] bot match: ", r)
	expect(bool(r["over"]), "bot match finishes within 6 simulated minutes")
	expect(int(r["longest"]) >= 2, "bots exchange at least 2 touches in some rally (longest %d)" % int(r["longest"]))


func test_game_scene_runs_offline() -> void:
	var packed := load("res://src/game/scenes/game/game.tscn") as PackedScene
	var game := packed.instantiate()
	tree.root.add_child(game)
	var cfg := GameConfig.new()
	cfg.vs_ai = true
	cfg.win_score = 1
	game.initialize({"custom_battle": cfg})
	var runner := game.match_runner as MatchRunner
	var view := game.match_view as MatchView
	expect(runner != null and view != null, "game scene exposes runner and view")
	var over_payload := []
	runner.ev_match_over.connect(func(p: Dictionary) -> void: over_payload.append(p))

	runner._physics_process(0.0)
	view._process(0.0)
	expect_eq(view.score_label.text, "0  :  0", "HUD shows the score")
	expect_eq(view.message_label.text, "5", "HUD shows the serve countdown")

	var ticks := 0
	while over_payload.is_empty() and ticks < 60 * 60 * 5:
		runner._physics_process(0.0)
		if ticks % 7 == 0:
			view._process(0.0)
		ticks += 1
	expect(not over_payload.is_empty(), "match ends and reports a result (ticks=%d)" % ticks)
	if not over_payload.is_empty():
		var payload: Dictionary = over_payload[0]
		expect(int(payload["winner_side"]) in [0, 1], "winner is reported")
		expect(bool(payload["vs_ai"]), "payload carries vs_ai")
	game.deinit()
	game.queue_free()
