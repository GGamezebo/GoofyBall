extends IScene

## Main menu context (concept/ui-home): hero blob, yellow launch block — «Против AI»,
## «С другом», and «Вдвоём на одном ПК» (only where PlatformCaps allows). Starts battles with
## `root_events.ev_start_game({"match_setup": ...})`; online rooms go through OnlineEvents.

@export var root_events: RootEvents
@export var online_events: OnlineEvents
@export var platform_caps: PlatformCaps
@export var online_config: OnlineConfig
@export var vs_ai_setup: MatchSetup
@export var local_2p_setup: MatchSetup
@export var log_settings: LogSettings
@export var vs_ai_button: Button
@export var local_2p_button: Button
@export var friend_window: FriendWindow
@export var hero_blob: BlobView
@export var palette: TeamPalette
@export var hero_radius_px: float = 120.0

var _listener := EventListener.new()
var _log: LogChannel
var _room_pending: bool = false
var _hero_time: float = 0.0
var _hero_base := Vector2.ZERO


func initialize(_data: Dictionary) -> void:
	_log = LogChannel.new("menu", log_settings)
	_listener.add(vs_ai_button.pressed, _start_local.bind(vs_ai_setup))
	_listener.add(local_2p_button.pressed, _start_local.bind(local_2p_setup))
	_listener.add(friend_window.ev_create_pressed, _on_create_pressed)
	_listener.add(friend_window.ev_join_pressed, _on_join_pressed)
	_listener.add(friend_window.ev_closed, _on_friend_closed)
	_listener.add(friend_window.ev_server_submitted, _on_server_submitted)
	_listener.add(online_events.ev_room_created, _on_room_created)
	_listener.add(online_events.ev_room_status, func(text: String) -> void: friend_window.set_status(text, false))
	_listener.add(online_events.ev_room_error, _on_room_error)
	_listener.add(platform_caps.changed, _refresh_caps)
	_refresh_caps()
	friend_window.set_server_address(online_config.address())
	hero_blob.setup(palette.color(0), hero_radius_px, "", false)
	hero_blob.name_label.visible = false
	_hero_base = hero_blob.position
	vs_ai_button.grab_focus()
	_log.info("open", {"local_2p": platform_caps.local_multiplayer})


func deinit() -> void:
	_listener.deinit()
	super.deinit()


func _process(delta: float) -> void:
	# Idle hop for the hero blob (decor only).
	_hero_time += delta
	var phase := fmod(_hero_time, 1.6) / 1.6
	var height := maxf(0.0, sin(phase * TAU)) * 70.0
	var floor_y := _hero_base.y + hero_radius_px
	hero_blob.apply(_hero_base - Vector2(0.0, height), cos(phase * TAU) * -8.0, height <= 0.5, floor_y, hero_blob.get_global_mouse_position(), delta)


func _refresh_caps() -> void:
	local_2p_button.visible = platform_caps.local_multiplayer


func _start_local(template: MatchSetup) -> void:
	var setup := template.duplicate(true) as MatchSetup
	setup.match_seed = randi()
	_log.info("start_local", {"humans": setup.local_human_count()})
	root_events.ev_start_game.emit({"match_setup": setup})


func _on_create_pressed() -> void:
	_room_pending = true
	friend_window.set_busy(true)
	friend_window.set_status("Подключаемся к серверу…", false)
	online_events.ev_create_room.emit()


func _on_join_pressed(code: String) -> void:
	_room_pending = true
	friend_window.set_busy(true)
	friend_window.set_status("Ищем комнату %s…" % code, false)
	online_events.ev_join_room.emit(code)


func _on_room_created(code: String) -> void:
	friend_window.show_code(code)
	friend_window.set_status("Ждём друга… Скажи ему код.", false)


func _on_room_error(text: String) -> void:
	_room_pending = false
	friend_window.set_busy(false)
	friend_window.set_status(text, true)


func _on_friend_closed() -> void:
	if _room_pending:
		_room_pending = false
		online_events.ev_leave_room.emit()


func _on_server_submitted(address: String) -> void:
	online_events.ev_set_server.emit(address)
	friend_window.set_server_address(online_config.address())
	friend_window.set_status("Сервер: %s" % online_config.address(), false)
