class_name PlatformAuth
extends RefCounted

## Contract for one-click / guest identity providers.
## Key by Nakama user_id after auth — never invent per-platform save tables.

var client: OnlineClient


func _init(p_client: OnlineClient = null) -> void:
	client = p_client


func get_platform_id() -> String:
	return "device"


func can_authenticate() -> bool:
	return true


func can_link() -> bool:
	return can_authenticate()


## Yield one frame — keeps stubs/overrides as real coroutines for `await` callers.
func _yield_frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		await tree.process_frame
	else:
		await Engine.get_main_loop().process_frame


## Returns OnlineSession or null on failure.
func authenticate_async() -> OnlineSession:
	await _yield_frame()
	return null


## Link this provider onto the current session. Returns true on success.
func link_async() -> bool:
	await _yield_frame()
	return false
