class_name OnlineClient
extends RefCounted

## Thin wrapper over the Nakama client: silent guest sign-in by device id and JSON RPCs.
## `nakama_node` is the addon's `Nakama.gd` placed in the scene (no autoload).

const DEVICE_ID_PATH := "user://device_id%s.txt"

var nakama: NakamaClient
var session: NakamaSession
var last_error: String = ""


func setup(nakama_node: Node, config: OnlineConfig) -> void:
	nakama = nakama_node.create_client(config.server_key, config.host, config.port, config.scheme(),
		config.timeout_sec, NakamaLogger.LOG_LEVEL.WARNING)
	# One quick retry is enough for a room screen; the default backoff waits ~30 s on a dead server.
	nakama.auto_retry_count = 1


func is_signed_in() -> bool:
	return session != null and session.valid and not session.is_expired()


## `profile` separates several game copies on one PC (`-- --profile=2`).
func sign_in_async(profile: String) -> bool:
	if is_signed_in():
		return true
	var result: NakamaSession = await nakama.authenticate_device_async(device_id(profile), null, true)
	if result == null or result.is_exception():
		last_error = str(result.get_exception().message) if result != null else "no response"
		session = null
		return false
	session = result
	return true


func rpc_async(rpc_id: String, payload: Dictionary) -> Dictionary:
	if not is_signed_in():
		last_error = "not signed in"
		return {}
	var result = await nakama.rpc_async(session, rpc_id, JSON.stringify(payload))
	if result == null or result.is_exception():
		last_error = str(result.get_exception().message) if result != null else "no response"
		return {}
	var parsed: Variant = JSON.parse_string(str(result.payload)) if result.payload != null else null
	if parsed is Dictionary:
		return parsed
	last_error = "bad payload"
	return {}


static func device_id(profile: String) -> String:
	var path := DEVICE_ID_PATH % ("" if profile.is_empty() else "_" + profile)
	if FileAccess.file_exists(path):
		var existing := FileAccess.get_file_as_string(path).strip_edges()
		if existing.length() >= 16:
			return existing
	var id := "gb_" + Crypto.new().generate_random_bytes(16).hex_encode()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(id)
	return id
