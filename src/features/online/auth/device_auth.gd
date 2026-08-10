class_name DeviceAuth
extends PlatformAuth

## Guest / device identity — works offline-first boot then sync when online.
## Device id is persisted under user:// so reinstalls may reset (expected for guest).

const DEVICE_ID_PATH := "user://online_device_id.txt"


func get_platform_id() -> String:
	return "device"


func authenticate_async() -> OnlineSession:
	if client == null:
		await _yield_frame()
		return null
	var device_id := _load_or_create_device_id()
	return await client.authenticate_device_async(device_id, true)


func link_async() -> bool:
	if client == null or not client.has_session():
		await _yield_frame()
		return false
	var device_id := _load_or_create_device_id()
	await client.link_device_async(device_id)
	return client.has_session()


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
