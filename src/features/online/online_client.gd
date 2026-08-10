class_name OnlineClient
extends RefCounted

## Minimal Nakama HTTP client for Phase 1 (auth + RPC). Realtime bridge comes later.

signal ev_request_failed(operation: String, message: String)

var config: OnlineConfig
var session: OnlineSession

var _http: HTTPRequest
var _busy: bool = false


func setup(host_node: Node, p_config: OnlineConfig) -> void:
	config = p_config
	if _http != null and is_instance_valid(_http):
		_http.queue_free()
	_http = HTTPRequest.new()
	_http.timeout = p_config.request_timeout_sec
	host_node.add_child(_http)


func has_session() -> bool:
	return session != null and session.is_valid()


func authenticate_device_async(device_id: String, create: bool = true) -> OnlineSession:
	var path := "/v2/account/authenticate/device?create=%s" % ("true" if create else "false")
	var body := {"id": device_id}
	var data := await _request_json("POST", path, body, false)
	session = OnlineSession.from_auth_payload(data, "device")
	return session


func authenticate_google_async(id_token: String, create: bool = true) -> OnlineSession:
	var path := "/v2/account/authenticate/google?create=%s" % ("true" if create else "false")
	var data := await _request_json("POST", path, {"token": id_token}, false)
	session = OnlineSession.from_auth_payload(data, "google")
	return session


func authenticate_steam_async(session_ticket: String, create: bool = true) -> OnlineSession:
	var path := "/v2/account/authenticate/steam?create=%s&import=false" % ("true" if create else "false")
	var data := await _request_json("POST", path, {"token": session_ticket}, false)
	session = OnlineSession.from_auth_payload(data, "steam")
	return session


func authenticate_yandex_async(player_id: String, signature: String = "", create: bool = true) -> OnlineSession:
	var path := "/v2/account/authenticate/custom?create=%s" % ("true" if create else "false")
	var custom_id := player_id if player_id.begins_with("yandex_") else "yandex_%s" % player_id
	var body: Dictionary = {"id": custom_id}
	if not signature.is_empty():
		body["vars"] = {"yandex_signature": signature}
	var data := await _request_json("POST", path, body, false)
	session = OnlineSession.from_auth_payload(data, "yandex")
	return session


func link_google_async(id_token: String) -> void:
	await _request_json("POST", "/v2/account/link/google", {"token": id_token}, true)


func link_device_async(device_id: String) -> void:
	await _request_json("POST", "/v2/account/link/device", {"id": device_id}, true)


func link_steam_async(session_ticket: String) -> void:
	await _request_json("POST", "/v2/account/link/steam?import=false", {"token": session_ticket}, true)


func link_yandex_async(player_id: String, signature: String = "") -> void:
	var custom_id := player_id if player_id.begins_with("yandex_") else "yandex_%s" % player_id
	var body: Dictionary = {"id": custom_id}
	if not signature.is_empty():
		body["vars"] = {"yandex_signature": signature}
	await _request_json("POST", "/v2/account/link/custom", body, true)


func rpc_async(rpc_id: String, payload: Dictionary = {}) -> Dictionary:
	var path := "/v2/rpc/%s?unwrap" % rpc_id
	var raw := await _request_json("POST", path, payload, true, true)
	if raw.has("payload") and typeof(raw["payload"]) == TYPE_STRING:
		var inner: Variant = JSON.parse_string(str(raw["payload"]))
		if typeof(inner) == TYPE_DICTIONARY:
			return inner
	return raw


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


func _request_json(method: String, path: String, body: Dictionary, use_session: bool, rpc_envelope: bool = false) -> Dictionary:
	if _http == null:
		ev_request_failed.emit(path, "OnlineClient not setup")
		return {}
	if _busy:
		ev_request_failed.emit(path, "request already in flight")
		return {}
	_busy = true

	var url := config.base_url() + path
	var headers := PackedStringArray(["Content-Type: application/json"])
	if use_session:
		if session == null or session.token.is_empty():
			_busy = false
			ev_request_failed.emit(path, "no session")
			return {}
		headers.append("Authorization: Bearer %s" % session.token)
	else:
		var basic := Marshalls.utf8_to_base64("%s:" % config.server_key)
		headers.append("Authorization: Basic %s" % basic)

	# Auth endpoints want a JSON object; RPC wants a JSON-encoded string payload.
	var payload: String
	if rpc_envelope:
		payload = JSON.stringify(JSON.stringify(body))
	else:
		payload = JSON.stringify(body)
	var err := _http.request(url, headers, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET, payload)
	if err != OK:
		_busy = false
		ev_request_failed.emit(path, "HTTPRequest error %s" % err)
		return {}

	var args: Array = await _http.request_completed
	_busy = false
	var result: int = args[0]
	var response_code: int = args[1]
	var response_body: PackedByteArray = args[3]
	var text := response_body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		ev_request_failed.emit(path, "transport result %s" % result)
		return {}
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else {}
	if response_code < 200 or response_code >= 300:
		var msg := text
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("message"):
			msg = str(parsed["message"])
		ev_request_failed.emit(path, "HTTP %s: %s" % [response_code, msg])
		return {}
	if typeof(parsed) != TYPE_DICTIONARY:
		# unwrap may return a bare JSON value; normalize
		if typeof(parsed) == TYPE_NIL and text.strip_edges().begins_with("{"):
			return {}
		if rpc_envelope and typeof(parsed) == TYPE_DICTIONARY:
			return parsed
		return {}
	return parsed
