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
var _boom_was_available: bool = false
var _vc: VirtualControls
var _online_sync: OnlineMatchSync
var _online_client: bool = false
var _exit_emitted: bool = false
var _local_display_name: String = "YOU"
var _name_left_label: Label
var _name_right_label: Label

@onready var _flash_left: MeshInstance3D = get_node_or_null("Court/FloorFlashLeft")
@onready var _flash_right: MeshInstance3D = get_node_or_null("Court/FloorFlashRight")


func _ready() -> void:
	PerformanceTune.apply_game_scene(self)
	_vc = get_node_or_null("UI/VirtualControls") as VirtualControls
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.look_at(Vector3(0.0, 2.5, 0.0), Vector3.UP)
		await get_tree().process_frame
		_align_ceiling_to_screen_top(cam)


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

	match_controller.initialize(game_config)

	var left := match_controller.player_left as BlobPlayer
	var right := match_controller.player_right as BlobPlayer
	var ball := match_controller.ball as Ball

	_online_client = game_config.online and multiplayer.has_multiplayer_peer() and not multiplayer.is_server()

	if game_config.online:
		_setup_fighter_banners()
		# Disable AI first — setup(false) flips right.use_player_input back on;
		# OnlineMatchSync must run after so both sides stay on external_* input.
		if ai_opponent:
			ai_opponent.setup(right, ball, false)
		_setup_online_sync(left, right, ball)
	elif ai_opponent:
		ai_opponent.setup(right, ball, game_config.vs_ai)

	if not _online_client:
		game_manager.initialize(game_config, match_controller)

	var vc := _vc
	if vc == null:
		vc = get_node_or_null("UI/VirtualControls") as VirtualControls
		_vc = vc
	if vc:
		if not vc.ev_self_destruct_requested.is_connected(_on_touch_self_destruct):
			vc.ev_self_destruct_requested.connect(_on_touch_self_destruct)
	var local_blob := _local_blob()
	if local_blob and not local_blob.ev_last_chance_used.is_connected(_on_last_chance_used):
		local_blob.ev_last_chance_used.connect(_on_last_chance_used)

	if hint_label:
		if game_config.online:
			var side_name := "BLUE" if game_config.local_side == 0 else "RED"
			hint_label.text = "You are %s (%s) — left drag move, right hold jump" % [_local_display_name, side_name]
		elif game_config.vs_ai:
			hint_label.text = "You: move+jump / Space·B blast (1/round)   |   AI (Red)   |   Esc — menu"
		else:
			hint_label.text = "Blue: move+jump / Space·B blast   |   Red: pad1 / arrows   |   Esc — menu"

	_listener.add(game_events.ev_score_changed, _on_score)
	_listener.add(game_events.ev_message, _on_message)
	_listener.add(game_events.ev_match_over, _on_match_over)
	_listener.add(game_events.ev_point_scored, _on_point_scored)
	_listener.add(game_events.ev_round_time_changed, _on_round_time)

	root_events.ev_battle_started.emit()
	_on_score(0, 0)
	_on_round_time(int(game_config.round_duration_sec) if game_config else 60)
	_refresh_boom_button()


func _setup_online_sync(left: BlobPlayer, right: BlobPlayer, ball: Ball) -> void:
	_online_sync = OnlineMatchSync.new()
	_online_sync.name = "OnlineMatchSync"
	add_child(_online_sync)
	_online_sync.setup(left, right, ball, game_config.local_side, _local_display_name)
	_online_sync.ev_hud.connect(_on_online_hud)
	_online_sync.ev_remote_match_over.connect(_on_remote_match_over)
	_online_sync.ev_names_changed.connect(_on_fighter_names)
	_on_fighter_names(_online_sync.left_display_name, _online_sync.right_display_name)
	if not _online_client and game_events:
		# Host mirrors HUD into sync for the client.
		_listener.add(game_events.ev_score_changed, _host_sync_score)
		_listener.add(game_events.ev_message, _host_sync_message)
		_listener.add(game_events.ev_round_time_changed, _host_sync_timer)


func _setup_fighter_banners() -> void:
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null:
		return
	_name_left_label = _make_fighter_label(ui, true)
	_name_right_label = _make_fighter_label(ui, false)
	_on_fighter_names("BLUE", "RED")


