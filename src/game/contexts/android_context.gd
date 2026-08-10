class_name AndroidContext
extends HfsmBoundEntity

## Platform context for Android / Google Play builds.


func on_event(event_name: String, _data: Dictionary) -> void:
	if event_name != "ev.open_android":
		return
