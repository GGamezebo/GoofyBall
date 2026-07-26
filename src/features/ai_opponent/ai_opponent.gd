class_name AiOpponent
extends Node

## Reactive bot for the right-side blob — smooth proportional steering.

@export var player: BlobPlayer
@export var ball: RigidBody3D
@export var enabled: bool = false

const NET_LIMIT := 0.55
const COURT_RIGHT := 6.2
## Distance at which steering is full strength (±1).
const FULL_SPEED_DIST := 1.6
## Soft stop zone — ease to zero instead of hard cut.
const STOP_DIST := 0.12
## How fast external_axis catches up to the desired value.
const AXIS_SMOOTH := 10.0
const JUMP_RANGE_X := 1.4
const JUMP_HEIGHT_MAX := 4.5
const LEAD_TIME := 0.22

var _axis: float = 0.0


func setup(p_player: BlobPlayer, p_ball: RigidBody3D, p_enabled: bool) -> void:
	player = p_player
	ball = p_ball
	enabled = p_enabled
	_axis = 0.0
	if player:
		player.set_ai_controlled(enabled)
		player.external_axis = 0.0


func _physics_process(delta: float) -> void:
	if not enabled or player == null or ball == null:
		return

	if ball.freeze:
		_axis = move_toward(_axis, 0.0, AXIS_SMOOTH * delta)
		player.external_axis = _axis
		return

	var target_x: float = ball.global_position.x
	if ball.linear_velocity.x > 0.35:
		target_x += ball.linear_velocity.x * LEAD_TIME
	target_x = clampf(target_x, NET_LIMIT, COURT_RIGHT)

	var dx: float = target_x - player.global_position.x
	var desired: float = _steer_axis(dx)
	_axis = move_toward(_axis, desired, AXIS_SMOOTH * delta)
	player.external_axis = _axis

	var near_x: bool = absf(ball.global_position.x - player.global_position.x) < JUMP_RANGE_X
	var ball_descending: bool = ball.linear_velocity.y < 0.5
	var good_height: bool = ball.global_position.y < JUMP_HEIGHT_MAX and ball.global_position.y > 0.9
	if near_x and ball_descending and good_height and player.is_on_floor():
		player.external_jump = true


func _steer_axis(dx: float) -> float:
	var abs_dx := absf(dx)
	if abs_dx <= STOP_DIST:
		return 0.0
	# Proportional: closer → slower, far → full speed. Smoothstep softens the ramp.
	var t: float = clampf((abs_dx - STOP_DIST) / (FULL_SPEED_DIST - STOP_DIST), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return signf(dx) * t
