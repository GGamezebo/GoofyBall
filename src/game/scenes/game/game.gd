extends IScene

## Battle screen: wires config → MatchRunner (simulation) → MatchView (rendering/HUD).
## No gameplay rules live here; see `src/features/volley_sim/`.

@export var game_config: GameConfig
@export var root_events: RootEvents
@export var match_runner: MatchRunner
@export var match_view: MatchView
@export var hint_label: Label
@export var virtual_controls: VirtualControls

var _listener: EventListener = EventListener.new()
var _exit_emitted: bool = false
var _local_display_name: String = "YOU"


func _ready() -> void:
	PerformanceTune.apply_game_scene(self)
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.look_at(Vector3(0.0, 2.5, 0.0), Vector3.UP)
	super._ready()


func initialize(data: Dictionary) -> void:
	var scenario: GameConfig = data.get("custom_battle") as GameConfig
	if scenario:
		ResourceUtils.update_resource(game_config, scenario)

	# Payload keys can override resource fields (menu lobby).
	if data.has("ranked"):
		game_config.ranked = bool(data.get("ranked", false))
	if data.has("local_side"):
		game_config.local_side = int(data.get("local_side", 0))
	if data.has("online"):
		game_config.online = bool(data.get("online", false))
	_local_display_name = str(data.get("local_display_name", "")).strip_edges()
	if _local_display_name.is_empty():
		_local_display_name = "YOU"

	match_runner.initialize(game_config)
	match_view.local_side = game_config.local_side if game_config.online else 0
	match_view.interpolate = not game_config.online
	if game_config.vs_ai:
		match_view.set_names("You", "AI")
	match_view.start()

	_listener.add(match_runner.ev_match_over, _on_match_over)
	if virtual_controls and not virtual_controls.ev_self_destruct_requested.is_connected(match_runner.request_blast):
		virtual_controls.ev_self_destruct_requested.connect(match_runner.request_blast)

	if hint_label:
		hint_label.text = _hint_text()

	root_events.ev_battle_started.emit()


func deinit() -> void:
	_listener.deinit()
	root_events.ev_battle_finished.emit()
	super.deinit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		root_events.ev_return_to_menu.emit({})
		get_viewport().set_input_as_handled()


func _on_match_over(payload: Dictionary) -> void:
	if _exit_emitted:
		return
	_exit_emitted = true
	root_events.ev_exit_game.emit(payload)


func _hint_text() -> String:
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if game_config.online:
		var side_name := "BLUE" if game_config.local_side == 0 else "RED"
		return "You are %s (%s) — left drag move, right hold jump" % [_local_display_name, side_name]
	if touch:
		return "Left side: drag to move  |  Right side: hold to jump  |  BOOM: last chance"
	if game_config.vs_ai:
		return "You: move+jump / Space·B blast (1/round)   |   AI (Red)   |   Esc — menu"
	return "Blue: move+jump / Space·B blast   |   Red: pad1 / arrows   |   Esc — menu"


func _default_data() -> Dictionary:
	var cfg := game_config.duplicate(true) if game_config else GameConfig.new()
	return {"custom_battle": cfg}
