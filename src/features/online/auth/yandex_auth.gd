class_name YandexAuth
extends PlatformAuth

## Yandex Games → Nakama custom auth (server beforeAuthenticateCustom).
## Dev: player id only (YANDEX_AUTH_MODE=dev). Prod: requires signature var.

var _player_id: String = ""
var _signature: String = ""


func get_platform_id() -> String:
	return "yandex"


func set_player_credentials(player_id: String, signature: String = "") -> void:
	_player_id = player_id.strip_edges()
	_signature = signature.strip_edges()


func can_authenticate() -> bool:
	return not _player_id.is_empty()


func authenticate_async() -> OnlineSession:
	if client == null or not can_authenticate():
		await _yield_frame()
		return null
	return await client.authenticate_yandex_async(_player_id, _signature, true)


func link_async() -> bool:
	if client == null or not client.has_session() or not can_authenticate():
		await _yield_frame()
		return false
	await client.link_yandex_async(_player_id, _signature)
	return true
