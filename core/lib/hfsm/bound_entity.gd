class_name HfsmBoundEntity
extends RefCounted

## Base class for entities bound to FSM states.
## Registered by name via host entities map: { slot: { name: Script } }.


func _init(_data: Dictionary = {}) -> void:
	pass


func on_event(_event_name: String, _data: Dictionary) -> void:
	pass


func deinit() -> void:
	pass
