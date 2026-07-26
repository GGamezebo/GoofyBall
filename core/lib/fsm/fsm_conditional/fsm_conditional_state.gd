class_name FSMConditionalState
extends Node2D

const UNINITIALIZED_STATE_ID = -1

var state_id: int = UNINITIALIZED_STATE_ID

func _init(p_state_id: int = UNINITIALIZED_STATE_ID):
	state_id = p_state_id

## Equivalent to a Python @classmethod make
static func make(p_state_id: int = UNINITIALIZED_STATE_ID) -> FSMConditionalState:
	return FSMConditionalState.new(p_state_id)

func deinit() -> void:
	pass

func can_transit() -> bool:
	return true

func is_finished() -> bool:
	return false

func activate() -> void:
	pass

func update(_dt: float) -> void:
	pass

func deactivate() -> void:
	reset()

func interrupt() -> void:
	deactivate()

func reset() -> void:
	pass

func kill() -> void:
	pass
