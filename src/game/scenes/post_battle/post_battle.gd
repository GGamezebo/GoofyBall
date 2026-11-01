extends IScene

## Results context (concept/ui-results): «ПОБЕДА!» / «ПОРАЖЕНИЕ» (or the winner's name when two
## players share one PC), final score, «↻ Реванш» and «Дальше ›». An online rematch starts when
## both players pressed it (App/Online handles that through OnlineEvents).

@export var root_events: RootEvents
@export var online_events: OnlineEvents
@export var palette: TeamPalette
@export var log_settings: LogSettings
## F6: shown with a fake result built from this setup.
@export var preview_setup: MatchSetup
@export var title_label: Label
@export var score_label: Label
@export var subtitle_label: Label
@export var status_label: Label
@export var rematch_button: Button
@export var next_button: Button
@export var hero_blob: BlobView
@export var hero_radius_px: float = 130.0

var _listener := EventListener.new()
var _log: LogChannel
var _result: Dictionary = {}
var _online: bool = false
var _hero_time: float = 0.0
var _hero_base := Vector2.ZERO


func initialize(data: Dictionary) -> void:
	_log = LogChannel.new("results", log_settings)
	_result = data if data.has("scores") else _preview_result()
	_online = bool(_result.get("online", false))
	_listener.add(rematch_button.pressed, _on_rematch)
	_listener.add(next_button.pressed, _on_next)
	_listener.add(online_events.ev_rematch_status, _set_status)
	_listener.add(online_events.ev_opponent_left, _on_opponent_left)
	_show_result()
	next_button.grab_focus()


func deinit() -> void:
	_listener.deinit()
	super.deinit()


func _process(delta: float) -> void:
	if hero_blob == null:
		return
	_hero_time += delta
	var hop := maxf(0.0, sin(_hero_time * 5.0)) * 30.0
	hero_blob.apply(_hero_base - Vector2(0.0, hop), -cos(_hero_time * 5.0) * 6.0, hop <= 0.5,
		_hero_base.y + hero_radius_px, _hero_base + Vector2(0.0, -400.0), delta)


func _show_result() -> void:
	var scores: Array = _result.get("scores", [0, 0])
	var winner := int(_result.get("winner_team", -1))
	var local_teams: Array = _result.get("local_teams", [])
	var names: Array = _result.get("team_names", [])
	score_label.text = " : ".join(scores.map(func(v): return str(v)))
	subtitle_label.text = ""
	_set_status("")

	var title := ""
	var color := Color("#FFD20A")
	if bool(_result.get("aborted", false)):
		title = "МАТЧ ПРЕРВАН"
		color = Color("#A6B4D2")
		subtitle_label.text = _reason_text(str(_result.get("reason", "")))
		rematch_button.disabled = _online
	elif local_teams.size() == 1:
		var won := local_teams.has(winner)
		title = "ПОБЕДА!" if won else "ПОРАЖЕНИЕ"
		color = Color("#FFD20A") if won else palette.color(1)
	else:
		title = "%s победил!" % (str(names[winner]) if winner >= 0 and winner < names.size() else "")
		color = palette.color(maxi(winner, 0))
	title_label.text = title
	title_label.add_theme_color_override("font_color", color)

	if hero_blob != null:
		var hero_team: int = winner if winner >= 0 else 0
		if local_teams.size() == 1:
			hero_team = int(local_teams[0])
		hero_blob.setup(palette.color(hero_team), hero_radius_px, "", false)
		hero_blob.name_label.visible = false
		_hero_base = hero_blob.position
	_log.info("open", {"winner": winner, "aborted": _result.get("aborted", false), "online": _online})


func _on_rematch() -> void:
	if _online:
		rematch_button.disabled = true
		online_events.ev_rematch_request.emit()
		return
	var setup := (_result.get("match_setup") as MatchSetup)
	if setup == null:
		setup = preview_setup
	var next := setup.duplicate(true) as MatchSetup
	next.match_seed = randi()
	_log.info("rematch_local")
	root_events.ev_start_game.emit({"match_setup": next})


func _on_next() -> void:
	if _online:
		online_events.ev_leave_room.emit()
	root_events.ev_return_to_menu.emit({})


func _on_opponent_left() -> void:
	rematch_button.disabled = true
	_set_status("Соперник вышел из комнаты")


func _set_status(text: String) -> void:
	status_label.text = text
	status_label.visible = not text.is_empty()


func _preview_result() -> Dictionary:
	return {
		"match_setup": preview_setup, "scores": [7, 4], "winner_team": 0, "local_teams": [0],
		"team_names": ["Ты", "Бот"], "online": false, "aborted": false, "reason": "",
	}


static func _reason_text(reason: String) -> String:
	match reason:
		"opponent_left":
			return "Соперник отключился"
		"sync_error":
			return "Связь потеряна"
		"handshake_timeout", "opponent_missing":
			return "Соперник не подключился"
	return "Матч остановлен"
