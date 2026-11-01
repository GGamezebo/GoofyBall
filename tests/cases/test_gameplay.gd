extends TestCase

## Bots can play a whole match through the same sim (AI keeps rallies going and the match ends).

const SETUP_PATH := "res://src/common/setups/local_2p.tres"


func test_bot_vs_bot_finishes() -> void:
	var setup := (load(SETUP_PATH) as MatchSetup).duplicate(true) as MatchSetup
	setup.match_seed = 2024
	var sim := VolleySim.new()
	sim.reset(setup.to_sim_config())
	var bots := [AiOpponent.new(0), AiOpponent.new(1)]
	var touches := 0
	var last_touch := 0
	var ticks := 0
	while not sim.is_match_over() and ticks < 60 * 60 * 15:
		sim.step([bots[0].decide(sim.state, sim.cfg["physics"], sim.cfg["arena"]), bots[1].decide(sim.state, sim.cfg["physics"], sim.cfg["arena"])])
		if int(sim.state["touch_serial"]) != last_touch:
			last_touch = int(sim.state["touch_serial"])
			touches += 1
		ticks += 1
	print("[gameplay] bot vs bot: %s in %d ticks, %d touches" % [str(sim.state["scores"]), ticks, touches])
	expect(sim.is_match_over(), "match finished")
	expect(touches > 20, "bots actually hit the ball (%d touches)" % touches)


func test_bot_returns_serves() -> void:
	var setup := (load(SETUP_PATH) as MatchSetup).duplicate(true) as MatchSetup
	setup.match_seed = 5
	var sim := VolleySim.new()
	sim.reset(setup.to_sim_config())
	var bot := AiOpponent.new(1)
	var bot_touches := 0
	var last_touch := 0
	for _t in 60 * 60 * 3:
		sim.step([VolleySim.neutral_input(), bot.decide(sim.state, sim.cfg["physics"], sim.cfg["arena"])])
		if int(sim.state["touch_serial"]) != last_touch:
			last_touch = int(sim.state["touch_serial"])
			if int(sim.state["touch_player"]) == 1:
				bot_touches += 1
	expect(bot_touches > 3, "bot touches the ball (%d)" % bot_touches)
