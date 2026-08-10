extends IScene

@export var root_events: RootEvents
@export var pdata: PData
@export var two_player_config: GameConfig
@export var vs_ai_config: GameConfig
@export var play_two_button: Button
@export var play_ai_button: Button
@export var dev_login_button: Button
@export var stats_label: Label
@export var online_status_label: Label
@export var exit_button: Button

var _auth_busy: bool = false


func _ready() -> void:
	if play_two_button:
		play_two_button.pressed.connect(_on_play_two)
		play_two_button.grab_focus()
	if play_ai_button:
		play_ai_button.pressed.connect(_on_play_ai)
	if dev_login_button:
		dev_login_button.pressed.connect(_on_dev_login)
	if exit_button:
		exit_button.pressed.connect(_on_exit)


func initialize(_data: Dictionary = {}) -> void:
	_refresh_stats()
	_refresh_online_status()


func _refresh_stats() -> void:
	if stats_label == null or pdata == null:
		return
	stats_label.text = "Matches: %d  |  2P wins: %d  |  vs AI: %d-%d" % [
		pdata.matches_played,
		pdata.wins_two_player,
		pdata.wins_vs_ai,
		pdata.losses_vs_ai,
	]


func _refresh_online_status() -> void:
	if online_status_label == null:
		return
	var online := _resolve_online_service()
	if online == null:
		online_status_label.text = "Online: (no service — isolated run)"
		return
	if online.client != null and online.client.has_session():
		var session: OnlineSession = online.client.session
		online_status_label.text = "Online: guest  %s" % _short_id(session.user_id)
		return
	online_status_label.text = "Online: offline"


func _resolve_online_service() -> OnlineService:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("OnlineService") as OnlineService


func _short_id(user_id: String) -> String:
	if user_id.length() <= 12:
		return user_id
	return "%s…" % user_id.substr(0, 12)


func _on_play_two() -> void:
	var cfg: GameConfig = two_player_config.duplicate(true) if two_player_config else GameConfig.new()
	cfg.vs_ai = false
	root_events.ev_start_game.emit({"custom_battle": cfg})


func _on_play_ai() -> void:
	var cfg: GameConfig = vs_ai_config.duplicate(true) if vs_ai_config else GameConfig.new()
	cfg.vs_ai = true
	root_events.ev_start_game.emit({"custom_battle": cfg})


func _on_dev_login() -> void:
	if _auth_busy:
		return
	var online := _resolve_online_service()
	if online == null:
		_set_online_status("Online: no OnlineService (run via main)")
		return
	_auth_busy = true
	if dev_login_button:
		dev_login_button.disabled = true
	_set_online_status("Online: creating guest…")
	var session := await online.authenticate_guest_async()
	_auth_busy = false
	if dev_login_button:
		dev_login_button.disabled = false
	if session == null or not session.is_valid():
		_set_online_status("Online: guest failed (is Nakama up?)")
		return
	_set_online_status("Online: guest  %s" % _short_id(session.user_id))
	_refresh_stats()


func _set_online_status(text: String) -> void:
	if online_status_label:
		online_status_label.text = text


func _on_exit() -> void:
	get_tree().quit()
