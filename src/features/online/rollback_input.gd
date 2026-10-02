class_name RollbackInput
extends Node

## One per player. godot-rollback-netcode asks the node whose multiplayer authority is the
## local peer for `_get_local_input()` every tick, ships it to the other peer, and hands
## every peer the same `_network_process(input)` call (real or predicted).

var side: int = 0
var latest: Dictionary = {}
var sample: Callable


func _get_local_input() -> Dictionary:
	return sample.call() if sample.is_valid() else {"x": 0, "j": 0, "b": 0}


func _network_process(input: Dictionary) -> void:
	latest = input
