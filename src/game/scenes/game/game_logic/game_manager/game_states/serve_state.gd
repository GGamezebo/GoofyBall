class_name ServeState
extends StateBase

const COUNTDOWN_SEC := 5

static func get_state() -> String:
	return "Serve"

var _seconds_left: int = 0
var _countdown_tween: Tween


func enter(_prev_state: FSMState, _event_data: Dictionary) -> void:
	_stop_countdown()
	var controller := game_manager.match_controller
	if controller:
		controller.begin_serve()

	_seconds_left = COUNTDOWN_SEC
	_tick_countdown()


func leave(_event_data: Dictionary) -> void:
	_stop_countdown()


func deinit() -> void:
	_stop_countdown()
	super.deinit()


func _tick_countdown() -> void:
	var controller := game_manager.match_controller if game_manager else null
	if controller and controller.game_events:
		controller.game_events.ev_message.emit(str(_seconds_left))

	_countdown_tween = create_tween()
	_countdown_tween.tween_interval(1.0)
	_countdown_tween.tween_callback(_on_countdown_tick)


func _on_countdown_tick() -> void:
	_seconds_left -= 1
	if _seconds_left > 0:
		_tick_countdown()
		return

	_countdown_tween = null
	if game_manager and game_manager.fsm:
		add_event(FSMGameEvents.START_PLAY)


func _stop_countdown() -> void:
	if _countdown_tween and is_instance_valid(_countdown_tween):
		_countdown_tween.kill()
	_countdown_tween = null
