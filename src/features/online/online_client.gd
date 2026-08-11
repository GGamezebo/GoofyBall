class_name OnlineClient
extends RefCounted

## Single Nakama path: wraps nakama-godot NakamaClient for auth + RPC.
## Realtime reuses the same NakamaClient via OnlineRealtime.

signal ev_request_failed(operation: String, message: String)

var config: OnlineConfig
var nakama: NakamaClient
var session: OnlineSession
var platform_id: String = "device"


func setup(host_node: Node, p_config: OnlineConfig) -> void:
	config = p_config if p_config else OnlineConfig.new()
	if host_node == null or host_node.get_node_or_null("/root/Nakama") == null:
		push_error("OnlineClient: Nakama autoload missing")
		ev_request_failed.emit("setup", "Nakama autoload missing")
		return
	var scheme := config.scheme.strip_edges()
	if scheme.is_empty():
		scheme = "https" if config.use_ssl else "http"
	nakama = Nakama.create_client(
		config.server_key,
		config.host,
		config.port,
		scheme,
		int(config.request_timeout_sec)
	)


func has_session() -> bool:
	return session != null and session.is_valid()


func get_nakama_session() -> NakamaSession:
	if session == null:
		return null
	return session.nakama_session


func authenticate_device_async(
	device_id: String,
	create: bool = true,
	username = null
) -> OnlineSession:
	if nakama == null:
		ev_request_failed.emit("authenticate_device", "Nakama client not setup")
		return null
	var nk: NakamaSession = await nakama.authenticate_device_async(device_id, username, create)
	return _store_session(nk, "device")


func authenticate_google_async(id_token: String, create: bool = true) -> OnlineSession:
	if nakama == null:
		ev_request_failed.emit("authenticate_google", "Nakama client not setup")
		return null
	var nk: NakamaSession = await nakama.authenticate_google_async(id_token, null, create)
	return _store_session(nk, "google")


func authenticate_steam_async(session_ticket: String, create: bool = true) -> OnlineSession:
	if nakama == null:
		ev_request_failed.emit("authenticate_steam", "Nakama client not setup")
		return null
	var nk: NakamaSession = await nakama.authenticate_steam_async(session_ticket, null, create, null, false)
	return _store_session(nk, "steam")


func authenticate_yandex_async(player_id: String, signature: String = "", create: bool = true) -> OnlineSession:
	if nakama == null:
		ev_request_failed.emit("authenticate_yandex", "Nakama client not setup")
		return null
	var custom_id := player_id if player_id.begins_with("yandex_") else "yandex_%s" % player_id
	var vars = null
	if not signature.is_empty():
		vars = {"yandex_signature": signature}
	var nk: NakamaSession = await nakama.authenticate_custom_async(custom_id, null, create, vars)
	return _store_session(nk, "yandex")


func link_google_async(id_token: String) -> bool:
	var nk := get_nakama_session()
	if nakama == null or nk == null:
		ev_request_failed.emit("link_google", "no session")
		return false
	var res: NakamaAsyncResult = await nakama.link_google_async(nk, id_token)
	return _ok_async(res, "link_google")


func link_device_async(device_id: String) -> bool:
	var nk := get_nakama_session()
	if nakama == null or nk == null:
		ev_request_failed.emit("link_device", "no session")
		return false
	var res: NakamaAsyncResult = await nakama.link_device_async(nk, device_id)
	return _ok_async(res, "link_device")


func link_steam_async(session_ticket: String) -> bool:
	var nk := get_nakama_session()
	if nakama == null or nk == null:
		ev_request_failed.emit("link_steam", "no session")
		return false
	var res: NakamaAsyncResult = await nakama.link_steam_async(nk, session_ticket, false)
	return _ok_async(res, "link_steam")


func link_yandex_async(player_id: String, signature: String = "") -> bool:
	var nk := get_nakama_session()
	if nakama == null or nk == null:
		ev_request_failed.emit("link_yandex", "no session")
		return false
	var custom_id := player_id if player_id.begins_with("yandex_") else "yandex_%s" % player_id
	# SDK link_custom has no vars helper — authenticate path carries signature when needed.
	var res: NakamaAsyncResult = await nakama.link_custom_async(nk, custom_id)
	if res != null and res.is_exception() and not signature.is_empty():
		ev_request_failed.emit("link_yandex", "link_custom with signature requires server support; try authenticate")
	return _ok_async(res, "link_yandex")


func rpc_async(rpc_id: String, payload: Dictionary = {}) -> Dictionary:
	var nk := get_nakama_session()
	if nakama == null or nk == null:
		ev_request_failed.emit(rpc_id, "no session")
		return {}
	var raw_payload = null if payload.is_empty() else JSON.stringify(payload)
	var result = await nakama.rpc_async(nk, rpc_id, raw_payload)
	if result == null:
		ev_request_failed.emit(rpc_id, "null rpc result")
		return {}
	if result.is_exception():
		var ex = result.get_exception()
		ev_request_failed.emit(rpc_id, str(ex.message) if ex else "rpc failed")
		return {}
	var text := str(result.payload) if result.payload != null else ""
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func health_ext_async() -> Dictionary:
	return await rpc_async("health_ext")


func get_account_view_async() -> Dictionary:
	return await rpc_async("get_account_view")


func link_status_async() -> Dictionary:
	return await rpc_async("link_status")


func progress_pull_async() -> Dictionary:
	return await rpc_async("progress_pull")


func progress_push_async(progress: Dictionary) -> Dictionary:
	return await rpc_async("progress_push", {"progress": progress})


func progress_merge_async(progress: Dictionary) -> Dictionary:
	return await rpc_async("progress_merge", {"progress": progress})


func submit_match_result_async(result: Dictionary) -> Dictionary:
	return await rpc_async("submit_match_result", result)


func leaderboard_top_async(limit: int = 10, cursor: String = "") -> Dictionary:
	var body: Dictionary = {"limit": limit}
	if not cursor.is_empty():
		body["cursor"] = cursor
	return await rpc_async("leaderboard_top", body)


func room_create_async(region: String = "any") -> Dictionary:
	return await rpc_async("room_create", {"region": region})


func room_join_async(code: String) -> Dictionary:
	return await rpc_async("room_join", {"code": code})


func room_close_async(code: String) -> Dictionary:
	return await rpc_async("room_close", {"code": code})


func mm_enqueue_async(skill: int = 0, region: String = "any") -> Dictionary:
	return await rpc_async("mm_enqueue", {"skill": skill, "region": region})


func mm_status_async(ticket_id: String) -> Dictionary:
	return await rpc_async("mm_status", {"ticket_id": ticket_id})


func mm_cancel_async(ticket_id: String) -> Dictionary:
	return await rpc_async("mm_cancel", {"ticket_id": ticket_id})


func _store_session(nk: NakamaSession, p_platform_id: String) -> OnlineSession:
	if nk == null or nk.is_exception() or not nk.valid:
		var msg := "auth failed"
		if nk != null and nk.is_exception():
			var ex = nk.get_exception()
			msg = str(ex.message) if ex else msg
		ev_request_failed.emit("authenticate", msg)
		session = null
		return null
	platform_id = p_platform_id
	session = OnlineSession.from_nakama(nk, p_platform_id)
	return session


func _ok_async(res: NakamaAsyncResult, op: String) -> bool:
	if res == null:
		ev_request_failed.emit(op, "null result")
		return false
	if res.is_exception():
		var ex = res.get_exception()
		ev_request_failed.emit(op, str(ex.message) if ex else "failed")
		return false
	return true
