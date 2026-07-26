extends IScene

@export var root_events: RootEvents
@export var title_label: Label
@export var score_label: Label
@export var menu_button: Button
@export var repeat_button: Button

var _result: Dictionary = {}
var _listener: EventListener = EventListener.new()


func _ready() -> void:
	if repeat_button:
		repeat_button.grab_focus()


func initialize(data: Dictionary) -> void:
	_result = data.duplicate(true)
	var winner_side: int = int(data.get("winner_side", -1))
	var score_left: int = int(data.get("score_left", 0))
	var score_right: int = int(data.get("score_right", 0))
	var vs_ai: bool = false
	var game_config: GameConfig = data.get("game_config") as GameConfig
	if game_config:
		vs_ai = game_config.vs_ai

	if title_label:
		if winner_side == 0:
			title_label.text = "Blue wins!" if not vs_ai else "You win!"
		elif winner_side == 1:
			title_label.text = "Red wins!" if not vs_ai else "AI wins!"
		else:
			title_label.text = "Match over"

	if score_label:
		score_label.text = "%d  :  %d" % [score_left, score_right]

	_listener.add(menu_button.pressed, _on_menu)
	_listener.add(repeat_button.pressed, _on_repeat)


func deinit() -> void:
	_listener.deinit()
	_result.clear()


func _on_menu() -> void:
	root_events.ev_return_to_menu.emit({})


func _on_repeat() -> void:
	var game_config: GameConfig = _result.get("game_config") as GameConfig
	if game_config:
		root_events.ev_start_game.emit({"custom_battle": game_config})
	else:
		root_events.ev_return_to_menu.emit({})
