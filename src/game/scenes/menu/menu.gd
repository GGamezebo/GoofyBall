extends IScene

@export var root_events: RootEvents
@export var pdata: PData
@export var two_player_config: GameConfig
@export var vs_ai_config: GameConfig
@export var play_two_button: Button
@export var play_ai_button: Button
@export var stats_label: Label
@export var exit_button: Button


func _ready() -> void:
	if play_two_button:
		play_two_button.pressed.connect(_on_play_two)
		play_two_button.grab_focus()
	if play_ai_button:
		play_ai_button.pressed.connect(_on_play_ai)
	if exit_button:
		exit_button.pressed.connect(_on_exit)


func initialize(_data: Dictionary = {}) -> void:
	_refresh_stats()


func _refresh_stats() -> void:
	if stats_label == null or pdata == null:
		return
	stats_label.text = "Matches: %d  |  2P wins: %d  |  vs AI: %d-%d" % [
		pdata.matches_played,
		pdata.wins_two_player,
		pdata.wins_vs_ai,
		pdata.losses_vs_ai,
	]


func _on_play_two() -> void:
	var cfg: GameConfig = two_player_config.duplicate(true) if two_player_config else GameConfig.new()
	cfg.vs_ai = false
	root_events.ev_start_game.emit({"custom_battle": cfg})


func _on_play_ai() -> void:
	var cfg: GameConfig = vs_ai_config.duplicate(true) if vs_ai_config else GameConfig.new()
	cfg.vs_ai = true
	root_events.ev_start_game.emit({"custom_battle": cfg})


func _on_exit() -> void:
	get_tree().quit()
