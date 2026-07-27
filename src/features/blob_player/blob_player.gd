class_name BlobPlayer
extends CharacterBody3D

## Side-view blob: moves on X, jumps on Y, locked to Z = 0.
## Once per round: last-chance self-destruct blast (`p1_self_destruct` for Blue).

signal ev_last_chance_used
signal ev_last_chance_ready

@export var player_index: int = 0
@export var blob_color: Color = Color.CORNFLOWER_BLUE
## When false, move via `external_axis` / `external_jump` (AI / tests).
@export var use_player_input: bool = true
@export var ball: RigidBody3D

const MOVE_SPEED := 6.5
const JUMP_VELOCITY := 11.6
const GRAVITY := 22.0
const AIR_CONTROL := 0.55
const HIT_SPEED := 8.0
## Loft for high contacts only; low contacts keep geometric cut (under-net).
const HIT_MIN_UP := 4.0
const HIT_REFLECT := 0.4
const HIT_PUSH := 0.75
const HIT_FLOOR_VY := -10.0
const BLAST_SPEED := 18.0
const BLAST_UP := 5.0
const BLAST_RADIUS := 16.0
const PLANE_Z := 0.0
const SHADOW_FLOOR_Y := 0.02
## Keep each blob on its own half (radius + half-net + margin).
const NET_LIMIT_X := 0.55

@onready var mesh_root: Node3D = $MeshRoot
@onready var _ground_shadow: MeshInstance3D = $GroundShadow
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _glow: OmniLight3D = $GlowLight
@onready var _sparks: GPUParticles3D = $ExplosionSparks
@onready var _blast_flash: OmniLight3D = $BlastFlash

var external_axis: float = 0.0
var external_jump: bool = false

var _squash := 1.0
var _stretch := 1.0
var _destroyed: bool = false
var _last_chance_used: bool = false


