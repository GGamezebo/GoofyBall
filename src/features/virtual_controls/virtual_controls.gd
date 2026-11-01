class_name VirtualControls
extends Control

## Two-thumb touch controls for the local player (concept/ui.md, match HUD):
## left half — press and drag left / right (analog, strength = finger offset);
## right half — hold to jump (the round button is the visual hint, the whole half works).
## Drives InputMap actions, so the game reads touch exactly like keys. Hidden without touch.

@export var left_action: StringName = &"p1_move_left"
@export var right_action: StringName = &"p1_move_right"
@export var jump_action: StringName = &"p1_jump"
## Finger travel (px) for full ±1 move strength.
@export var move_range_px: float = 90.0
@export var move_deadzone_px: float = 10.0
@export var origin_ring: Control
@export var knob: Control
@export var jump_button: Control

var _touch_ui: bool = false
var _move_pointer: int = -1
var _move_origin := Vector2.ZERO
var _jump_pointer: int = -1
var _left_held: bool = false
var _right_held: bool = false
var _jump_held: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_ui = DisplayServer.is_touchscreen_available()
	visible = _touch_ui
	set_process_input(_touch_ui)
	_hide_move_feedback()


func _exit_tree() -> void:
	release_all()


func release_all() -> void:
	_apply_axis(0.0)
	_set_jump(false)
	_move_pointer = -1
	_jump_pointer = -1
	_hide_move_feedback()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_down(touch.index, touch.position)
		else:
			_on_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _move_pointer:
			_update_move(drag.position)


func _on_down(index: int, pos: Vector2) -> void:
	if pos.x < get_viewport_rect().size.x * 0.5:
		if _move_pointer >= 0:
			return
		_move_pointer = index
		_move_origin = pos
		origin_ring.visible = true
		origin_ring.global_position = pos - origin_ring.size * 0.5
		knob.visible = true
		_update_move(pos)
	elif _jump_pointer < 0:
		_jump_pointer = index
		_set_jump(true)


func _on_up(index: int) -> void:
	if index == _move_pointer:
		_move_pointer = -1
		_apply_axis(0.0)
		_hide_move_feedback()
	if index == _jump_pointer:
		_jump_pointer = -1
		_set_jump(false)


func _update_move(pos: Vector2) -> void:
	var offset := clampf(pos.x - _move_origin.x, -move_range_px, move_range_px)
	var axis := offset / maxf(move_range_px, 1.0)
	if absf(offset) < move_deadzone_px:
		axis = 0.0
	_apply_axis(axis)
	knob.global_position = _move_origin + Vector2(offset, 0.0) - knob.size * 0.5


func _apply_axis(axis: float) -> void:
	if axis < 0.0:
		Input.action_press(left_action, -axis)
		_left_held = true
		if _right_held:
			Input.action_release(right_action)
			_right_held = false
	elif axis > 0.0:
		Input.action_press(right_action, axis)
		_right_held = true
		if _left_held:
			Input.action_release(left_action)
			_left_held = false
	else:
		if _left_held:
			Input.action_release(left_action)
			_left_held = false
		if _right_held:
			Input.action_release(right_action)
			_right_held = false


func _set_jump(pressed: bool) -> void:
	if pressed == _jump_held:
		return
	_jump_held = pressed
	if pressed:
		Input.action_press(jump_action)
	else:
		Input.action_release(jump_action)
	jump_button.modulate = Color(1.4, 1.4, 1.4) if pressed else Color.WHITE


func _hide_move_feedback() -> void:
	if origin_ring:
		origin_ring.visible = false
	if knob:
		knob.visible = false
