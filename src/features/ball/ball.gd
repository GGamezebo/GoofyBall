class_name Ball
extends RigidBody3D

## Volleyball on the side-view plane (Z locked).

signal landed(side: int)
## Emitted once per meaningful hit (after bounce impulse is applied).
signal touched(side: int)

const MAX_SPEED := 22.0
const FLOOR_SCORE_Y := 0.55
const PLANE_Z := 0.0
## Ignore re-contacts with the same body for this long (physics spam).
const TOUCH_COOLDOWN_SEC := 0.2

var _scored := false
var _touch_cooldown: float = 0.0
var _last_touch_body: WeakRef


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position.z = PLANE_Z
	if _touch_cooldown > 0.0:
		_touch_cooldown = maxf(0.0, _touch_cooldown - delta)

	if linear_velocity.length() > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED
	linear_velocity.z = 0.0

	if not _scored and global_position.y <= FLOOR_SCORE_Y and linear_velocity.y < -1.0:
		_score_point()


func _score_point() -> void:
	_scored = true
	var side := 0 if global_position.x < 0.0 else 1
	landed.emit(side)
	freeze = true


func _on_body_entered(body: Node) -> void:
	if _scored or freeze:
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
	_scored = false
	_touch_cooldown = 0.0
	_last_touch_body = null
	freeze = false
	global_position = Vector3(pos.x, pos.y, PLANE_Z)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## Place the ball frozen mid-air (serve countdown).
func hold_ball(pos: Vector3) -> void:
	_scored = false
	_touch_cooldown = 0.0
	_last_touch_body = null
	global_position = Vector3(pos.x, pos.y, PLANE_Z)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true


## Let the held ball drop.
func release_ball() -> void:
	freeze = false
