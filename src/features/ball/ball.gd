class_name Ball
extends RigidBody3D

## Volleyball on the side-view plane (Z locked).

signal landed(side: int)
## Emitted once per meaningful hit (after bounce impulse is applied).
signal touched(side: int)

const MAX_SPEED := 38.0
const FLOOR_SCORE_Y := 0.55
const PLANE_Z := 0.0
const SHADOW_FLOOR_Y := 0.02
## Ignore re-contacts with the same body for this long (physics spam).
const TOUCH_COOLDOWN_SEC := 0.2

const COLOR_NORMAL := Color(1.0, 0.82, 0.12, 1.0)
const COLOR_ALARM := Color(1.0, 0.08, 0.12, 1.0)
const EMISSION_NORMAL := Color(0.75, 0.35, 0.02, 1.0)
const EMISSION_ALARM := Color(1.0, 0.05, 0.05, 1.0)

var _scored := false
var _touch_cooldown: float = 0.0
var _last_touch_body: WeakRef
var _alarm := false
## Online client: pose driven by host; skip local simulation (or smooth-follow targets).
var network_puppet: bool = false
## When puppet: lerp toward these each physics frame.
var net_target_pos: Vector3 = Vector3.ZERO
var net_target_vel: Vector3 = Vector3.ZERO
var net_has_target: bool = false
var _body_mat: StandardMaterial3D
var _stripe_mat: StandardMaterial3D

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _stripe: MeshInstance3D = $Stripe
@onready var _stripe2: MeshInstance3D = $Stripe2
@onready var _ground_shadow: MeshInstance3D = $GroundShadow
@onready var _glow: OmniLight3D = $GlowLight
@onready var _sparks: GPUParticles3D = $ExplosionSparks


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	body_entered.connect(_on_body_entered)
	_cache_materials()
	if _sparks:
		_sparks.emitting = false
	if _ground_shadow:
		_ground_shadow.top_level = true
		_ground_shadow.transparency = 0.55
	if PerformanceTune.is_constrained():
		if _glow:
			_glow.visible = false
		if _mesh:
			_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _stripe:
			_stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _stripe2:
			_stripe2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	global_position.z = PLANE_Z
	if network_puppet:
		if net_has_target:
			global_position = Vector3(net_target_pos.x, net_target_pos.y, PLANE_Z)
			linear_velocity = net_target_vel
			linear_velocity.z = 0.0
			global_position.z = PLANE_Z
		if _alarm and not _scored:
			_update_alarm_visuals()
		_update_ground_shadow()
		return
	if _touch_cooldown > 0.0:
		_touch_cooldown = maxf(0.0, _touch_cooldown - delta)

	if _alarm and not _scored:
		_update_alarm_visuals()

	if linear_velocity.length() > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED
	linear_velocity.z = 0.0

	_update_ground_shadow()

	if not _scored and global_position.y <= FLOOR_SCORE_Y and linear_velocity.y < -1.0:
		_score_point()


func _update_ground_shadow() -> void:
	if _ground_shadow == null:
		return
	_ground_shadow.global_position = Vector3(global_position.x, SHADOW_FLOOR_Y, PLANE_Z)
	var t := clampf(1.0 - (global_position.y - 0.35) / 6.0, 0.4, 1.0)
	_ground_shadow.scale = Vector3(t, 1.0, t)


func set_alarm(enabled: bool) -> void:
	_alarm = enabled
	if not enabled:
		_apply_ball_color(COLOR_NORMAL, EMISSION_NORMAL, 0.7, 0.85)
		if _glow:
			_glow.light_color = Color(1.0, 0.72, 0.12, 1.0)
			_glow.light_energy = 1.6


func is_alarm() -> bool:
	return _alarm


func apply_network_state(
	pos: Vector3,
	lin_vel: Vector3,
	ang_vel: Vector3,
	frozen: bool,
	alarm: bool
) -> void:
	if network_puppet:
		apply_interp_pose(pos, lin_vel, frozen, alarm)
		return
	var target := Vector3(pos.x, pos.y, PLANE_Z)
	var vel := Vector3(lin_vel.x, lin_vel.y, 0.0)
	global_position = target
	linear_velocity = vel
	angular_velocity = ang_vel
	freeze = frozen
	set_alarm(alarm)
	_update_ground_shadow()


