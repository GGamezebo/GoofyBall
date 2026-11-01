class_name Hud
extends CanvasLayer

## Match HUD (concept/ui-match): score on top, pause button, big "ОЧКО!" flash, status line,
## pause menu, touch controls and the net overlay. Listens to GameEvents; talks back only
## through GameEvents (pause / resume / exit requests).

@export var game_events: GameEvents
@export var palette: TeamPalette
@export var score_labels: Array[Label] = []
@export var name_labels: Array[Label] = []
@export var point_label: Label
@export var point_sub_label: Label
@export var status_label: Label
@export var pause_button: Button
@export var pause_overlay: Control
@export var resume_button: Button
@export var exit_button: Button
@export var pause_note: Label
@export var virtual_controls: VirtualControls
@export var net_overlay: NetOverlay

var _listener := EventListener.new()
var _info: Dictionary = {}
var _point_tween: Tween


func initialize() -> void:
	_listener.add(game_events.ev_match_started, _on_match_started)
	_listener.add(game_events.ev_score_changed, _on_score_changed)
	_listener.add(game_events.ev_point, _on_point)
	_listener.add(game_events.ev_match_over, _on_match_over)
	_listener.add(game_events.ev_status, _on_status)
	_listener.add(pause_button.pressed, _open_pause)
	_listener.add(resume_button.pressed, _close_pause)
	_listener.add(exit_button.pressed, func() -> void: game_events.ev_exit_requested.emit())
	pause_overlay.visible = false
	point_label.visible = false
	point_sub_label.visible = false
	status_label.visible = false


func deinit() -> void:
	_listener.deinit()
	virtual_controls.release_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_overlay.visible:
			_close_pause()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()


func _open_pause() -> void:
	if pause_overlay.visible:
		return
	virtual_controls.release_all()
	pause_note.text = "Онлайн: это просто меню, матч идёт." if bool(_info.get("online", false)) else "Игра на паузе."
	pause_overlay.visible = true
	resume_button.grab_focus()
	game_events.ev_pause_requested.emit()


func _close_pause() -> void:
	if not pause_overlay.visible:
		return
	pause_overlay.visible = false
	game_events.ev_resume_requested.emit()


func _on_match_started(info: Dictionary) -> void:
	_info = info
	var names: Array = info.get("team_names", [])
	for team in score_labels.size():
		var color := palette.color(team)
		score_labels[team].add_theme_color_override("font_color", color)
		score_labels[team].text = "0"
		if team < name_labels.size():
			name_labels[team].add_theme_color_override("font_color", color.lightened(0.3))
			name_labels[team].text = str(names[team]) if team < names.size() else ""


func _on_score_changed(scores: Array) -> void:
	for team in mini(scores.size(), score_labels.size()):
		score_labels[team].text = str(scores[team])


func _on_point(team: int, reason: int) -> void:
	var sub := "Больше трёх касаний" if reason == VolleySim.Reason.TOUCHES else ""
	_flash("ОЧКО!", palette.color(team), sub, 0.9)


func _on_match_over(winner_team: int) -> void:
	var local_teams: Array = _info.get("local_teams", [])
	var names: Array = _info.get("team_names", [])
	var text := ""
	if local_teams.size() == 1:
		text = "ПОБЕДА!" if local_teams.has(winner_team) else "ПОРАЖЕНИЕ"
	else:
		text = "%s победил!" % (str(names[winner_team]) if winner_team < names.size() else "")
	_flash(text, palette.color(winner_team) if text != "ПОБЕДА!" else Color("#FFD20A"), "", 3.0)


func _on_status(text: String) -> void:
	status_label.text = text
	status_label.visible = not text.is_empty()


func _flash(text: String, color: Color, sub: String, hold_sec: float) -> void:
	point_label.text = text
	point_label.add_theme_color_override("font_color", color)
	point_label.visible = true
	point_label.modulate.a = 1.0
	point_label.scale = Vector2(0.6, 0.6)
	point_sub_label.text = sub
	point_sub_label.visible = not sub.is_empty()
	point_sub_label.modulate.a = 1.0
	if _point_tween:
		_point_tween.kill()
	_point_tween = create_tween()
	_point_tween.tween_property(point_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_point_tween.tween_interval(hold_sec)
	_point_tween.tween_property(point_label, "modulate:a", 0.0, 0.25)
	_point_tween.parallel().tween_property(point_sub_label, "modulate:a", 0.0, 0.25)
