class_name OnlineRealtime
extends Node

## Nakama socket + MultiplayerBridge — shares NakamaClient from OnlineClient.

signal ev_socket_connected
signal ev_socket_closed
signal ev_match_joined(match_id: String)
signal ev_match_join_failed(message: String)
signal ev_peer_connected(peer_id: int)
signal ev_peer_disconnected(peer_id: int)

var online_client: OnlineClient
var socket: NakamaSocket
var bridge: NakamaMultiplayerBridge

var _socket_connected: bool = false
var _join_busy: bool = false


func setup(p_client: OnlineClient) -> void:
	online_client = p_client


func is_socket_connected() -> bool:
	return _socket_connected and socket != null


func is_in_match() -> bool:
	return bridge != null and bridge.match_state == NakamaMultiplayerBridge.MatchState.CONNECTED


func get_match_id() -> String:
	if bridge == null:
		return ""
	return bridge.match_id


func connect_socket_async(_online_session: OnlineSession = null) -> bool:
	if online_client == null or online_client.nakama == null:
		ev_match_join_failed.emit("OnlineClient / Nakama not setup")
		return false
	var nk_session: NakamaSession = online_client.get_nakama_session()
	if nk_session == null or not nk_session.valid:
		ev_match_join_failed.emit("no Nakama session")
		return false
	if get_node_or_null("/root/Nakama") == null:
		ev_match_join_failed.emit("Nakama autoload missing")
		return false

	if is_socket_connected():
		return true

	socket = Nakama.create_socket_from(online_client.nakama)
	socket.closed.connect(_on_socket_closed)
	var conn = await socket.connect_async(nk_session)
	if conn != null and conn.is_exception():
		var ex = conn.get_exception()
		ev_match_join_failed.emit(str(ex.message) if ex else "socket connect failed")
		_socket_connected = false
		return false

	_socket_connected = true
	_rebuild_bridge()
	ev_socket_connected.emit()
	return true


func join_named_match_async(match_name: String) -> bool:
	if match_name.strip_edges().is_empty():
		ev_match_join_failed.emit("empty match_name")
		return false
	if _join_busy:
		ev_match_join_failed.emit("join already in progress")
		return false
	if bridge == null or not is_socket_connected():
		ev_match_join_failed.emit("socket not connected")
		return false
	if bridge.match_state != NakamaMultiplayerBridge.MatchState.DISCONNECTED:
		await leave_match_async()

	_join_busy = true
	var ok := await _await_bridge_join(func(): bridge.join_named_match(match_name))
	_join_busy = false
	return ok


func join_match_async(match_id: String) -> bool:
	if match_id.strip_edges().is_empty():
		ev_match_join_failed.emit("empty match_id")
		return false
	if _join_busy:
		ev_match_join_failed.emit("join already in progress")
		return false
	if bridge == null or not is_socket_connected():
		ev_match_join_failed.emit("socket not connected")
		return false
	if bridge.match_state != NakamaMultiplayerBridge.MatchState.DISCONNECTED:
		await leave_match_async()

	_join_busy = true
	var ok := await _await_bridge_join(func(): bridge.join_match(match_id))
	_join_busy = false
	return ok


func leave_match_async() -> void:
	if bridge == null:
		return
	await bridge.leave()
	if is_instance_valid(self) and multiplayer and bridge != null:
		multiplayer.multiplayer_peer = bridge.multiplayer_peer


func disconnect_socket() -> void:
	_socket_connected = false
	if bridge != null:
		bridge.leave()
		bridge = null
	if socket != null:
		if socket.closed.is_connected(_on_socket_closed):
			socket.closed.disconnect(_on_socket_closed)
		socket.close()
		socket = null
	if multiplayer and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	ev_socket_closed.emit()


func _rebuild_bridge() -> void:
	if socket == null:
		return
	bridge = NakamaMultiplayerBridge.new(socket)
	bridge.match_joined.connect(_on_match_joined)
	bridge.match_join_error.connect(_on_match_join_error)
	multiplayer.multiplayer_peer = bridge.multiplayer_peer
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _await_bridge_join(start: Callable) -> bool:
	var done := {"v": false}
	var success := {"v": false}
	var err_msg := {"v": ""}

	var on_ok := func() -> void:
		success.v = true
		done.v = true
	var on_err := func(ex) -> void:
		err_msg.v = str(ex.message) if ex != null else "join failed"
		success.v = false
		done.v = true

	bridge.match_joined.connect(on_ok, CONNECT_ONE_SHOT)
	bridge.match_join_error.connect(on_err, CONNECT_ONE_SHOT)
	start.call()

	var timeout_sec := 12.0
	var elapsed := 0.0
	while not done.v and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	if not done.v:
		ev_match_join_failed.emit("join timed out")
		await leave_match_async()
		return false
	if not success.v:
		ev_match_join_failed.emit(err_msg.v)
		return false
	return true


func _on_match_joined() -> void:
	ev_match_joined.emit(get_match_id())


func _on_match_join_error(ex) -> void:
	var msg := str(ex.message) if ex != null else "match join error"
	ev_match_join_failed.emit(msg)


func _on_peer_connected(peer_id: int) -> void:
	ev_peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	ev_peer_disconnected.emit(peer_id)


func _on_socket_closed() -> void:
	_socket_connected = false
	ev_socket_closed.emit()
