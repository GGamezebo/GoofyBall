class_name WEBContext
extends PlatformContext

## Web build (later iteration). Kept so the router has a branch for every platform.


func _enter() -> void:
	if platform_caps != null:
		platform_caps.local_multiplayer = false
