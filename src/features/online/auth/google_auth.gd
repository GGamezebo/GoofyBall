class_name GoogleAuth
extends PlatformAuth

## Google Sign-In / Play for Android and Google Identity for HTML.
## Phase 1: token is injected (from SDK / JS bridge). Without token → cannot auth.

var _variant: String = "google_android"
var _id_token: String = ""


func _init(p_client: OnlineClient = null, variant: String = "google_android") -> void:
	super._init(p_client)
	_variant = variant


func get_platform_id() -> String:
	return _variant


func set_id_token(token: String) -> void:
	_id_token = token.strip_edges()


func can_authenticate() -> bool:
	return not _id_token.is_empty()


func authenticate_async() -> OnlineSession:
	if client == null or not can_authenticate():
		await _yield_frame()
		return null
	return await client.authenticate_google_async(_id_token, true)


func link_async() -> bool:
	if client == null or not client.has_session() or not can_authenticate():
		await _yield_frame()
		return false
	await client.link_google_async(_id_token)
	return true
