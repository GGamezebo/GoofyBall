class_name GameManager
extends Node

@export var game_events: GameEvents
@export var states: Array[StateBase]

var fsm: FSM
var match_controller: MatchController


func initialize(game_config: GameConfig, controller: MatchController) -> void:
	match_controller = controller
	if states.is_empty():
		for child in get_children():
			if child is StateBase:
				states.append(child)
	for state in states:
		state.initialize(self, game_config)

	fsm = FSM.new({
		"initial": {"state": ServeState.get_state()},
		"transitions": [
			{"src": ServeState.get_state(), "dst": PlayState.get_state(), "event": FSMGameEvents.START_PLAY},
			{"src": PlayState.get_state(), "dst": PointState.get_state(), "event": FSMGameEvents.POINT},
			{"src": PointState.get_state(), "dst": ServeState.get_state(), "event": FSMGameEvents.NEXT_ROUND},
			{"src": PointState.get_state(), "dst": MatchEndState.get_state(), "event": FSMGameEvents.MATCH_OVER},
			{"src": MatchEndState.get_state(), "dst": ServeState.get_state(), "event": FSMGameEvents.RESTART},
		],
		"states": states,
	})
	fsm.ev_state_changed.connect(_on_state_changed)


func _exit_tree() -> void:
	if fsm:
		fsm.deinit()


func _on_state_changed(from_state_name: String, to_state_name: String) -> void:
	if game_events:
		game_events.ev_game_state_changed.emit(from_state_name, to_state_name)
