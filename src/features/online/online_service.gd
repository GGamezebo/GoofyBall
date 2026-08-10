class_name OnlineService
extends Node

## Optional online identity host. Safe defaults: no auto-login unless configured.
## Does not block offline AI / local 2P — call authenticate explicitly from menu later.

signal ev_authenticated(session: OnlineSession)
signal ev_account_view(view: Dictionary)
signal ev_auth_failed(message: String)
signal ev_ready

@export var config: OnlineConfig

var client: OnlineClient
var last_account_view: Dictionary = {}

var _auth: PlatformAuth


func _ready() -> void:
	if config == null:
		config = OnlineConfig.new()
	client = OnlineClient.new()
	client.setup(self, config)
	client.ev_request_failed.connect(_on_request_failed)
	_auth = PlatformAuthFactory.create(client, config.preferred_platform)
	ev_ready.emit()
	if config.auto_authenticate_on_ready:
		authenticate_guest_async()


func get_platform_id() -> String:
	if _auth == null:
		return "device"
	return _auth.get_platform_id()


func authenticate_guest_async() -> OnlineSession:
	var device := PlatformAuthFactory.create_device(client)
	var session := await device.authenticate_async()
	if session == null or not session.is_valid():
		ev_auth_failed.emit("device auth failed")
		return null
	ev_authenticated.emit(session)
	await refresh_account_view_async()
	return session


func authenticate_preferred_async() -> OnlineSession:
	if _auth == null:
		return await authenticate_guest_async()
	if _auth.get_platform_id() == "device":
		return await authenticate_guest_async()
	if not _auth.can_authenticate():
		# Fall back to guest so boot never hard-fails without SDK tokens.
		return await authenticate_guest_async()
	@warning_ignore("redundant_await")
	var session := await _auth.authenticate_async()
	if session == null or not session.is_valid():
		ev_auth_failed.emit("%s auth failed" % _auth.get_platform_id())
		return null
	ev_authenticated.emit(session)
	await refresh_account_view_async()
	return session


func link_provider_async(provider: PlatformAuth) -> bool:
	if client == null or not client.has_session():
		ev_auth_failed.emit("link requires session")
		return false
	if provider == null or not provider.can_link():
		ev_auth_failed.emit("provider cannot link")
		return false
	provider.client = client
	# Polymorphic PlatformAuth.await: analyzer may still flag; overrides are coroutines.
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


func _on_request_failed(operation: String, message: String) -> void:
	push_warning("OnlineClient %s: %s" % [operation, message])
	ev_auth_failed.emit("%s: %s" % [operation, message])
