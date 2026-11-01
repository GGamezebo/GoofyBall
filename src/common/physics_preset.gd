class_name PhysicsPreset
extends Resource

## Physics numbers for one preset (Classic, Moon, ...). Meters, seconds, y up.

@export_group("Blob")
@export var blob_radius: float = 0.5
@export var move_speed: float = 6.5
@export var ground_accel: float = 18.0
@export var air_control: float = 0.55
@export var jump_velocity: float = 11.6
@export var gravity: float = 22.0
## Snap horizontal speed to the stick on the floor (crisp control) instead of accelerating.
@export var snap_move: bool = true

@export_group("Hit")
@export var hit_speed: float = 8.0
@export var hit_min_up: float = 4.0
@export var hit_reflect: float = 0.4
@export var hit_push: float = 0.75
@export var hit_floor_vy: float = -10.0
@export var touch_cooldown_ticks: int = 12

@export_group("Ball")
@export var ball_radius: float = 0.35
@export var ball_gravity: float = 3.92
@export var ball_damp: float = 0.115
@export var ball_bounce: float = 0.78
@export var ball_max_speed: float = 38.0
@export var ball_substeps: int = 4


func to_dict() -> Dictionary:
	return {
		"blob_radius": blob_radius, "move_speed": move_speed, "ground_accel": ground_accel,
		"air_control": air_control, "jump_velocity": jump_velocity, "gravity": gravity,
		"snap_move": snap_move, "hit_speed": hit_speed, "hit_min_up": hit_min_up,
		"hit_reflect": hit_reflect, "hit_push": hit_push, "hit_floor_vy": hit_floor_vy,
		"touch_cooldown_ticks": touch_cooldown_ticks, "ball_radius": ball_radius,
		"ball_gravity": ball_gravity, "ball_damp": ball_damp, "ball_bounce": ball_bounce,
		"ball_max_speed": ball_max_speed, "ball_substeps": ball_substeps,
	}