func _make_fighter_label(ui: CanvasLayer, is_left: bool) -> Label:
	var label := Label.new()
	label.name = "FighterNameLeft" if is_left else "FighterNameRight"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override(
		"font_color",
		Color(0.35, 0.85, 1.0, 1.0) if is_left else Color(1.0, 0.35, 0.55, 1.0)
	)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 5
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 12.0
	label.offset_bottom = 56.0
	if is_left:
		label.anchor_left = 0.0
		label.anchor_right = 0.28
		label.offset_left = 16.0
		label.offset_right = -8.0
	else:
		label.anchor_left = 0.72
		label.anchor_right = 1.0
		label.offset_left = 8.0
		label.offset_right = -16.0
	ui.add_child(label)
	return label


func _on_fighter_names(left_name: String, right_name: String) -> void:
	var you_left := game_config != null and game_config.online and game_config.local_side == 0
	var you_right := game_config != null and game_config.online and game_config.local_side == 1
	if _name_left_label:
		_name_left_label.text = ("%s\n(YOU)" % left_name.to_upper()) if you_left else left_name.to_upper()
	if _name_right_label:
		_name_right_label.text = ("%s\n(YOU)" % right_name.to_upper()) if you_right else right_name.to_upper()


func _host_sync_score(score_left: int, score_right: int) -> void:
	if _online_sync:
		_online_sync.notify_hud(score_left, score_right, message_label.text if message_label else "", _last_timer_value())


func _host_sync_message(text: String) -> void:
	if _online_sync:
		_online_sync.notify_hud(
			match_controller.score_left if match_controller else 0,
			match_controller.score_right if match_controller else 0,
			text,
			_last_timer_value()
		)


func _host_sync_timer(seconds_left: int) -> void:
	if _online_sync:
		_online_sync.notify_hud(
			match_controller.score_left if match_controller else 0,
			match_controller.score_right if match_controller else 0,
			message_label.text if message_label else "",
			seconds_left
		)


func _last_timer_value() -> int:
	if timer_label == null:
		return 0
	return int(timer_label.text) if timer_label.text.is_valid_int() else 0


func _on_online_hud(score_left: int, score_right: int, message: String, timer_sec: int) -> void:
	_on_score(score_left, score_right)
	if message_label and not message.is_empty():
		message_label.text = message
	if timer_sec >= 0:
		_on_round_time(timer_sec)


func _local_blob() -> BlobPlayer:
	if match_controller == null:
		return null
	if game_config and game_config.online and game_config.local_side == 1:
		return match_controller.player_right as BlobPlayer
	return match_controller.player_left as BlobPlayer


func _process(_delta: float) -> void:
	_refresh_boom_button()


func _refresh_boom_button() -> void:
	if _vc == null or match_controller == null:
		return
	var blob := _local_blob()
	var available := blob != null and blob.can_try_last_chance()
	if available == _boom_was_available:
		return
	_boom_was_available = available
	_vc.set_last_chance_available(available)


func deinit() -> void:
	if _online_sync:
		_online_sync.shutdown()
		_online_sync = null
	_listener.deinit()
	root_events.ev_battle_finished.emit()
	super.deinit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave_online_if_needed()
		root_events.ev_return_to_menu.emit({})
		get_viewport().set_input_as_handled()


func _leave_online_if_needed() -> void:
	if game_config == null or not game_config.online:
		return
	var online := get_node_or_null("../../OnlineService") as OnlineService
	if online == null:
		var root := get_tree().get_first_node_in_group("app_root")
		if root:
			online = root.get_node_or_null("OnlineService") as OnlineService
	# AppRoot sibling path from nested scene varies — walk up.
	if online == null:
		var n: Node = self
		while n:
			online = n.get_node_or_null("OnlineService") as OnlineService
			if online:
				break
			n = n.get_parent()
	if online:
		online.leave_realtime_match_async()


func _on_touch_self_destruct() -> void:
	if game_config and game_config.online and _online_sync:
		_online_sync.request_local_blast()
		return
	var blob := _local_blob()
	if blob:
		blob.try_last_chance()


func _on_last_chance_used() -> void:
	_refresh_boom_button()
	if game_events:
		game_events.ev_message.emit("Last chance!")


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
	if _exit_emitted:
		return
	await get_tree().create_timer(1.4).timeout
	if _exit_emitted:
		return
	_exit_emitted = true
	var payload := match_controller.build_result_payload() if match_controller else {}
	if _online_sync and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_online_sync.notify_match_over(payload)
	if root_events:
		root_events.ev_exit_game.emit(payload)


func _on_remote_match_over(payload: Dictionary) -> void:
	if _exit_emitted:
		return
	_exit_emitted = true
	_leave_online_if_needed()
	if root_events:
		root_events.ev_exit_game.emit(payload)


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
