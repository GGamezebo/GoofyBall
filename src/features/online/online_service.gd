class_name OnlineService
extends Node

## Optional online identity + realtime host. Safe defaults: no auto-login.
## Does not block offline AI / local 2P — call authenticate / join explicitly.

signal ev_authenticated(session: OnlineSession)
signal ev_account_view(view: Dictionary)
signal ev_auth_failed(message: String)
signal ev_progress_synced(progress: Dictionary)
signal ev_match_result_submitted(result: Dictionary)
signal ev_room(result: Dictionary)
signal ev_matchmaker(result: Dictionary)
signal ev_match_joined(match_id: String)
signal ev_match_join_failed(message: String)
signal ev_peer_connected(peer_id: int)
signal ev_peer_disconnected(peer_id: int)
signal ev_ready

@export var config: OnlineConfig
## Optional — when set, merge cloud progress into this PData after auth / sync.
@export var pdata: PData
## Auto socket+join after room/mm success (default on).
@export var auto_join_realtime: bool = true

var client: OnlineClient
var realtime: OnlineRealtime
var last_account_view: Dictionary = {}
var last_progress: Dictionary = {}

var _auth: PlatformAuth
var _sync_busy: bool = false


func _ready() -> void:
	if config == null:
		config = OnlineConfig.new()
	client = OnlineClient.new()
	client.setup(self, config)
	client.ev_request_failed.connect(_on_request_failed)
	realtime = OnlineRealtime.new()
	realtime.name = "OnlineRealtime"
	add_child(realtime)
	realtime.setup(client)
	realtime.ev_match_joined.connect(func(id: String): ev_match_joined.emit(id))
	realtime.ev_match_join_failed.connect(func(msg: String): ev_match_join_failed.emit(msg))
	realtime.ev_peer_connected.connect(func(id: int): ev_peer_connected.emit(id))
	realtime.ev_peer_disconnected.connect(func(id: int): ev_peer_disconnected.emit(id))
	_auth = PlatformAuthFactory.create(client, config.preferred_platform)
	ev_ready.emit()
	if config.auto_authenticate_on_ready:
		authenticate_guest_async()


func get_platform_id() -> String:
	if _auth == null:
		return "device"
	return _auth.get_platform_id()


func authenticate_guest_async(dev_account_index: int = -1) -> OnlineSession:
	var device := PlatformAuthFactory.create_device(client)
	if dev_account_index >= 0:
		device.set_dev_account(
			DevAccounts.device_id(dev_account_index),
			DevAccounts.username(dev_account_index)
		)
	var session := await device.authenticate_async()
	if session == null or not session.is_valid():
		ev_auth_failed.emit("device auth failed")
		return null
	ev_authenticated.emit(session)
	await refresh_account_view_async()
	await sync_progress_async()
	return session


func authenticate_preferred_async() -> OnlineSession:
	if _auth == null:
		return await authenticate_guest_async()
	if _auth.get_platform_id() == "device":
		return await authenticate_guest_async()
	if not _auth.can_authenticate():
		return await authenticate_guest_async()
	@warning_ignore("redundant_await")
	var session := await _auth.authenticate_async()
	if session == null or not session.is_valid():
		ev_auth_failed.emit("%s auth failed" % _auth.get_platform_id())
		return null
	ev_authenticated.emit(session)
	await refresh_account_view_async()
	await sync_progress_async()
	return session


func link_provider_async(provider: PlatformAuth) -> bool:
	if client == null or not client.has_session():
		ev_auth_failed.emit("link requires session")
		return false
	if provider == null or not provider.can_link():
		ev_auth_failed.emit("provider cannot link")
		return false
	provider.client = client
	@warning_ignore("redundant_await")
	var ok := await provider.link_async()
	if ok:
		await refresh_account_view_async()
	return ok


func refresh_account_view_async() -> Dictionary:
	if client == null or not client.has_session():
		return {}
	last_account_view = await client.get_account_view_async()
	if not last_account_view.is_empty():
		ev_account_view.emit(last_account_view)
	return last_account_view


func health_ext_async() -> Dictionary:
	if client == null or not client.has_session():
		return {}
	return await client.health_ext_async()


