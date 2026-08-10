class_name YandexGamesContext
extends HfsmBoundEntity

## Nested under WEB — Yandex Games SDK / custom auth hooks only.


func on_event(event_name: String, _data: Dictionary) -> void:
	if event_name != "ev.open_yandex_games":
		return
