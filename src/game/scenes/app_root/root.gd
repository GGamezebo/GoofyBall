extends IScene

## App root context: bridges RootEvents into HFSM events and opens the parallel
## Platform and Online states. Holds no gameplay.

@export var root_events: RootEvents
@export var platform_caps: PlatformCaps
@export var log_settings: LogSettings

var _listener := EventListener.new()
var _log: LogChannel


func initialize(_data: Dictionary) -> void:
	_log = LogChannel.new("app", log_settings)
	_log.info("start", {
		"version": ProjectSettings.get_setting("application/config/version", "dev"),
		"os": OS.get_name(),
		"debug": OS.is_debug_build(),
	})
	_listener.add(root_events.ev_start_game, _on_start_game)
	_listener.add(root_events.ev_exit_game, _on_exit_game)
	_listener.add(root_events.ev_return_to_menu, _on_return_to_menu)
	# The platform branch is picked inside App/Platform (PlatformRouterContext), never here.
	add_event("ev.open_platform", {"platform_caps": platform_caps, "root_events": root_events})
	add_event("ev.open_online")


func deinit() -> void:
	_listener.deinit()
	super.deinit()


func on_event(event_name: String, _data: Dictionary) -> void:
	if _log != null and event_name.begins_with("ev."):
		_log.debug("hfsm_event", {"event": event_name, "path": "/".join(_hfsm.get_active_path()) if _hfsm else ""})


func _on_start_game(data: Dictionary) -> void:
	_log.info("start_game")
	add_event("ev.start_game", data.duplicate())


func _on_exit_game(data: Dictionary) -> void:
	_log.info("exit_game", {"winner": data.get("winner_team", -1), "aborted": data.get("aborted", false)})
	add_event("ev.exit_game", data)


func _on_return_to_menu(data: Dictionary) -> void:
	_log.info("return_to_menu")
	add_event("ev.open_menu", data)
