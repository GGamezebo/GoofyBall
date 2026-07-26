class_name WindowStackManager
extends Node

## Full-screen menu window stack.
## Forward: ButtonWindowTransition children (button → open target).
## Back: ButtonWindowBack children (button → pop) or close_stacked_window() / ui_cancel.
## Dialogs/overlays must NOT go through this stack.

@export_category("Stacked windows")
@export var default_window: Control

var window_stack: Array[Control] = []


func _ready() -> void:
	for node in get_children():
		if node is ButtonWindowTransition:
			var transition := node as ButtonWindowTransition
			if transition.target_window:
				transition.target_window.hide()
			if transition.button:
				transition.button.pressed.connect(open_stacked_window.bind(transition.target_window))
		elif node is ButtonWindowBack:
			var back := node as ButtonWindowBack
			if back.button:
				back.button.pressed.connect(close_stacked_window)

	if default_window:
		open_stacked_window(default_window)


func open_stacked_window(new_window: Control) -> void:
	if new_window == null:
		push_error("[WindowStackManager] open_stacked_window: window is null")
		return

	if window_stack.has(new_window):
		while window_stack.back() != new_window:
			var top_window: Control = window_stack.pop_back()
			_hide_window(top_window)
		_show_window(new_window)
	else:
		if not window_stack.is_empty() and not window_stack.back().is_ancestor_of(new_window):
			_hide_window(window_stack.back())
		window_stack.append(new_window)
		_show_window(new_window)

	_grab_focus_in(new_window)


func close_stacked_window() -> void:
	if window_stack.size() <= 1:
		return

	var current_window: Control = window_stack.pop_back()
	_hide_window(current_window)

	var previous_window: Control = window_stack.back()
	_show_window(previous_window)
	_grab_focus_in(previous_window)


func can_go_back() -> bool:
	return window_stack.size() > 1


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not can_go_back():
		return
	close_stacked_window()
	get_viewport().set_input_as_handled()


func _show_window(window: Control) -> void:
	window.show()
	if window.has_method("on_window_enter"):
		window.on_window_enter()


func _hide_window(window: Control) -> void:
	if window.has_method("on_window_exit"):
		window.on_window_exit()
	window.hide()


func _grab_focus_in(window: Control) -> void:
	var focus_target := window.find_next_valid_focus()
	if focus_target:
		focus_target.grab_focus()
