class_name DesktopContext
extends PlatformContext

## PC (Windows / Linux / macOS): keyboard + gamepads, so two players fit on one computer.


func _enter() -> void:
	if platform_caps != null:
		platform_caps.local_multiplayer = true
