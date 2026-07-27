extends IScene

@export var game_config: GameConfig
@export var root_events: RootEvents
@export var game_events: GameEvents
@export var game_manager: GameManager
@export var match_controller: MatchController
@export var ai_opponent: AiOpponent
@export var score_label: Label
@export var message_label: Label
@export var hint_label: Label
@export var timer_label: Label

var _listener: EventListener = EventListener.new()
var _flash_tween: Tween
var _flash_mat: StandardMaterial3D
var _timer_pulse_tween: Tween

@onready var _flash_left: MeshInstance3D = get_node_or_null("Court/FloorFlashLeft")
@onready var _flash_right: MeshInstance3D = get_node_or_null("Court/FloorFlashRight")


func _ready() -> void:
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.look_at(Vector3(0.0, 2.5, 0.0), Vector3.UP)
		await get_tree().process_frame
		_align_ceiling_to_screen_top(cam)


func initialize(data: Dictionary) -> void:
	var scenario: GameConfig = data.get("custom_battle") as GameConfig
	if scenario:
		ResourceUtils.update_resource(game_config, scenario)

	match_controller.initialize(game_config)
	game_manager.initialize(game_config, match_controller)

	var right := match_controller.player_right as BlobPlayer
	var ball := match_controller.ball
	if ai_opponent:
		ai_opponent.setup(right, ball, game_config.vs_ai)

	if hint_label:
		if game_config.vs_ai:
			hint_label.text = "You: stick/D-pad + A jump (or A/D+W / touch)   |   AI (Red)   |   Esc — menu"
		else:
			hint_label.text = "Blue: pad0 stick+A (or A/D+W / touch)   |   Red: pad1 stick+A (or ←/→+↑)   |   Esc — menu"

	_listener.add(game_events.ev_score_changed, _on_score)
	_listener.add(game_events.ev_message, _on_message)
	_listener.add(game_events.ev_match_over, _on_match_over)
	_listener.add(game_events.ev_point_scored, _on_point_scored)
	_listener.add(game_events.ev_round_time_changed, _on_round_time)

	root_events.ev_battle_started.emit()
	_on_score(0, 0)
	_on_round_time(int(game_config.round_duration_sec) if game_config else 60)


func deinit() -> void:
	_listener.deinit()
	root_events.ev_battle_finished.emit()
	super.deinit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		root_events.ev_return_to_menu.emit({})
		get_viewport().set_input_as_handled()


func _on_score(score_left: int, score_right: int) -> void:
	if score_label:
		score_label.text = "%d  :  %d" % [score_left, score_right]


func _on_message(text: String) -> void:
	if message_label:
		message_label.text = text


func _on_round_time(seconds_left: int) -> void:
	if timer_label == null:
		return
	timer_label.text = str(seconds_left)
	var alarm := seconds_left <= 5 and seconds_left > 0
	if alarm:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.2, 1.0))
		timer_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.0, 0.2, 0.75))
		if _timer_pulse_tween == null or not is_instance_valid(_timer_pulse_tween):
			_timer_pulse_tween = create_tween().set_loops()
			_timer_pulse_tween.tween_property(timer_label, "modulate", Color(1.4, 0.7, 0.7, 1.0), 0.18)
			_timer_pulse_tween.tween_property(timer_label, "modulate", Color.WHITE, 0.18)
	else:
		if _timer_pulse_tween and is_instance_valid(_timer_pulse_tween):
			_timer_pulse_tween.kill()
			_timer_pulse_tween = null
		timer_label.modulate = Color.WHITE
		if seconds_left <= 0:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.25, 1.0))
		else:
			timer_label.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0, 1.0))
			timer_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.45, 0.8, 0.7))


## `side` is the rally loser (0 = left/Blue, 1 = right/Red). Blink that half neon red.
func _on_point_scored(side: int) -> void:
	var flash := _flash_left if side == 0 else _flash_right
	if flash == null:
		return
	var mat := flash.material_override as StandardMaterial3D
	if mat == null:
		return

	if _flash_tween and is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_flash_mat = mat
	_set_flash(0.0)

	_flash_tween = create_tween()
	for i in 3:
		_flash_tween.tween_method(_set_flash, 0.0, 1.0, 0.1)
		_flash_tween.tween_method(_set_flash, 1.0, 0.12, 0.22)
	_flash_tween.tween_method(_set_flash, 0.12, 0.0, 0.35)


func _set_flash(value: float) -> void:
	if _flash_mat == null:
		return
	_flash_mat.albedo_color = Color(1.0, 0.05, 0.12, value * 0.8)
	_flash_mat.emission_energy_multiplier = value * 3.5


func _on_match_over(_winner_side: int) -> void:
	await get_tree().create_timer(1.4).timeout
	if root_events:
		root_events.ev_exit_game.emit(match_controller.build_result_payload())


func _align_ceiling_to_screen_top(cam: Camera3D) -> void:
	var ceiling_shape := get_node_or_null("Court/Ceiling/CollisionShape3D") as CollisionShape3D
	if ceiling_shape == null:
		return
	var ceiling_glass := get_node_or_null("Court/Ceiling/Glass") as MeshInstance3D
	var screen_top := Vector2(get_viewport().get_visible_rect().size.x * 0.5, 0.0)
	var origin := cam.project_ray_origin(screen_top)
	var dir := cam.project_ray_normal(screen_top)
	if absf(dir.z) < 0.0001:
		return
	var hit := origin + dir * (-origin.z / dir.z)
	var box := ceiling_shape.shape as BoxShape3D
	var half_h := 0.2 if box == null else box.size.y * 0.5
	ceiling_shape.position.y = hit.y + half_h
	if ceiling_glass:
		ceiling_glass.position.y = ceiling_shape.position.y


func _default_data() -> Dictionary:
	var cfg := game_config.duplicate(true) if game_config else GameConfig.new()
	return {"custom_battle": cfg}
