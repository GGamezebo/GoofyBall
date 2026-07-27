class_name VirtualControls
extends Control

## Dual-thumb touch for the left (Blue / P1) player only.
## Left half: press + analog drag left/right to move (strength = finger offset).
## Right half: hold finger to jump.
## Left-edge mid BOOM button: last-chance blast — touchscreen only, once per round.
## Drives `p1_*` InputMap. Local 2P is not dual-player touch — P2 stays keyboard.

@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
## Finger travel (px) for full ±1 move strength.
@export var move_range_px: float = 90.0
@export var move_deadzone_px: float = 10.0

signal ev_self_destruct_requested

@onready var _origin_ring: Control = $OriginRing
@onready var _knob: Control = $Knob
@onready var _jump_pad: Control = $JumpPad
@onready var _bomb_btn: Control = $BombButton

var _move_active: bool = false
var _move_pointer_id: int = -1
var _move_using_mouse: bool = false
var _move_origin: Vector2 = Vector2.ZERO
var _move_axis: float = 0.0
var _left_held: bool = false
var _right_held: bool = false

var _jump_active: bool = false
var _jump_pointer_id: int = -1
var _jump_using_mouse: bool = false
var _jump_held: bool = false

var _touch_ui: bool = false
var _charge_available: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_ui = DisplayServer.is_touchscreen_available()
	_hide_move_feedback()
	_hide_jump_feedback()
	_release_all_actions()
	set_last_chance_available(true)


func _exit_tree() -> void:
	_release_all_actions()


func set_last_chance_available(available: bool) -> void:
	_charge_available = available
	_refresh_bomb_visibility()


func _refresh_bomb_visibility() -> void:
	if _bomb_btn == null:
		return
	_bomb_btn.visible = _touch_ui and _charge_available


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
	if _touch_ui and _charge_available and _is_over_bomb(screen_pos):
		_trigger_bomb()
		get_viewport().set_input_as_handled()
		return
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


func _trigger_bomb() -> void:
	if not _touch_ui or not _charge_available:
		return
	ev_self_destruct_requested.emit()


func _is_over_bomb(screen_pos: Vector2) -> bool:
	if _bomb_btn == null or not _bomb_btn.visible:
		return false
	var rect := Rect2(_bomb_btn.global_position, _bomb_btn.size)
	# Generous hit area for thumbs.
	return rect.grow(12.0).has_point(screen_pos)


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
	var range_px := maxf(move_range_px, 1.0)
	var axis := clampf(delta_x / range_px, -1.0, 1.0)
	var dead := move_deadzone_px / range_px
	if absf(axis) < dead:
		axis = 0.0
	_apply_move_axis(axis)
	_move_knob(screen_pos)


func _apply_move_axis(axis: float) -> void:
	_move_axis = axis
	if axis < 0.0:
		Input.action_press(left_action, -axis)
		if _right_held:
			Input.action_release(right_action)
			_right_held = false
		_left_held = true
	elif axis > 0.0:
		Input.action_press(right_action, axis)
		if _left_held:
			Input.action_release(left_action)
			_left_held = false
		_right_held = true
	else:
		if _left_held:
			Input.action_release(left_action)
			_left_held = false
		if _right_held:
			Input.action_release(right_action)
			_right_held = false


func _end_move() -> void:
	_move_active = false
	_move_pointer_id = -1
	_move_using_mouse = false
	_apply_move_axis(0.0)
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
	_apply_move_axis(0.0)
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
	capped.x = clampf(capped.x, -move_range_px, move_range_px)
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
