class_name OnlineSession
extends RefCounted

## Nakama session tokens. Opaque to gameplay — only OnlineClient / auth use this.

var user_id: String = ""
var username: String = ""
var token: String = ""
var refresh_token: String = ""
var expires_at_unix: int = 0
var platform_id: String = ""


func is_valid() -> bool:
	if token.is_empty() or user_id.is_empty():
		return false
	if expires_at_unix <= 0:
		return true
	return Time.get_unix_time_from_system() < expires_at_unix - 30


static func from_auth_payload(data: Dictionary, p_platform_id: String = "") -> OnlineSession:
	var s := OnlineSession.new()
	s.token = str(data.get("token", ""))
	s.refresh_token = str(data.get("refresh_token", ""))
	s.user_id = _user_id_from_jwt(s.token)
	s.username = ""
	s.expires_at_unix = int(data.get("expires", 0))
	s.platform_id = p_platform_id
	return s


static func _user_id_from_jwt(jwt: String) -> String:
	var parts := jwt.split(".")
	if parts.size() < 2:
		return ""
	var payload_b64 := parts[1]
	# JWT uses URL-safe base64 without padding.
	while payload_b64.length() % 4 != 0:
		payload_b64 += "="
	payload_b64 = payload_b64.replace("-", "+").replace("_", "/")
	var json_bytes := Marshalls.base64_to_raw(payload_b64)
	var parsed: Variant = JSON.parse_string(json_bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = parsed
	return str(d.get("uid", d.get("user_id", "")))