func _ready() -> void:
	_apply_color()
	if _ground_shadow:
		_ground_shadow.top_level = true
		_ground_shadow.transparency = 0.55
	if _sparks:
		_sparks.emitting = false
	if _blast_flash:
		_blast_flash.visible = false
	if PerformanceTune.is_constrained():
		if _glow:
			_glow.visible = false
		if mesh_root:
			for child in mesh_root.get_children():
				if child is MeshInstance3D:
					(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Called at match start — revive and restore last-chance charge.
func prepare_match(p_ball: RigidBody3D = null) -> void:
	if p_ball:
		ball = p_ball
	prepare_round()


## Called each serve — revive if exploded and recharge last-chance for the new rally.
func prepare_round() -> void:
	_last_chance_used = false
	_revive()
	ev_last_chance_ready.emit()


func is_destroyed() -> bool:
	return _destroyed


func _physics_process(delta: float) -> void:
	if _destroyed:
		return

	if use_player_input and _can_use_last_chance_input() \
			and Input.is_action_just_pressed("p1_self_destruct"):
		try_last_chance()
		return

	var move_dir := _read_move_input()
	var on_floor := is_on_floor()
	var target_vx := move_dir * MOVE_SPEED

	# Smooth horizontal accel for AI (and soft landings); keyboard stays snappy on floor.
	if use_player_input and on_floor:
		velocity.x = target_vx
	else:
		var accel := 18.0 if on_floor else (MOVE_SPEED * AIR_CONTROL * 8.0)
		velocity.x = move_toward(velocity.x, target_vx, accel * delta)

	if _read_jump_input() and on_floor:
		velocity.y = JUMP_VELOCITY
		_squash = 1.25
		_stretch = 0.78

	if not on_floor:
		velocity.y -= GRAVITY * delta

	velocity.z = 0.0

	var was_on_floor := on_floor
	move_and_slide()
	global_position.z = PLANE_Z
	_clamp_to_own_half()

	if not was_on_floor and is_on_floor():
		_squash = 0.62
		_stretch = 1.32

	_squash = lerpf(_squash, 1.0, delta * 14.0)
	_stretch = lerpf(_stretch, 1.0, delta * 14.0)
	if mesh_root:
		mesh_root.scale = Vector3(_stretch, _squash, _stretch)

	_update_ground_shadow()
	external_jump = false


func _can_use_last_chance_input() -> bool:
	# Blue / P1 only — local 2P has no dual last-chance.
	return player_index == 0 and can_try_last_chance()


## True when blast is currently allowed (own half, live ball, charge left).
func can_try_last_chance() -> bool:
	if player_index != 0:
		return false
	if _destroyed or _last_chance_used:
		return false
	if ball == null or not is_instance_valid(ball):
		return false
	if "freeze" in ball and ball.freeze:
		return false
	if _is_ball_on_opponent_half():
		return false
	return true


## Last-chance self-destruct: explode FX + blast the ball. Once per round.
func try_last_chance() -> bool:
	if not can_try_last_chance():
		return false
	_last_chance_used = true
	_destroyed = true
	velocity = Vector3.ZERO
	_play_explosion_fx()
	_apply_blast_wave()
	ev_last_chance_used.emit()
	return true


func _is_ball_on_opponent_half() -> bool:
	if ball == null or not is_instance_valid(ball):
		return false
	if player_index == 0:
		return ball.global_position.x > 0.0
	return ball.global_position.x < 0.0


func _play_explosion_fx() -> void:
	_set_body_visible(false)
	if _collision:
		_collision.disabled = true
	collision_layer = 0
	collision_mask = 0
	if _sparks:
		_tint_sparks()
		_sparks.restart()
		_sparks.emitting = true
	if _blast_flash:
		_blast_flash.light_color = blob_color.lightened(0.35)
		_blast_flash.visible = true
		_blast_flash.light_energy = 8.0
		var tw := create_tween()
		tw.tween_property(_blast_flash, "light_energy", 0.0, 0.45)
		tw.tween_callback(func() -> void:
			if is_instance_valid(_blast_flash):
				_blast_flash.visible = false
		)


func _apply_blast_wave() -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if "freeze" in ball and ball.freeze:
		return

	var delta := ball.global_position - global_position
	delta.z = 0.0
	var dist := delta.length()
	var dir: Vector3
	if dist < 0.05:
		dir = Vector3(1.0 if player_index == 0 else -1.0, 0.35, 0.0).normalized()
	else:
		dir = delta.normalized()

	# Bias toward the opponent half so last-chance tends to clear the net.
	var toward_opp := 1.0 if player_index == 0 else -1.0
	dir.x = lerpf(dir.x, toward_opp, 0.35)
	dir = dir.normalized()

	var falloff := 1.0 - clampf(dist / BLAST_RADIUS, 0.0, 1.0)
	var power := BLAST_SPEED * (0.55 + 0.45 * falloff)
	var blast := dir * power + Vector3(0.0, BLAST_UP * (0.5 + 0.5 * falloff), 0.0)
	blast.z = 0.0

	ball.linear_velocity = blast
	ball.angular_velocity = Vector3(0.0, 0.0, randf_range(-14.0, 14.0))


func _tint_sparks() -> void:
	if _sparks == null:
		return
	var proc := _sparks.process_material
	if proc is ParticleProcessMaterial:
		var colored: ParticleProcessMaterial = (proc as ParticleProcessMaterial).duplicate()
		colored.color = blob_color.lightened(0.25)
		_sparks.process_material = colored
	var pass_mesh := _sparks.draw_pass_1
	if pass_mesh is SphereMesh:
		var sm := (pass_mesh as SphereMesh).duplicate() as SphereMesh
		var src := sm.material
		if src is StandardMaterial3D:
			var mat: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			mat.albedo_color = blob_color.lightened(0.3)
			mat.emission_enabled = true
			mat.emission = blob_color
			mat.emission_energy_multiplier = 4.0
			sm.material = mat
		_sparks.draw_pass_1 = sm


func _revive() -> void:
	_destroyed = false
	velocity = Vector3.ZERO
	collision_layer = 2
	collision_mask = 5
	if _collision:
		_collision.disabled = false
	_set_body_visible(true)
	if _sparks:
		_sparks.emitting = false
	if _blast_flash:
		_blast_flash.visible = false
		_blast_flash.light_energy = 0.0
	_squash = 1.0
	_stretch = 1.0
	if mesh_root:
		mesh_root.scale = Vector3.ONE


func _set_body_visible(visible: bool) -> void:
	if mesh_root:
		mesh_root.visible = visible
	if _ground_shadow:
		_ground_shadow.visible = visible
	if _glow:
		_glow.visible = visible


func _update_ground_shadow() -> void:
	if _ground_shadow == null or _destroyed:
		return
	_ground_shadow.global_position = Vector3(global_position.x, SHADOW_FLOOR_Y, PLANE_Z)
	var t := clampf(1.0 - (global_position.y - 0.42) / 5.5, 0.45, 1.0)
	_ground_shadow.scale = Vector3(t, 1.0, t)


func _clamp_to_own_half() -> void:
	if player_index == 0:
		if global_position.x > -NET_LIMIT_X:
			global_position.x = -NET_LIMIT_X
			if velocity.x > 0.0:
				velocity.x = 0.0
	else:
		if global_position.x < NET_LIMIT_X:
			global_position.x = NET_LIMIT_X
			if velocity.x < 0.0:
				velocity.x = 0.0


func apply_ball_hit(ball_body: RigidBody3D, hit_normal: Vector3) -> void:
	if _destroyed:
		return
	var n := hit_normal
	n.z = 0.0
	if n.length_squared() < 0.0001:
		n = Vector3.UP
	else:
		n = n.normalized()

	# Contact height on the blob: +1 top, -1 bottom. Low hits cut under the net.
	var loft := clampf(n.y, 0.0, 1.0)

	var incoming := ball_body.linear_velocity
	incoming.z = 0.0
	var bounced := incoming.bounce(n)
	var push := n * HIT_SPEED
	var player_boost := Vector3(velocity.x * 0.75, velocity.y * 0.5, 0.0)

	var new_vel := bounced * HIT_REFLECT + push * HIT_PUSH + player_boost

	# Only mid/high contacts get forced loft — bottom contacts keep geometry.
	if loft > 0.2:
		new_vel.y = maxf(new_vel.y, HIT_MIN_UP * loft)
	else:
		# Soft floor so a pure downward poke doesn't bury instantly.
		new_vel.y = maxf(new_vel.y, HIT_FLOOR_VY)

	new_vel.z = 0.0
	ball_body.linear_velocity = new_vel
	ball_body.angular_velocity = Vector3(0, 0, randf_range(-5.0, 5.0))
	_squash = 0.7
	_stretch = 1.25


func set_ai_controlled(enabled: bool) -> void:
	use_player_input = not enabled
	external_axis = 0.0
	external_jump = false


func _apply_color() -> void:
	if mesh_root == null:
		return
	var body := mesh_root.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var mat := body.get_active_material(0)
	if mat is StandardMaterial3D:
		var colored: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
		colored.albedo_color = blob_color
		colored.emission_enabled = true
		colored.emission = blob_color.darkened(0.35)
		colored.emission_energy_multiplier = 0.55
		body.set_surface_override_material(0, colored)

	if _glow:
		_glow.light_color = blob_color


func _read_move_input() -> float:
	if not use_player_input:
		return clampf(external_axis, -1.0, 1.0)
	# Analog: stick strength, touch drag strength, or digital keys (±1).
	if player_index == 0:
		return Input.get_axis("p1_left", "p1_right")
	return Input.get_axis("p2_left", "p2_right")


func _read_jump_input() -> bool:
	if not use_player_input:
		return external_jump
	if player_index == 0:
		return Input.is_action_pressed("p1_jump")
	return Input.is_action_pressed("p2_jump")
