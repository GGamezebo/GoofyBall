extends IScene

@export var root_events: RootEvents
@export var pdata: PData
@export var two_player_config: GameConfig
@export var vs_ai_config: GameConfig
@export var play_two_button: Button
@export var play_ai_button: Button
@export var create_room_button: Button
@export var join_room_button: Button
@export var find_match_button: Button
@export var cancel_online_button: Button
@export var room_code_edit: LineEdit
@export var room_code_label: Label
@export var lobby_status_label: Label
@export var dev_account_option: OptionButton
@export var dev_login_button: Button
@export var open_console_button: Button
@export var stats_label: Label
@export var online_status_label: Label
@export var exit_button: Button

var _auth_busy: bool = false
var _lobby_busy: bool = false
var _online_start_emitted: bool = false
var _pending_ranked: bool = false
var _mm_ticket_id: String = ""
var _mm_poll_running: bool = false
var _logged_dev_index: int = -1


func _ready() -> void:
	if play_two_button:
		play_two_button.pressed.connect(_on_play_two)
		play_two_button.grab_focus()
	if play_ai_button:
		play_ai_button.pressed.connect(_on_play_ai)
	if create_room_button:
		create_room_button.pressed.connect(_on_create_room)
	if join_room_button:
		join_room_button.pressed.connect(_on_join_room)
	if find_match_button:
		find_match_button.pressed.connect(_on_find_match)
	if cancel_online_button:
		cancel_online_button.pressed.connect(_on_cancel_online)
		cancel_online_button.visible = false
	if room_code_edit:
		room_code_edit.placeholder_text = "Room code"
		room_code_edit.max_length = 8
	_populate_dev_accounts()
	_apply_dev_mode_visibility()
	if dev_login_button:
		dev_login_button.pressed.connect(_on_dev_login)
	if open_console_button:
		open_console_button.pressed.connect(_on_open_console)
	if exit_button:
		exit_button.pressed.connect(_on_exit)


func _is_dev_mode() -> bool:
	return OS.is_debug_build() or OS.has_feature("editor")


func _apply_dev_mode_visibility() -> void:
	var dev := _is_dev_mode()
	if open_console_button:
		open_console_button.visible = dev
	# Dev account picker is for local multi-client testing only.
	if dev_account_option:
		dev_account_option.visible = dev
	if dev_login_button:
		dev_login_button.visible = dev
	var row := get_node_or_null("Center/VBox/DevAccountRow") as CanvasItem
	if row:
		row.visible = dev


func _populate_dev_accounts() -> void:
	if dev_account_option == null:
		return
	dev_account_option.clear()
	for i in DevAccounts.count():
		dev_account_option.add_item(DevAccounts.label(i), i)
	if DevAccounts.count() > 0:
		dev_account_option.select(0)


func initialize(_data: Dictionary = {}) -> void:
	_online_start_emitted = false
	_lobby_busy = false
	_mm_ticket_id = ""
	_mm_poll_running = false
	_refresh_stats()
	_refresh_online_status()
	_set_lobby_status("")
	_set_room_code_display("")
	_connect_online_signals()
	_set_cancel_visible(false)


func deinit() -> void:
	_disconnect_online_signals()
	super.deinit()


func _connect_online_signals() -> void:
	var online := _resolve_online_service()
	if online == null:
		return
	if not online.ev_peer_connected.is_connected(_on_peer_connected):
		online.ev_peer_connected.connect(_on_peer_connected)
	if not online.ev_match_joined.is_connected(_on_match_joined):
		online.ev_match_joined.connect(_on_match_joined)
	if not online.ev_match_join_failed.is_connected(_on_match_join_failed):
		online.ev_match_join_failed.connect(_on_match_join_failed)


func _disconnect_online_signals() -> void:
	var online := _resolve_online_service()
	if online == null:
		return
	if online.ev_peer_connected.is_connected(_on_peer_connected):
		online.ev_peer_connected.disconnect(_on_peer_connected)
	if online.ev_match_joined.is_connected(_on_match_joined):
		online.ev_match_joined.disconnect(_on_match_joined)
	if online.ev_match_join_failed.is_connected(_on_match_join_failed):
		online.ev_match_join_failed.disconnect(_on_match_join_failed)


func _refresh_stats() -> void:
	if stats_label == null or pdata == null:
		return
	stats_label.text = "Matches: %d  |  2P wins: %d  |  vs AI: %d-%d" % [
		pdata.matches_played,
		pdata.wins_two_player,
		pdata.wins_vs_ai,
		pdata.losses_vs_ai,
	]


func _selected_dev_index() -> int:
	if dev_account_option == null or DevAccounts.count() == 0:
		return 0
	return clampi(dev_account_option.get_selected_id(), 0, DevAccounts.count() - 1)


