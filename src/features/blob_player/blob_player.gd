class_name BlobPlayer
extends CharacterBody3D

## Side-view blob: moves on X, jumps on Y, locked to Z = 0.

@export var player_index: int = 0
@export var blob_color: Color = Color.CORNFLOWER_BLUE
## When false, move via `external_axis` / `external_jump` (AI / tests).
@export var use_player_input: bool = true

const MOVE_SPEED := 6.5
const JUMP_VELOCITY := 9.5
const GRAVITY := 22.0
const AIR_CONTROL := 0.55
const HIT_SPEED := 5.5
const HIT_MIN_UP := 3.0
const PLANE_Z := 0.0

@onready var mesh_root: Node3D = $MeshRoot

var external_axis: float = 0.0
var external_jump: bool = false

var _squash := 1.0
var _stretch := 1.0


func _ready() -> void:
	_apply_color()


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

	if not was_on_floor and is_on_floor():
		_squash = 0.62
		_stretch = 1.32

	_squash = lerpf(_squash, 1.0, delta * 14.0)
	_stretch = lerpf(_stretch, 1.0, delta * 14.0)
	if mesh_root:
		mesh_root.scale = Vector3(_stretch, _squash, _stretch)

	external_jump = false


func apply_ball_hit(ball: RigidBody3D, hit_normal: Vector3) -> void:
	var dir := hit_normal
	dir.z = 0.0
	dir = dir.normalized()

	var new_vel := dir * HIT_SPEED
	new_vel.x += velocity.x * 0.5
	new_vel.y = maxf(new_vel.y, HIT_MIN_UP) + maxf(velocity.y, 0.0) * 0.4
	new_vel.z = 0.0

	ball.linear_velocity = new_vel
	ball.angular_velocity = Vector3(0, 0, randf_range(-3.0, 3.0))
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
		return Input.is_action_just_pressed("p1_jump")
	return Input.is_action_just_pressed("p2_jump")
