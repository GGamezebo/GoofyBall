class_name VirtualControls
extends Control

## Dual-thumb touch for the left (Blue / P1) player only.
## Left half: press + drag left/right to move.
## Right half: hold finger to jump.
## Drives `p1_*` InputMap. Local 2P is not dual-player touch — P2 stays keyboard.

@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
@export var move_deadzone_px: float = 28.0

@onready var _origin_ring: Control = $OriginRing
@onready var _knob: Control = $Knob
@onready var _jump_pad: Control = $JumpPad

var _move_active: bool = false
var _move_pointer_id: int = -1
var _move_using_mouse: bool = false
var _move_origin: Vector2 = Vector2.ZERO
var _left_held: bool = false
var _right_held: bool = false

var _jump_active: bool = false
var _jump_pointer_id: int = -1
var _jump_using_mouse: bool = false
var _jump_held: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hide_move_feedback()
	_hide_jump_feedback()
	_release_all_actions()


func _exit_tree() -> void:
	_release_all_actions()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_pointer_down(touch.index, false, touch.position)
		else:
			_on_pointer_up(touch.index, false)
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _move_active and not _move_using_mouse and drag.index == _move_pointer_id:
			_update_move(drag.position)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_on_pointer_down(-1, true, mb.position)
		else:
			_on_pointer_up(-1, true)
		return

	if event is InputEventMouseMotion and _move_active and _move_using_mouse:
		_update_move((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _on_pointer_down(pointer_id: int, is_mouse: bool, screen_pos: Vector2) -> void:
	if _is_left_half(screen_pos):
		if _move_active:
			return
		_begin_move(pointer_id, is_mouse, screen_pos)
		get_viewport().set_input_as_handled()
		return
	if _jump_active:
		return
	_begin_jump(pointer_id, is_mouse, screen_pos)
	get_viewport().set_input_as_handled()


func _on_pointer_up(pointer_id: int, is_mouse: bool) -> void:
	if _move_active and _move_using_mouse == is_mouse and _move_pointer_id == pointer_id:
		_end_move()
		get_viewport().set_input_as_handled()
	if _jump_active and _jump_using_mouse == is_mouse and _jump_pointer_id == pointer_id:
		_end_jump()
		get_viewport().set_input_as_handled()


func _is_left_half(screen_pos: Vector2) -> bool:
	return screen_pos.x < get_viewport_rect().size.x * 0.5


func _begin_move(pointer_id: int, is_mouse: bool, screen_pos: Vector2) -> void:
	_move_active = true
	_move_pointer_id = pointer_id
	_move_using_mouse = is_mouse
	_move_origin = screen_pos
	_show_move_feedback(screen_pos)
	_update_move(screen_pos)


func _update_move(screen_pos: Vector2) -> void:
	if not _move_active:
		return
	var delta_x := screen_pos.x - _move_origin.x
	_left_held = _set_action(left_action, delta_x <= -move_deadzone_px, _left_held)
	_right_held = _set_action(right_action, delta_x >= move_deadzone_px, _right_held)
	_move_knob(screen_pos)


func _end_move() -> void:
	_move_active = false
	_move_pointer_id = -1
	_move_using_mouse = false
	_left_held = _set_action(left_action, false, _left_held)
	_right_held = _set_action(right_action, false, _right_held)
	_hide_move_feedback()


func _begin_jump(pointer_id: int, is_mouse: bool, screen_pos: Vector2) -> void:
	_jump_active = true
	_jump_pointer_id = pointer_id
	_jump_using_mouse = is_mouse
	_jump_held = _set_action(jump_action, true, _jump_held)
	_show_jump_feedback(screen_pos)


func _end_jump() -> void:
	_jump_active = false
	_jump_pointer_id = -1
	_jump_using_mouse = false
	_jump_held = _set_action(jump_action, false, _jump_held)
	_hide_jump_feedback()


func _set_action(action: StringName, want: bool, was_held: bool) -> bool:
	if want == was_held:
		return was_held
	if want:
		Input.action_press(action)
	else:
		Input.action_release(action)
	return want


func _release_all_actions() -> void:
	_left_held = _set_action(left_action, false, _left_held)
	_right_held = _set_action(right_action, false, _right_held)
	_jump_held = _set_action(jump_action, false, _jump_held)
	_move_active = false
	_jump_active = false
	_move_pointer_id = -1
	_jump_pointer_id = -1
	_move_using_mouse = false
	_jump_using_mouse = false


func _show_move_feedback(screen_pos: Vector2) -> void:
	if _origin_ring:
		_origin_ring.visible = true
		_origin_ring.global_position = screen_pos - _origin_ring.size * 0.5
	if _knob:
		_knob.visible = true
		_move_knob(screen_pos)


func _move_knob(screen_pos: Vector2) -> void:
	if _knob == null:
		return
	var capped := Vector2(screen_pos.x - _move_origin.x, 0.0)
	var max_r := 72.0
	capped.x = clampf(capped.x, -max_r, max_r)
	_knob.global_position = _move_origin + capped - _knob.size * 0.5


func _hide_move_feedback() -> void:
	if _origin_ring:
		_origin_ring.visible = false
	if _knob:
		_knob.visible = false


func _show_jump_feedback(screen_pos: Vector2) -> void:
	if _jump_pad == null:
		return
	_jump_pad.visible = true
	_jump_pad.global_position = screen_pos - _jump_pad.size * 0.5


func _hide_jump_feedback() -> void:
	if _jump_pad:
		_jump_pad.visible = false
