extends IScene

## App-root HFSM scene: shared progress/saves + RootEvents → HFSM bridge.
## Also opens the sibling platform state (DESKTOP / ANDROID / STEAM / WEB).

@export var root_events: RootEvents
@export var pdata: PData

var _listener: EventListener = EventListener.new()


func initialize(_data: Dictionary) -> void:
	_listener.add(root_events.ev_start_game, _on_ev_start_game)
	_listener.add(root_events.ev_exit_game, _on_ev_exit_game)
	_listener.add(root_events.ev_return_to_menu, _on_ev_return_to_menu)
	_open_host_platform()


func deinit() -> void:
	_listener.deinit()
	super.deinit()


func _open_host_platform() -> void:
	if OS.has_feature("steam"):
		add_event("ev.open_steam")
	elif OS.has_feature("android"):
		add_event("ev.open_android")
	elif (
		OS.has_feature("web")
		or OS.has_feature("yandex_games")
		or OS.has_feature("yandex")
	):
		add_event("ev.open_web")
	else:
		add_event("ev.open_desktop")


func _on_ev_start_game(data: Dictionary) -> void:
	add_event("ev.start_game", data)


func _on_ev_exit_game(data: Dictionary = {}) -> void:
	_apply_match_result(data)
	add_event("ev.exit_game", data)


func _on_ev_return_to_menu(data: Dictionary = {}) -> void:
	add_event("ev.open_menu", data)


func _apply_match_result(data: Dictionary) -> void:
	if pdata == null:
		return
	var game_config: GameConfig = data.get("game_config") as GameConfig
	if game_config == null:
		return

	pdata.matches_played += 1
	var winner_side: int = int(data.get("winner_side", -1))
	if game_config.vs_ai:
		if winner_side == 0:
			pdata.wins_vs_ai += 1
		elif winner_side == 1:
			pdata.losses_vs_ai += 1
	else:
		if winner_side == 0 or winner_side == 1:
			pdata.wins_two_player += 1

	root_events.ev_save_progress.emit()
