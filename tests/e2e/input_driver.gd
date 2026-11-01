extends Node

## Test helper: presses the p1 InputMap actions with a scripted pattern every physics frame,
## so the real game reads it exactly like a player on a keyboard.

var salt: int = 3
var _frame: int = 0


func _physics_process(_delta: float) -> void:
	_frame += 1
	var block := _frame / 25
	var a := ((block + salt) * 1103515245 + 12345) & 0x7fffffff
	var b := ((_frame + salt) * 1664525 + 1013904223) & 0x7fffffff
	var axis := float(((a >> 8) % 201) - 100) / 100.0
	Input.action_release("p1_move_left")
	Input.action_release("p1_move_right")
	if axis < -0.05:
		Input.action_press("p1_move_left", -axis)
	elif axis > 0.05:
		Input.action_press("p1_move_right", axis)
	if (b >> 6) % 5 == 0:
		Input.action_press("p1_jump")
	else:
		Input.action_release("p1_jump")
