class_name PlayState
extends StateBase

static func get_state() -> String:
	return "Play"


func enter(_prev_state: FSMState, _event_data: Dictionary) -> void:
	var controller := game_manager.match_controller
	if controller == null:
		return
	controller.release_serve()
	event_listener.add(controller.ev_point_scored, _on_point)


func leave(_event_data: Dictionary) -> void:
	event_listener.deinit()
	if game_manager.match_controller:
		game_manager.match_controller.set_round_active(false)


func _on_point(side: int) -> void:
	add_event(FSMGameEvents.POINT, {"side": side})