## CS remote ball: pose already delayed-interpolated by OnlineMatchSync.
func apply_interp_pose(pos: Variant, lin_vel: Variant, frozen: bool, alarm: bool) -> void:
	var target := Vector3((pos as Vector3).x, (pos as Vector3).y, PLANE_Z)
	var vel := Vector3((lin_vel as Vector3).x, (lin_vel as Vector3).y, 0.0)
	freeze = true
	net_target_pos = target
	net_target_vel = Vector3.ZERO if frozen else vel
	net_has_target = true
	angular_velocity = Vector3.ZERO
	_scored = false
	set_alarm(alarm)
	_set_visuals_visible(true)
	global_position = target
	linear_velocity = net_target_vel
	_update_ground_shadow()


## Freeze, hide mesh, burst sparks. Safe to call once per rally.
func explode() -> void:
	if _scored:
		return
	_scored = true
	set_alarm(false)
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_set_visuals_visible(false)
	if _sparks:
		_sparks.restart()
		_sparks.emitting = true


func _score_point() -> void:
	_scored = true
	var side := 0 if global_position.x < 0.0 else 1
	landed.emit(side)
	freeze = true
	set_alarm(false)


func _on_body_entered(body: Node) -> void:
	if network_puppet or _scored or freeze:
		return
	if not (body is CharacterBody3D):
		return
	var player := body as CharacterBody3D
	if not player.has_method("apply_ball_hit"):
		return

	# Debounce: same body re-entering within cooldown is one touch.
	var last: Object = _last_touch_body.get_ref() if _last_touch_body else null
	if last == player and _touch_cooldown > 0.0:
		return

	var normal: Vector3 = (global_position - player.global_position).normalized()
	normal.z = 0.0
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	player.apply_ball_hit(self, normal)

	_last_touch_body = weakref(player)
	_touch_cooldown = TOUCH_COOLDOWN_SEC

	var side := 0
	if "player_index" in player:
		side = int(player.get("player_index"))
	elif player.global_position.x >= 0.0:
		side = 1
	touched.emit(side)


func reset_ball(pos: Vector3) -> void:
	_prepare_for_serve(pos)
	freeze = false


## Place the ball frozen mid-air (serve countdown).
func hold_ball(pos: Vector3) -> void:
	_prepare_for_serve(pos)
	freeze = true


## Let the held ball drop.
func release_ball() -> void:
	freeze = false


func _prepare_for_serve(pos: Vector3) -> void:
	_scored = false
	_touch_cooldown = 0.0
	_last_touch_body = null
	set_alarm(false)
	_set_visuals_visible(true)
	if _sparks:
		_sparks.emitting = false
	global_position = Vector3(pos.x, pos.y, PLANE_Z)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _cache_materials() -> void:
	if _mesh:
		var src := _mesh.get_active_material(0)
		if src is StandardMaterial3D:
			_body_mat = (src as StandardMaterial3D).duplicate()
			_mesh.set_surface_override_material(0, _body_mat)
	if _stripe:
		var src2 := _stripe.get_active_material(0)
		if src2 is StandardMaterial3D:
			_stripe_mat = (src2 as StandardMaterial3D).duplicate()
			_stripe.set_surface_override_material(0, _stripe_mat)
			if _stripe2:
				_stripe2.set_surface_override_material(0, _stripe_mat)


func _update_alarm_visuals() -> void:
	# Fast red blink for the last seconds of the round.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.028)
	var albedo := COLOR_NORMAL.lerp(COLOR_ALARM, pulse)
	var emission := EMISSION_NORMAL.lerp(EMISSION_ALARM, pulse)
	_apply_ball_color(albedo, emission, lerpf(0.7, 4.5, pulse), lerpf(0.85, 5.0, pulse))
	if _glow:
		_glow.light_color = Color(1.0, 0.12, 0.08, 1.0).lerp(Color(1.0, 0.75, 0.15, 1.0), 1.0 - pulse)
		_glow.light_energy = lerpf(1.2, 4.0, pulse)


func _apply_ball_color(albedo: Color, emission: Color, body_energy: float, stripe_energy: float) -> void:
	if _body_mat:
		_body_mat.albedo_color = albedo
		_body_mat.emission = emission
		_body_mat.emission_energy_multiplier = body_energy
	if _stripe_mat:
		_stripe_mat.albedo_color = albedo.lightened(0.1)
		_stripe_mat.emission = emission.lightened(0.15)
		_stripe_mat.emission_energy_multiplier = stripe_energy


func _set_visuals_visible(show_visuals: bool) -> void:
	if _mesh:
		_mesh.visible = show_visuals
	if _stripe:
		_stripe.visible = show_visuals
	if _stripe2:
		_stripe2.visible = show_visuals
	if _glow:
		_glow.visible = show_visuals
	if _ground_shadow:
		_ground_shadow.visible = show_visuals