func sync_progress_async(local_override: Dictionary = {}) -> Dictionary:
	if client == null or not client.has_session():
		return {}
	if _sync_busy:
		return last_progress
	_sync_busy = true
	var local_blob: Dictionary
	if not local_override.is_empty():
		local_blob = OnlineProgress.sanitize(local_override)
	elif pdata != null:
		local_blob = OnlineProgress.wrap_pdata(pdata)
	else:
		local_blob = OnlineProgress.sanitize({})
	var result := await client.progress_merge_async(local_blob)
	_sync_busy = false
	if result.is_empty() or not bool(result.get("ok", false)):
		return {}
	var merged: Dictionary = result.get("progress", {})
	if typeof(merged) != TYPE_DICTIONARY:
		return {}
	last_progress = merged
	if pdata != null:
		OnlineProgress.apply_to_pdata(pdata, merged)
	ev_progress_synced.emit(merged)
	return merged


func push_progress_after_local_save() -> void:
	if client == null or not client.has_session() or pdata == null:
		return
	sync_progress_async()


func submit_match_result_async(result: Dictionary) -> Dictionary:
	if client == null or not client.has_session():
		return {}
	var response := await client.submit_match_result_async(result)
	if response.is_empty():
		return {}
	if bool(response.get("ok", false)):
		var progress: Dictionary = response.get("progress", {})
		if typeof(progress) == TYPE_DICTIONARY and not progress.is_empty() and pdata != null:
			OnlineProgress.apply_to_pdata(pdata, OnlineProgress.merge(OnlineProgress.wrap_pdata(pdata), progress))
		ev_match_result_submitted.emit(response)
	return response


func fetch_leaderboard_top_async(limit: int = 10) -> Dictionary:
	if client == null or not client.has_session():
		return {}
	return await client.leaderboard_top_async(limit)


func connect_realtime_async() -> bool:
	if client == null or not client.has_session() or realtime == null:
		return false
	return await realtime.connect_socket_async()


## Join relayed match by name (preferred for rooms / mm).
func join_realtime_match_async(match_name: String) -> bool:
	if match_name.strip_edges().is_empty():
		return false
	if not await connect_realtime_async():
		return false
	return await realtime.join_named_match_async(match_name)


func leave_realtime_match_async() -> void:
	if realtime:
		await realtime.leave_match_async()


func room_create_async(region: String = "any") -> Dictionary:
	if client == null or not client.has_session():
		return {}
	var result := await client.room_create_async(region)
	if not result.is_empty():
		ev_room.emit(result)
		if auto_join_realtime and bool(result.get("ok", false)):
			await _auto_join_from_lobby(result)
	return result


func room_join_async(code: String) -> Dictionary:
	if client == null or not client.has_session():
		return {}
	var result := await client.room_join_async(code)
	if not result.is_empty():
		ev_room.emit(result)
		if auto_join_realtime and bool(result.get("ok", false)):
			await _auto_join_from_lobby(result)
	return result


func room_close_async(code: String) -> Dictionary:
	if client == null or not client.has_session():
		return {}
	var result := await client.room_close_async(code)
	if not result.is_empty():
		ev_room.emit(result)
	return result


func mm_enqueue_async(skill: int = 0, region: String = "any") -> Dictionary:
	if client == null or not client.has_session():
		return {}
	var result := await client.mm_enqueue_async(skill, region)
	if not result.is_empty():
		ev_matchmaker.emit(result)
		if (
			auto_join_realtime
			and bool(result.get("ok", false))
			and str(result.get("status", "")) == "matched"
		):
			await _auto_join_from_lobby(result)
	return result


func mm_status_async(ticket_id: String) -> Dictionary:
	if client == null or not client.has_session():
		return {}
	var result := await client.mm_status_async(ticket_id)
	if not result.is_empty():
		ev_matchmaker.emit(result)
		if (
			auto_join_realtime
			and bool(result.get("ok", false))
			and str(result.get("status", "")) == "matched"
		):
			await _auto_join_from_lobby(result)
	return result


func mm_cancel_async(ticket_id: String) -> Dictionary:
	if client == null or not client.has_session():
		return {}
	var result := await client.mm_cancel_async(ticket_id)
	if not result.is_empty():
		ev_matchmaker.emit(result)
	return result


func _auto_join_from_lobby(result: Dictionary) -> void:
	var match_name := str(result.get("match_name", result.get("match_id", "")))
	if match_name.is_empty():
		return
	await join_realtime_match_async(match_name)


func _on_request_failed(operation: String, message: String) -> void:
	push_warning("OnlineClient %s: %s" % [operation, message])
	ev_auth_failed.emit("%s: %s" % [operation, message])


func _exit_tree() -> void:
	if realtime:
		realtime.disconnect_socket()
