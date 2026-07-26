class_name PointState
extends StateBase

static func get_state() -> String:
	return "Point"

var _delay_tween: Tween
var _pending_side: int = 0


func enter(_prev_state: FSMState, event_data: Dictionary) -> void:
	_stop_delay()
	_pending_side = int(event_data.get("side", 0))
	var controller := game_manager.match_controller
	if controller:
		controller.apply_point(_pending_side)

	_delay_tween = create_tween()
	_delay_tween.tween_interval(1.1)
	_delay_tween.tween_callback(_on_point_delay_done)


func leave(_event_data: Dictionary) -> void:
	_stop_delay()


func deinit() -> void:
	_stop_delay()
	super.deinit()


func _on_point_delay_done() -> void:
	_delay_tween = null
	if game_manager == null or game_manager.fsm == null:
		return
	var controller := game_manager.match_controller
	if controller and controller.is_match_over():
		add_event(FSMGameEvents.MATCH_OVER, {"winner_side": controller.get_winner_side()})
	else:
		add_event(FSMGameEvents.NEXT_ROUND)


func _stop_delay() -> void:
	if _delay_tween and is_instance_valid(_delay_tween):
		_delay_tween.kill()
	_delay_tween = null
