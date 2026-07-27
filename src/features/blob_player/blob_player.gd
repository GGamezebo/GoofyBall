class_name BlobPlayer
extends CharacterBody3D

## Side-view blob: moves on X, jumps on Y, locked to Z = 0.

@export var player_index: int = 0
@export var blob_color: Color = Color.CORNFLOWER_BLUE
## When false, move via `external_axis` / `external_jump` (AI / tests).
@export var use_player_input: bool = true

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
const PLANE_Z := 0.0
const SHADOW_FLOOR_Y := 0.02
## Keep each blob on its own half (radius + half-net + margin).
const NET_LIMIT_X := 0.55

@onready var mesh_root: Node3D = $MeshRoot
@onready var _ground_shadow: MeshInstance3D = $GroundShadow

var external_axis: float = 0.0
var external_jump: bool = false

var _squash := 1.0
var _stretch := 1.0


func _ready() -> void:
	_apply_color()
	if _ground_shadow:
		_ground_shadow.top_level = true


func _physics_process(delta: float) -> void:
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


func _update_ground_shadow() -> void:
	if _ground_shadow == null:
		return
	_ground_shadow.global_position = Vector3(global_position.x, SHADOW_FLOOR_Y, PLANE_Z)
	_ground_shadow.global_rotation = Vector3.ZERO
	var t := clampf(1.0 - (global_position.y - 0.42) / 5.5, 0.4, 1.0)
	_ground_shadow.scale = Vector3(t, 1.0, t)
	_ground_shadow.transparency = 1.0 - lerpf(0.2, 0.55, t)


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


func apply_ball_hit(ball: RigidBody3D, hit_normal: Vector3) -> void:
	var n := hit_normal
	n.z = 0.0
	if n.length_squared() < 0.0001:
		n = Vector3.UP
	else:
		n = n.normalized()

	# Contact height on the blob: +1 top, -1 bottom. Low hits cut under the net.
	var loft := clampf(n.y, 0.0, 1.0)

	var incoming := ball.linear_velocity
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
	ball.linear_velocity = new_vel
	ball.angular_velocity = Vector3(0, 0, randf_range(-5.0, 5.0))
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

	var glow := get_node_or_null("GlowLight") as OmniLight3D
	if glow:
		glow.light_color = blob_color


func _read_move_input() -> float:
	if not use_player_input:
		return clampf(external_axis, -1.0, 1.0)
	var dir := 0.0
	if player_index == 0:
		if Input.is_action_pressed("p1_left"):
			dir -= 1.0
		if Input.is_action_pressed("p1_right"):
			dir += 1.0
	else:
		if Input.is_action_pressed("p2_left"):
			dir -= 1.0
		if Input.is_action_pressed("p2_right"):
			dir += 1.0
	return dir


func _read_jump_input() -> bool:
	if not use_player_input:
		return external_jump
	if player_index == 0:
		return Input.is_action_pressed("p1_jump")
	return Input.is_action_pressed("p2_jump")
