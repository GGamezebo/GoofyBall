class_name WEBContext
extends HfsmBoundEntity

## Platform context for HTML5 / web builds.
## If this is a Yandex Games host, raises nested YandexGames state.


func on_event(event_name: String, _data: Dictionary) -> void:
	if event_name != "ev.open_web":
		return
	if OS.has_feature("yandex_games") or OS.has_feature("yandex"):
		add_event("ev.open_yandex_games")
