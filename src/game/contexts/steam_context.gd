class_name SteamContext
extends HfsmBoundEntity

## Platform context for Steam builds.


func on_event(event_name: String, _data: Dictionary) -> void:
	if event_name != "ev.open_steam":
		return
