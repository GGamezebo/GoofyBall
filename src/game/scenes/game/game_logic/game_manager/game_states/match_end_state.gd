class_name MatchEndState
extends StateBase

static func get_state() -> String:
	return "MatchEnd"


func enter(_prev_state: FSMState, event_data: Dictionary) -> void:
	var winner_side: int = int(event_data.get("winner_side", -1))
	var controller := game_manager.match_controller
	if controller:
		controller.finish_match(winner_side)
