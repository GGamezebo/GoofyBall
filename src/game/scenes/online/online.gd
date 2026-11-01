extends IScene

## App/Online context: owns the Nakama connection for friend rooms. Lives next to Menu /
## Battle / PostBattle, so the connection survives scene changes (rematch without a new room).
## Talks to the rest of the app only through OnlineEvents and RootEvents.

@export var root_events: RootEvents
@export var online_events: OnlineEvents
@export var online_config: OnlineConfig
## Template for an online 1×1: peers and names are filled per match.
@export var online_setup: MatchSetup
@export var log_settings: LogSettings
@export var room_flow: RoomFlow

var _listener := EventListener.new()
var _log: LogChannel


func initialize(_data: Dictionary) -> void:
	_log = LogChannel.new("online", log_settings)
	online_config.load_overrides()
	room_flow.setup(online_config, _log)
	_listener.add(online_events.ev_create_room, room_flow.create_room)
	_listener.add(online_events.ev_join_room, room_flow.join_room)
	_listener.add(online_events.ev_leave_room, room_flow.leave)
	_listener.add(online_events.ev_rematch_request, room_flow.request_rematch)
	_listener.add(online_events.ev_set_server, _on_set_server)
	_listener.add(room_flow.ev_room_created, func(code: String) -> void: online_events.ev_room_created.emit(code))
	_listener.add(room_flow.ev_status, func(text: String) -> void: online_events.ev_room_status.emit(text))
	_listener.add(room_flow.ev_error, func(text: String) -> void: online_events.ev_room_error.emit(text))
	_listener.add(room_flow.ev_rematch_status, func(text: String) -> void: online_events.ev_rematch_status.emit(text))
	_listener.add(room_flow.ev_opponent_left, func() -> void: online_events.ev_opponent_left.emit())
	_listener.add(room_flow.ev_match_ready, _on_match_ready)
	_log.info("ready", {"server": online_config.address(), "name": room_flow.display_name})


func deinit() -> void:
	room_flow.leave()
	_listener.deinit()
	super.deinit()


func _on_set_server(address: String) -> void:
	if not room_flow.is_idle():
		online_events.ev_room_error.emit("Сначала выйди из комнаты")
		return
	if online_config.set_address(address):
		room_flow.setup(online_config, _log)
		_log.info("server_changed", {"server": online_config.address()})
	else:
		online_events.ev_room_error.emit("Адрес вида 192.168.1.10:7350")


func _on_match_ready(info: Dictionary) -> void:
	var setup := online_setup.duplicate(true) as MatchSetup
	var slots := setup.slots()
	slots[0].peer_id = int(info["host_peer"])
	slots[0].display_name = str(info["host_name"])
	slots[1].peer_id = int(info["guest_peer"])
	slots[1].display_name = str(info["guest_name"])
	setup.match_seed = int(info["seed"])
	_log.info("start_online_match", {"round": info["round"], "seed": setup.match_seed})
	root_events.ev_start_game.emit({"match_setup": setup})
