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

var _listener: EventListener = EventListener.new()


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
			hint_label.text = "You: A/D + W   |   AI (Red)   |   Max 3 touches   |   Esc — menu"
		else:
			hint_label.text = "Blue: A/D + W   |   Red: ←/→ + ↑   |   Max 3 touches   |   Esc — menu"

	_listener.add(game_events.ev_score_changed, _on_score)
	_listener.add(game_events.ev_message, _on_message)
	_listener.add(game_events.ev_match_over, _on_match_over)

	root_events.ev_battle_started.emit()
	_on_score(0, 0)


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


func _on_match_over(_winner_side: int) -> void:
	await get_tree().create_timer(1.4).timeout
	if root_events:
		root_events.ev_exit_game.emit(match_controller.build_result_payload())


func _align_ceiling_to_screen_top(cam: Camera3D) -> void:
	var ceiling_shape := get_node_or_null("Court/Ceiling/CollisionShape3D") as CollisionShape3D
	if ceiling_shape == null:
		return
	var screen_top := Vector2(get_viewport().get_visible_rect().size.x * 0.5, 0.0)
	var origin := cam.project_ray_origin(screen_top)
	var dir := cam.project_ray_normal(screen_top)
	if absf(dir.z) < 0.0001:
		return
	var hit := origin + dir * (-origin.z / dir.z)
	var box := ceiling_shape.shape as BoxShape3D
	var half_h := 0.2 if box == null else box.size.y * 0.5
	ceiling_shape.position.y = hit.y + half_h


func _default_data() -> Dictionary:
	var cfg := game_config.duplicate(true) if game_config else GameConfig.new()
	return {"custom_battle": cfg}
