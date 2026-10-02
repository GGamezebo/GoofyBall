class_name MatchView
extends Node

## Renders the simulation: poses the blob/ball views, drives the HUD and fires
## cosmetic FX. It only READS `runner.sim.s`; everything is derived from state, so
## rollbacks and re-simulation can never duplicate or lose an effect.

@export var runner: MatchRunner
@export var blob_left: BlobView
@export var blob_right: BlobView
@export var ball: BallView
@export var flash_left: MeshInstance3D
@export var flash_right: MeshInstance3D
@export var score_label: Label
@export var message_label: Label
@export var timer_label: Label
@export var virtual_controls: VirtualControls
## CanvasLayer that receives the online fighter-name banners.
@export var hud_layer: CanvasLayer

## Side whose blast availability is mirrored on the BOOM button.
var local_side: int = 0
var name_blue: String = "Blue"
var name_red: String = "Red"
## Online displays smoothed-by-SyncManager state; offline interpolates between ticks.
var interpolate: bool = true

var _seen := {}
var _score_text := ""
var _message_text := "\u0000"
var _timer_sec := -1
var _timer_pulse: Tween
var _flash_tween: Tween
var _flash_mat: StandardMaterial3D
var _boom_available := true
var _name_left_label: Label
var _name_right_label: Label


func start() -> void:
	_seen = _serials(runner.sim.s)
	_score_text = ""
	_message_text = "\u0000"
	_timer_sec = -1
	_boom_available = false


func set_names(blue: String, red: String) -> void:
	name_blue = blue
	name_red = red


func show_fighter_names(left_name: String, right_name: String) -> void:
	if hud_layer == null:
		return
	if _name_left_label == null:
		_name_left_label = _make_fighter_label(true)
		_name_right_label = _make_fighter_label(false)
	var you_left := local_side == 0
	_name_left_label.text = ("%s\n(YOU)" % left_name.to_upper()) if you_left else left_name.to_upper()
	_name_right_label.text = ("%s\n(YOU)" % right_name.to_upper()) if not you_left else right_name.to_upper()


func _process(_delta: float) -> void:
	if runner == null or runner.sim.s.is_empty():
		return
	var s: Dictionary = runner.sim.s
	_pose(s)
	_hud(s)
	_fx(s)
	_boom(s)


# --- poses --------------------------------------------------------------------------

func _pose(s: Dictionary) -> void:
	var prev: Dictionary = runner.prev_state
	var alpha := 1.0
	if interpolate and not prev.is_empty() and int(prev["tick"]) == int(s["tick"]) - 1:
		alpha = clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	else:
		prev = s
	var views: Array = [blob_left, blob_right]
	for i in 2:
		var cur: Dictionary = s["p"][i]
		var old: Dictionary = prev["p"][i]
		var view := views[i] as BlobView
		if view:
			view.apply_state(
				_lerp(old["x"], cur["x"], alpha),
				_lerp(old["y"], cur["y"], alpha),
				float(cur["vy"]),
				bool(cur["dead"])
			)
	if ball:
		var b: Dictionary = s["ball"]
		var ob: Dictionary = prev["ball"]
		ball.apply_state(
			_lerp(ob["x"], b["x"], alpha),
			_lerp(ob["y"], b["y"], alpha),
			bool(b["hidden"]),
			runner.sim.is_alarm()
		)


static func _lerp(a: Variant, b: Variant, t: float) -> float:
	var fa := float(a)
	var fb := float(b)
	# Teleports (serve reset, rollback correction) are snapped, not smeared.
	if absf(fb - fa) > 2.0:
		return fb
	return fa + (fb - fa) * t


# --- HUD ----------------------------------------------------------------------------

func _hud(s: Dictionary) -> void:
	var score := "%d  :  %d" % [int(s["score_l"]), int(s["score_r"])]
	if score != _score_text:
		_score_text = score
		if score_label:
			score_label.text = score

	var text := _message_for(s)
	if text != _message_text:
		_message_text = text
		if message_label:
			message_label.text = text

	var phase := int(s["phase"])
	var sec := runner.sim.time_left_sec()
	if phase == VolleySim.Phase.SERVE:
		sec = int(ceili(float(int(runner.sim.cfg["round_ticks"])) / float(VolleySim.TICK_RATE)))
	if sec != _timer_sec:
		_timer_sec = sec
		_show_timer(sec)


