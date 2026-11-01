class_name RoomFlow
extends Node

## Friend room by code over the Nakama relay:
## sign in (device id) → RPC `room_create` / `room_join` (server returns code, match name, seed)
## → join the relayed named match through `NakamaMultiplayerBridge` (first in = host = peer 1)
## → peers say hello → host starts the match (and every rematch) for both.
## The connection lives until `leave()`, so a rematch needs no new room. Two players max.

signal ev_room_created(code: String)
signal ev_status(text: String)
signal ev_error(text: String)
## {"seed", "round", "host_peer", "guest_peer", "host_name", "guest_name"}
signal ev_match_ready(info: Dictionary)
signal ev_rematch_status(text: String)
signal ev_opponent_left

enum State { IDLE, CONNECTING, WAITING, IN_MATCH }

const JOIN_TIMEOUT_SEC := 12.0
const SEED_STEP := 7919

@export var nakama_node: Node

var client := OnlineClient.new()
var display_name: String = ""

var _config: OnlineConfig
var _log: LogChannel
var _state: State = State.IDLE
var _socket: NakamaSocket
var _bridge: NakamaMultiplayerBridge
var _code: String = ""
var _base_seed: int = 0
var _round: int = 0
var _opponent_peer: int = 0
var _names: Dictionary = {}
var _rematch: Dictionary = {}
var _profile: String = ""


func setup(config: OnlineConfig, log_channel: LogChannel) -> void:
	_config = config
	_log = log_channel
	_profile = _cmdline_profile()
	client.setup(nakama_node, config)
	var device := OnlineClient.device_id(_profile)
	display_name = "Игрок %s" % device.right(4).to_upper()


func is_idle() -> bool:
	return _state == State.IDLE


func create_room() -> void:
	if _state != State.IDLE:
		return
	_state = State.CONNECTING
	_log.info("room_create_requested", {"server": _config.address()})
	if not await _connect():
		return
	ev_status.emit("Создаём комнату…")
	var result := await client.rpc_async("room_create", {})
	if _state != State.CONNECTING:
		return
	if not bool(result.get("ok", false)):
		_fail("room_create_failed", "Не удалось создать комнату", {"error": client.last_error})
		return
	_code = str(result["code"])
	_base_seed = int(result.get("seed", randi()))
	_log.info("room_created", {"code": _code})
	ev_room_created.emit(_code)
	if await _join_match(str(result["match_name"])):
		_state = State.WAITING


func join_room(code: String) -> void:
	if _state != State.IDLE:
		return
	_state = State.CONNECTING
	_log.info("room_join_requested", {"code": code, "server": _config.address()})
	if not await _connect():
		return
	var result := await client.rpc_async("room_join", {"code": code})
	if _state != State.CONNECTING:
		return
	if not bool(result.get("ok", false)):
		var error := str(result.get("error", client.last_error))
		var text := "Комната %s не найдена" % code if error == "room_not_found" else "Не удалось войти в комнату"
		if error == "rate_limited" or error == "too_many_attempts":
			text = "Слишком много попыток, подожди немного"
		_fail("room_join_failed", text, {"code": code, "error": error})
		return
	_code = code
	_base_seed = int(result.get("seed", 0))
	ev_status.emit("Подключаемся к другу…")
	if await _join_match(str(result["match_name"])):
		_state = State.WAITING


func request_rematch() -> void:
	if _state != State.IN_MATCH or _opponent_peer == 0:
		ev_rematch_status.emit("Соперник уже вышел")
		return
	_rematch[multiplayer.get_unique_id()] = true
	_rpc_rematch.rpc_id(_opponent_peer)
	ev_rematch_status.emit("Ждём соперника…")
	_log.info("rematch_requested", {"round": _round})
	_check_rematch()


func leave() -> void:
	if _state == State.IDLE and _socket == null:
		return
	_log.info("room_leave", {"code": _code, "state": State.keys()[_state]})
	_state = State.IDLE
	_opponent_peer = 0
	_names.clear()
	_rematch.clear()
	var bridge := _bridge
	var socket := _socket
	_bridge = null
	_socket = null
	# On app quit the node is already out of the tree: no multiplayer API, just drop the socket.
	if is_inside_tree():
		_disconnect_multiplayer_signals()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		if bridge != null:
			await bridge.leave()
	if socket != null:
		socket.close()


# --- connection -------------------------------------------------------------------------

func _connect() -> bool:
	ev_status.emit("Подключаемся к серверу…")
	if not await client.sign_in_async(_profile):
		_fail("sign_in_failed", _no_server_text(), {"error": client.last_error, "server": _config.address()})
		return false
	if _state != State.CONNECTING:
		return false
	_log.info("signed_in", {"user": client.session.user_id})
	_socket = nakama_node.create_socket_from(client.nakama)
	_socket.closed.connect(_on_socket_closed)
	var connected = await _socket.connect_async(client.session)
	if connected != null and connected.is_exception():
		_fail("socket_failed", _no_server_text(), {"error": str(connected.get_exception().message), "server": _config.address()})
		return false
	_bridge = NakamaMultiplayerBridge.new(_socket)
	multiplayer.multiplayer_peer = _bridge.multiplayer_peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_log.info("socket_connected")
	return true