func _refresh_online_status() -> void:
	if online_status_label == null:
		return
	var online := _resolve_online_service()
	if online == null:
		online_status_label.text = "Online: (no service — isolated run)"
		return
	if online.client != null and online.client.has_session():
		var session: OnlineSession = online.client.session
		var label := DevAccounts.label(_logged_dev_index) if _logged_dev_index >= 0 else "guest"
		var display_name := session.username if not session.username.is_empty() else label
		online_status_label.text = "Online: %s  %s" % [display_name, _short_id(session.user_id)]
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
	cfg.online = false
	cfg.ranked = false
	root_events.ev_start_game.emit({"custom_battle": cfg})


func _on_play_ai() -> void:
	var cfg: GameConfig = vs_ai_config.duplicate(true) if vs_ai_config else GameConfig.new()
	cfg.vs_ai = true
	cfg.online = false
	cfg.ranked = false
	root_events.ev_start_game.emit({"custom_battle": cfg})


func _ensure_session_async() -> bool:
	var online := _resolve_online_service()
	if online == null:
		_set_lobby_status("No OnlineService — run via main.tscn")
		return false
	var want := _selected_dev_index()
	if online.client != null and online.client.has_session() and _logged_dev_index == want:
		return true
	_set_lobby_status("Signing in as %s…" % DevAccounts.label(want))
	var session := await online.authenticate_guest_async(want)
	_logged_dev_index = want if session != null and session.is_valid() else -1
	_refresh_online_status()
	if session == null or not session.is_valid():
		_set_lobby_status("Guest login failed (is Nakama up?)")
		return false
	return true


func _on_create_room() -> void:
	if _lobby_busy:
		return
	_lobby_busy = true
	_online_start_emitted = false
	_pending_ranked = false
	_set_lobby_buttons_disabled(true)
	_set_cancel_visible(true)
	if not await _ensure_session_async():
		_lobby_busy = false
		_set_lobby_buttons_disabled(false)
		_set_cancel_visible(false)
		return
	var online := _resolve_online_service()
	_set_lobby_status("Creating room…")
	var result := await online.room_create_async("menu")
	if not bool(result.get("ok", false)):
		_set_lobby_status("Room create failed")
		_lobby_busy = false
		_set_lobby_buttons_disabled(false)
		_set_cancel_visible(false)
		return
	var code := str(result.get("code", ""))
	_set_room_code_display(code)
	_set_lobby_status("Room %s — waiting for friend…" % code)
	_try_start_online_battle()


func _on_join_room() -> void:
	if _lobby_busy:
		return
	var code := room_code_edit.text.strip_edges().to_upper() if room_code_edit else ""
	if code.length() < 4:
		_set_lobby_status("Enter a 4-letter room code")
		return
	_lobby_busy = true
	_online_start_emitted = false
	_pending_ranked = false
	_set_lobby_buttons_disabled(true)
	_set_cancel_visible(true)
	if not await _ensure_session_async():
		_lobby_busy = false
		_set_lobby_buttons_disabled(false)
		_set_cancel_visible(false)
		return
	var online := _resolve_online_service()
	_set_lobby_status("Joining %s…" % code)
	var result := await online.room_join_async(code)
	if not bool(result.get("ok", false)):
		_set_lobby_status("Join failed — check code")
		_lobby_busy = false
		_set_lobby_buttons_disabled(false)
		_set_cancel_visible(false)
		return
	_set_room_code_display(code)
	_set_lobby_status("Joined %s — waiting…" % code)
	_try_start_online_battle()


func _on_find_match() -> void:
	if _lobby_busy:
		return
	_lobby_busy = true
	_online_start_emitted = false
	_pending_ranked = true
	_mm_ticket_id = ""
	_set_lobby_buttons_disabled(true)
	_set_cancel_visible(true)
	if not await _ensure_session_async():
		_lobby_busy = false
		_set_lobby_buttons_disabled(false)
		_set_cancel_visible(false)
		return
	var online := _resolve_online_service()
	_set_lobby_status("Finding ranked match…")
	var result := await online.mm_enqueue_async(0, "any")
	if not bool(result.get("ok", false)):
		_set_lobby_status("Matchmaker failed")
		_lobby_busy = false
		_set_lobby_buttons_disabled(false)
		_set_cancel_visible(false)
		return
	var status := str(result.get("status", ""))
	if status == "matched":
		_set_lobby_status("Matched — connecting…")
		_try_start_online_battle()
		return
	_mm_ticket_id = str(result.get("ticket_id", ""))
	_set_lobby_status("In queue…")
	_poll_mm_until_matched()


func _poll_mm_until_matched() -> void:
	if _mm_poll_running:
		return
	_mm_poll_running = true
	var online := _resolve_online_service()
	while _lobby_busy and online and not _mm_ticket_id.is_empty():
		await get_tree().create_timer(1.0).timeout
		if not _lobby_busy:
			break
		var st := await online.mm_status_async(_mm_ticket_id)
		if str(st.get("status", "")) == "matched":
			_set_lobby_status("Matched — connecting…")
			_try_start_online_battle()
			break
		if not bool(st.get("ok", true)):
			_set_lobby_status("Queue ended")
			_lobby_busy = false
			_set_lobby_buttons_disabled(false)
			_set_cancel_visible(false)
			break
	_mm_poll_running = false


