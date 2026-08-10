class_name DesktopContext
extends HfsmBoundEntity

## Platform context for desktop (non-web, non-Steam) builds.


func on_event(event_name: String, _data: Dictionary) -> void:
	if event_name != "ev.open_desktop":
		return