func _join_match(match_name: String) -> bool:
	var outcome := {"done": false, "ok": false, "error": ""}
	var on_joined := func() -> void:
		outcome["done"] = true
		outcome["ok"] = true
	var on_error := func(exception) -> void:
		outcome["done"] = true
		outcome["error"] = str(exception.message) if exception != null else "join error"
	_bridge.match_joined.connect(on_joined, CONNECT_ONE_SHOT)
	_bridge.match_join_error.connect(on_error, CONNECT_ONE_SHOT)
	_bridge.join_named_match(match_name)
	var waited := 0.0
	while not bool(outcome["done"]) and waited < JOIN_TIMEOUT_SEC:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if _bridge == null:
			return false
	if not bool(outcome["ok"]):
		_fail("match_join_failed", "Не удалось подключиться к комнате", {"error": outcome["error"] if outcome["done"] else "timeout"})
		return false
	_log.info("match_joined", {"code": _code, "peer": multiplayer.get_unique_id(), "host": multiplayer.is_server()})
	if not multiplayer.is_server():
		ev_status.emit("Ждём хозяина комнаты…")
	return true


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		if _opponent_peer != 0 and _opponent_peer != peer_id:
			_log.warn("room_full_rejected", {"peer": peer_id})
			_rpc_room_full.rpc_id(peer_id)
			return
		_opponent_peer = peer_id
	elif peer_id == 1:
		_opponent_peer = 1
	else:
		return
	_log.info("peer_connected", {"peer": peer_id})
	ev_status.emit("Друг подключился!")
	_rpc_hello.rpc_id(peer_id, display_name)


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id != _opponent_peer:
		return
	_log.warn("opponent_left", {"peer": peer_id, "state": State.keys()[_state]})
	_opponent_peer = 0
	ev_opponent_left.emit()
	if _state == State.WAITING and multiplayer.is_server():
		ev_status.emit("Друг вышел. Ждём снова…")
	elif _state == State.IN_MATCH:
		leave()


func _on_socket_closed() -> void:
	if _state == State.IDLE:
		return
	_log.warn("socket_closed", {"state": State.keys()[_state]})
	var was_in_match := _state == State.IN_MATCH
	if was_in_match:
		ev_opponent_left.emit()
	leave()
	if not was_in_match:
		ev_error.emit("Связь с сервером потеряна")


func _disconnect_multiplayer_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)


## 127.0.0.1 only works when the server runs on this same device (PC); on a phone it points
## at the phone itself, so say what to type instead.
func _no_server_text() -> String:
	var text := "Нет связи с сервером %s" % _config.address()
	if _config.host == "127.0.0.1" or _config.host == "localhost":
		text += ".\n127.0.0.1 — это само устройство. Впиши в «Сервер» IP компьютера с сервером, например 192.168.1.10:7350"
	return text


func _fail(event: String, text: String, kv: Dictionary) -> void:
	_log.warn(event, kv)
	await leave()
	ev_error.emit(text)


# --- room RPCs (same node path on both peers) ---------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(peer_name: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != _opponent_peer and not (sender == 1 and not multiplayer.is_server()):
		return
	_names[sender] = peer_name.left(24)
	_log.info("hello", {"peer": sender})
	if multiplayer.is_server() and _state == State.WAITING:
		_start_round()


@rpc("authority", "call_remote", "reliable")
func _rpc_start(round_index: int, host_name: String, guest_name: String) -> void:
	_round = round_index
	_names[1] = host_name
	_names[multiplayer.get_unique_id()] = guest_name
	_emit_ready(host_name, guest_name)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_rematch() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != _opponent_peer:
		return
	_rematch[sender] = true
	ev_rematch_status.emit("Соперник хочет реванш!")
	_check_rematch()


@rpc("authority", "call_remote", "reliable")
func _rpc_room_full() -> void:
	_log.warn("room_full")
	await leave()
	ev_error.emit("Комната занята: в ней уже двое")


func _check_rematch() -> void:
	if not multiplayer.is_server() or _opponent_peer == 0:
		return
	if _rematch.get(1, false) and _rematch.get(_opponent_peer, false):
		_round += 1
		_start_round()


func _start_round() -> void:
	var host_name := display_name
	var guest_name := str(_names.get(_opponent_peer, "Гость"))
	_rpc_start.rpc_id(_opponent_peer, _round, host_name, guest_name)
	_emit_ready(host_name, guest_name)


func _emit_ready(host_name: String, guest_name: String) -> void:
	_state = State.IN_MATCH
	_rematch.clear()
	var guest_peer := _opponent_peer if multiplayer.is_server() else multiplayer.get_unique_id()
	var info := {
		"seed": (_base_seed + _round * SEED_STEP) & 0x7FFFFFFF,
		"round": _round,
		"host_peer": 1,
		"guest_peer": guest_peer,
		"host_name": host_name,
		"guest_name": guest_name,
	}
	_log.info("match_ready", {"code": _code, "round": _round, "guest_peer": guest_peer})
	ev_match_ready.emit(info)


static func _cmdline_profile() -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--profile="):
			return arg.trim_prefix("--profile=")
	return ""