func _message_for(s: Dictionary) -> String:
	if int(s["phase"]) == VolleySim.Phase.SERVE:
		return str(runner.sim.serve_countdown_sec())
	var side := int(s["msg_side"])
	match int(s["msg"]):
		VolleySim.Msg.POINT:
			return "Point for Red!" if side == 0 else "Point for Blue!"
		VolleySim.Msg.TIMEUP:
			return "Time's up! %s exploded!" % _who(side)
		VolleySim.Msg.TOUCHES:
			return "%s: too many touches!" % _who(side)
		VolleySim.Msg.WIN:
			return "%s wins!" % _who(side)
		VolleySim.Msg.LAST_CHANCE:
			return "Last chance!"
	return ""


func _who(side: int) -> String:
	return name_blue if side == 0 else name_red


func _show_timer(seconds_left: int) -> void:
	if timer_label == null:
		return
	timer_label.text = str(seconds_left)
	var alarm := seconds_left <= 5 and seconds_left > 0 and int(runner.sim.s["phase"]) != VolleySim.Phase.SERVE
	if alarm:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.2, 1.0))
		timer_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.0, 0.2, 0.75))
		if _timer_pulse == null or not is_instance_valid(_timer_pulse):
			_timer_pulse = create_tween().set_loops()
			_timer_pulse.tween_property(timer_label, "modulate", Color(1.4, 0.7, 0.7, 1.0), 0.18)
			_timer_pulse.tween_property(timer_label, "modulate", Color.WHITE, 0.18)
	else:
		if _timer_pulse and is_instance_valid(_timer_pulse):
			_timer_pulse.kill()
			_timer_pulse = null
		timer_label.modulate = Color.WHITE
		if seconds_left <= 0:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.25, 1.0))
		else:
			timer_label.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0, 1.0))
			timer_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.45, 0.8, 0.7))


# --- FX (edge-detected from the serial counters in state) ----------------------------

static func _serials(s: Dictionary) -> Dictionary:
	return {
		"touch": int(s["touch_serial"]),
		"point": int(s["point_serial"]),
		"blast": int(s["blast_serial"]),
		"explode": int(s["explode_serial"]),
	}


func _fx(s: Dictionary) -> void:
	var now := _serials(s)
	if _seen.is_empty():
		_seen = now
	# A rollback can move serials backwards: just resync, never replay FX.
	for key in now:
		if int(now[key]) < int(_seen.get(key, 0)):
			_seen[key] = now[key]
	if int(now["touch"]) > int(_seen["touch"]):
		var hit_view := (blob_left if int(s["touch_blob"]) == 0 else blob_right) as BlobView
		if hit_view:
			hit_view.play_hit()
	if int(now["blast"]) > int(_seen["blast"]):
		var blast_view := (blob_left if int(s["blast_blob"]) == 0 else blob_right) as BlobView
		if blast_view:
			blast_view.play_blast()
	if int(now["explode"]) > int(_seen["explode"]) and ball:
		ball.play_explosion()
	if int(now["point"]) > int(_seen["point"]):
		_flash_court(int(s["point_side"]))
	_seen = now


## `side` is the rally loser (0 = left/Blue, 1 = right/Red). Blink that half neon red.
func _flash_court(side: int) -> void:
	var flash := flash_left if side == 0 else flash_right
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


# --- BOOM button / banners -----------------------------------------------------------

func _boom(_s: Dictionary) -> void:
	if virtual_controls == null:
		return
	var available := runner.sim.can_blast(local_side if runner.game_config and runner.game_config.online else 0)
	if available != _boom_available:
		_boom_available = available
		virtual_controls.set_last_chance_available(available)


func _make_fighter_label(is_left: bool) -> Label:
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
	hud_layer.add_child(label)
	return label
