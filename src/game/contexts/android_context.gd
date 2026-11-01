class_name AndroidContext
extends PlatformContext

## Android: touch only, no local 2P. Store / services come in later iterations.


func _enter() -> void:
	if platform_caps != null:
		platform_caps.local_multiplayer = false
