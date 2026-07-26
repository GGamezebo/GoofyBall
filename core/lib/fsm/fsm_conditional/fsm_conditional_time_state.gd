class_name TimedState
extends FSMConditionalState

var _duration: float = 0.0
var _time_elapsed: float = 0.0

func init_timer(p_duration: float, p_state_id: int = UNINITIALIZED_STATE_ID) -> void:
	state_id = p_state_id
	_duration = p_duration
	_time_elapsed = 0.0

func update(dt: float) -> void:
	if not _is_timer_paused():
		_time_elapsed += dt

func _is_timer_paused() -> bool:
	return false

func is_finished() -> bool:
	return _time_elapsed >= _duration

func reset() -> void:
	_time_elapsed = 0.0
