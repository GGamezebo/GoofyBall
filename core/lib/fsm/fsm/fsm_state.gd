class_name FSMState
extends Node

var state_name: String
var fsm: WeakRef

func _init(_state_name: String) -> void:
	state_name = _state_name

func deinit() -> void:
	pass

func enter(_prev_state: FSMState, _event_data: Dictionary) -> void:
	pass

func leave(_event_data: Dictionary) -> void:
	pass

func reenter(_event_data: Dictionary) -> void:
	pass

func add_event(event_name: String, event_data: Dictionary = {}) -> void:
	var fsm_obj = fsm.get_ref()
	if fsm_obj:
		fsm_obj.add_event(event_name, event_data)

func sync_fsm(p_fsm) -> void:
	fsm = weakref(p_fsm)
