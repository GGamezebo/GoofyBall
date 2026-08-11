class_name DeviceAuth
extends PlatformAuth

## Guest / device identity — works offline-first boot then sync when online.
## Default: persist under user://. Dev presets: set_dev_account() from Menu.

const DEVICE_ID_PATH := "user://online_device_id.txt"

var _override_device_id: String = ""
var _override_username: String = ""


func get_platform_id() -> String:
	return "device"


## Use a fixed DevAccounts entry (unique device_id → unique Nakama user).
func set_dev_account(device_id: String, username: String = "") -> void:
	_override_device_id = device_id.strip_edges()
	_override_username = username.strip_edges()


func clear_dev_account() -> void:
	_override_device_id = ""
	_override_username = ""


func authenticate_async() -> OnlineSession:
	if client == null:
		await _yield_frame()
		return null
	var device_id := _resolve_device_id()
	if _override_username.is_empty():
		return await client.authenticate_device_async(device_id, true, null)
	return await client.authenticate_device_async(device_id, true, _override_username)


func link_async() -> bool:
	if client == null or not client.has_session():
		await _yield_frame()
		return false
	var device_id := _resolve_device_id()
	return await client.link_device_async(device_id)


func _resolve_device_id() -> String:
	if not _override_device_id.is_empty():
		return _override_device_id
	return _load_or_create_device_id()


func _load_or_create_device_id() -> String:
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var existing := FileAccess.get_file_as_string(DEVICE_ID_PATH).strip_edges()
		if existing.length() >= 16:
			return existing
	var id := "gd_%s_%s" % [OS.get_unique_id().replace("{", "").replace("}", ""), str(Time.get_unix_time_from_system())]
	id = id.replace("-", "").replace(" ", "")
	if id.length() < 16:
		id = "gd_%s" % str(Time.get_unix_time_from_system()) + str(randi())
	var f := FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
	if f:
		f.store_string(id)
	return id
