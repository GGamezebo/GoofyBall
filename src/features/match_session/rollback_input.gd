class_name RollbackInput
extends Node

## One per player slot. SyncManager asks the node whose multiplayer authority is the local peer
## for `_get_local_input()` every tick, ships it to the other peers, and hands every peer the same
## `_network_process(input)` call (real or predicted input).

## Returns this slot's local input; empty for remote slots.
var sample: Callable
var latest: Dictionary = {}


func _get_local_input() -> Dictionary:
	return sample.call() if sample.is_valid() else {}


func _network_process(input: Dictionary) -> void:
	latest = input
