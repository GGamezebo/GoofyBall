class_name MatchRunner
extends Node

## Owns the deterministic VolleySim for one match and feeds it inputs.
##
## Offline: steps the sim itself every physics tick (60 Hz).
## Online: `OnlineRollback` / SyncManager call `step_with()` / `save_state()` /
## `load_state()` instead, so prediction and rollback replay the exact same code.

signal ev_match_over(result: Dictionary)

## Ticks to keep showing the final score before leaving the match (1.4 s).
const END_LINGER_TICKS := 84

var sim := VolleySim.new()
## State one tick ago — lets views interpolate between fixed ticks offline.
var prev_state: Dictionary = {}
var game_config: GameConfig

var _input_p1 := PlayerInput.new()
var _input_p2 := PlayerInput.new()
var _ai: AiOpponent
var _over_emitted: bool = false


func initialize(config: GameConfig) -> void:
	game_config = config
	var allow_blast: Array = [true, true] if config.online else [true, false]
	var snap_move: Array = [true, not config.vs_ai]
	sim.reset(VolleySim.make_config(
		config.win_score,
		config.serve_height,
		config.max_touches,
		config.round_duration_sec,
		config.round_alarm_sec,
		allow_blast,
		snap_move
	))
	prev_state = sim.save_state()
	_ai = AiOpponent.new() if config.vs_ai and not config.online else null
	_over_emitted = false
	set_physics_process(not config.online)


## Touch BOOM button / any one-shot blast request for the local player.
func request_blast() -> void:
	_input_p1.request_blast()


## Local human input (always the p1_* actions, whichever side we play on).
func sample_local_input() -> Dictionary:
	return _input_p1.sample("p1")


func step_with(inputs: Array) -> void:
	sim.step(inputs)
	_check_match_over()


func save_state() -> Dictionary:
	return sim.save_state()


func load_state(state: Dictionary) -> void:
	sim.load_state(state)


func build_result_payload() -> Dictionary:
	var payload := sim.result_payload()
	payload["game_config"] = game_config
	payload["vs_ai"] = game_config.vs_ai if game_config else false
	payload["ranked"] = game_config.ranked if game_config else false
	payload["local_side"] = game_config.local_side if game_config else 0
	payload["online"] = game_config.online if game_config else false
	return payload


func _physics_process(_delta: float) -> void:
	prev_state = sim.save_state()
	var left := _input_p1.sample("p1")
	var right: Dictionary = _ai.decide(sim.s) if _ai else _input_p2.sample("p2")
	step_with([left, right])


func _check_match_over() -> void:
	if _over_emitted or int(sim.s["phase"]) != VolleySim.Phase.MATCH_END:
		return
	if int(sim.s["phase_ticks"]) < END_LINGER_TICKS:
		return
	_over_emitted = true
	ev_match_over.emit(build_result_payload())
