class_name FriendWindow
extends Control

## "Играть с другом" window (concept/ui-home, friend modal): create a room and show its code,
## or join with a friend's 4-letter code; server address row. Component: emits requests,
## the menu wires them to OnlineEvents. Opened / closed by the menu WindowStackManager.

signal ev_create_pressed
signal ev_join_pressed(code: String)
signal ev_server_submitted(address: String)
## Window left (back button / ui_cancel): any pending room must be dropped.
signal ev_closed

const CODE_LENGTH := 4

@export var create_button: Button
@export var code_box: Control
@export var code_label: Label
@export var copy_button: Button
@export var code_edit: LineEdit
@export var join_button: Button
@export var status_label: Label
@export var server_edit: LineEdit
@export var server_button: Button

var _busy: bool = false


func _ready() -> void:
	create_button.pressed.connect(func() -> void: ev_create_pressed.emit())
	join_button.pressed.connect(_submit_join)
	code_edit.text_submitted.connect(func(_text: String) -> void: _submit_join())
	code_edit.text_changed.connect(_on_code_changed)
	copy_button.pressed.connect(func() -> void: DisplayServer.clipboard_set(code_label.text))
	server_button.pressed.connect(func() -> void: ev_server_submitted.emit(server_edit.text.strip_edges()))


func on_window_enter() -> void:
	reset()


func on_window_exit() -> void:
	ev_closed.emit()


func reset() -> void:
	set_busy(false)
	code_box.visible = false
	create_button.visible = true
	code_edit.text = ""
	set_status("", false)


func set_server_address(address: String) -> void:
	server_edit.text = address


func set_busy(busy: bool) -> void:
	_busy = busy
	create_button.disabled = busy
	join_button.disabled = busy or code_edit.text.length() != CODE_LENGTH
	code_edit.editable = not busy


func show_code(code: String) -> void:
	create_button.visible = false
	code_box.visible = true
	code_label.text = code


func set_status(text: String, is_error: bool) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color("#FF6B6B") if is_error else Color("#FFD20A"))


func _on_code_changed(text: String) -> void:
	var clean := text.to_upper().strip_edges()
	if clean != text:
		var caret := code_edit.caret_column
		code_edit.text = clean
		code_edit.caret_column = caret
	join_button.disabled = _busy or clean.length() != CODE_LENGTH


func _submit_join() -> void:
	var code := code_edit.text.strip_edges().to_upper()
	if _busy or code.length() != CODE_LENGTH:
		return
	ev_join_pressed.emit(code)
