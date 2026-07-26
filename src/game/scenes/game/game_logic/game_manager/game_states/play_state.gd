class_name PlayState
extends StateBase

static func get_state() -> String:
	return "Play"

var _time_left: float = 0.0
var _alarm_on: bool = false
var _timed_out: bool = false


func enter(_prev_state: FSMState, _event_data: Dictionary) -> void:
	var controller := game_manager.match_controller
	if controller == null:
		return
	controller.release_serve()
	event_listener.add(controller.ev_point_scored, _on_point)

	_timed_out = false
	_alarm_on = false
	_time_left = game_config.round_duration_sec if game_config else 60.0
	_emit_time()
	set_process(true)


func leave(_event_data: Dictionary) -> void:
	set_process(false)
	_stop_alarm()
	event_listener.deinit()
	if game_manager.match_controller:
		game_manager.match_controller.set_round_active(false)


func _process(delta: float) -> void:
	var controller := game_manager.match_controller if game_manager else null
	if controller == null or not controller.round_active or _timed_out:
		return

	_time_left = maxf(0.0, _time_left - delta)
	_emit_time()

	var alarm_at: float = game_config.round_alarm_sec if game_config else 5.0
	if not _alarm_on and _time_left <= alarm_at:
		_alarm_on = true
		var ball := controller.ball as Ball
		if ball:
			ball.set_alarm(true)

	if _time_left <= 0.0:
		_on_timeout()


func _on_timeout() -> void:
	_timed_out = true
	set_process(false)
	var controller := game_manager.match_controller
	if controller == null or not controller.round_active:
		return
	controller.resolve_timeout_explosion()


func _on_point(side: int) -> void:
	set_process(false)
	_stop_alarm()
	add_event(FSMGameEvents.POINT, {"side": side})


func _emit_time() -> void:
	var controller := game_manager.match_controller if game_manager else null
	if controller and controller.game_events:
		controller.game_events.ev_round_time_changed.emit(maxi(0, ceili(_time_left)))


func _stop_alarm() -> void:
	_alarm_on = false
	var controller := game_manager.match_controller if game_manager else null
	if controller == null:
		return
	var ball := controller.ball as Ball
	if ball:
		ball.set_alarm(false)