func _on_cancel_online() -> void:
	var online := _resolve_online_service()
	if online and not _mm_ticket_id.is_empty():
		online.mm_cancel_async(_mm_ticket_id)
	_mm_ticket_id = ""
	_lobby_busy = false
	_online_start_emitted = false
	if online:
		online.leave_realtime_match_async()
	_set_lobby_status("Cancelled")
	_set_room_code_display("")
	_set_lobby_buttons_disabled(false)
	_set_cancel_visible(false)


func _on_match_joined(_match_id: String) -> void:
	_set_lobby_status("In match — waiting for opponent…")
	_try_start_online_battle()


func _on_match_join_failed(message: String) -> void:
	_set_lobby_status("Join failed: %s" % message)
	_lobby_busy = false
	_set_lobby_buttons_disabled(false)
	_set_cancel_visible(false)


func _on_peer_connected(_peer_id: int) -> void:
	_try_start_online_battle()


func _peer_count() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 0
	return multiplayer.get_peers().size() + 1


func _try_start_online_battle() -> void:
	if _online_start_emitted or not _lobby_busy:
		return
	var online := _resolve_online_service()
	if online == null or online.realtime == null or not online.realtime.is_in_match():
		return
	if _peer_count() < 2:
		_set_lobby_status("Waiting for opponent (%d/2)…" % maxi(1, _peer_count()))
		return
	# Mark early so both peers don't double-fire; settle SceneMultiplayer peer map.
	_online_start_emitted = true
	_set_lobby_status("Opponent found — starting…")
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	if online.realtime == null or not online.realtime.is_in_match() or _peer_count() < 2:
		_online_start_emitted = false
		_set_lobby_status("Opponent lost — waiting…")
		return
	_lobby_busy = false
	_set_cancel_visible(false)
	_set_lobby_buttons_disabled(false)
	_set_lobby_status("Starting online match…")

	var cfg: GameConfig = two_player_config.duplicate(true) if two_player_config else GameConfig.new()
	cfg.vs_ai = false
	cfg.online = true
	cfg.ranked = _pending_ranked
	cfg.local_side = 0 if multiplayer.is_server() else 1
	var display_name := DevAccounts.username(_logged_dev_index) if _logged_dev_index >= 0 else DevAccounts.username(_selected_dev_index())
	if online.client != null and online.client.session != null and not online.client.session.username.is_empty():
		display_name = online.client.session.username
	root_events.ev_start_game.emit({
		"custom_battle": cfg,
		"online": true,
		"ranked": _pending_ranked,
		"local_side": cfg.local_side,
		"local_display_name": display_name,
	})


func _set_lobby_buttons_disabled(disabled: bool) -> void:
	if create_room_button:
		create_room_button.disabled = disabled
	if join_room_button:
		join_room_button.disabled = disabled
	if find_match_button:
		find_match_button.disabled = disabled
	if play_two_button:
		play_two_button.disabled = disabled
	if play_ai_button:
		play_ai_button.disabled = disabled
	if dev_account_option:
		dev_account_option.disabled = disabled
	if dev_login_button:
		dev_login_button.disabled = disabled


func _set_cancel_visible(visible: bool) -> void:
	if cancel_online_button:
		cancel_online_button.visible = visible


func _set_lobby_status(text: String) -> void:
	if lobby_status_label:
		lobby_status_label.text = text


func _set_room_code_display(code: String) -> void:
	if room_code_label:
		room_code_label.text = ("Code: %s" % code) if not code.is_empty() else ""


func _on_dev_login() -> void:
	if _auth_busy:
		return
	var online := _resolve_online_service()
	if online == null:
		_set_online_status("Online: no OnlineService (run via main)")
		return
	var want := _selected_dev_index()
	_auth_busy = true
	if dev_login_button:
		dev_login_button.disabled = true
	if dev_account_option:
		dev_account_option.disabled = true
	_set_online_status("Online: signing in as %s…" % DevAccounts.label(want))
	var session := await online.authenticate_guest_async(want)
	_auth_busy = false
	if dev_login_button:
		dev_login_button.disabled = false
	if dev_account_option:
		dev_account_option.disabled = false
	if session == null or not session.is_valid():
		_logged_dev_index = -1
		_set_online_status("Online: login failed (is Nakama up?)")
		return
	_logged_dev_index = want
	_refresh_online_status()
	_refresh_stats()


func _set_online_status(text: String) -> void:
	if online_status_label:
		online_status_label.text = text


func _on_exit() -> void:
	get_tree().quit()


func _on_open_console() -> void:
	if not _is_dev_mode():
		return
	var url := OnlineEndpoints.console_url()
	var online := _resolve_online_service()
	if online != null and online.config != null:
		url = online.config.console_url()
	var err := OS.shell_open(url)
	if err != OK:
		_set_lobby_status("Could not open console: %s" % url)
	else:
		_set_lobby_status("Opened Nakama Console: %s" % url)
