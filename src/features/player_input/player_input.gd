class_name PlayerInput
extends RefCounted

## Turns InputMap state (keyboard, gamepad, touch via VirtualControls) into the
## simulation's input dictionary: {"x": -100..100, "j": 0|1, "b": 0|1}.
## Everything is quantised to ints so it is cheap and exact to send over the network.

const BLAST_ACTION := &"p1_self_destruct"

## One-shot request (touch BOOM button); consumed by the next `sample`.
var _blast_latched: bool = false


func request_blast() -> void:
	_blast_latched = true


## `prefix` = "p1" or "p2" (InputMap action prefix).
func sample(prefix: String) -> Dictionary:
	var x := roundi(Input.get_axis(prefix + "_left", prefix + "_right") * 100.0)
	var jump := Input.is_action_pressed(prefix + "_jump")
	var blast := _blast_latched
	if prefix == "p1" and Input.is_action_pressed(BLAST_ACTION):
		blast = true
	_blast_latched = false
	return {"x": x, "j": 1 if jump else 0, "b": 1 if blast else 0}
