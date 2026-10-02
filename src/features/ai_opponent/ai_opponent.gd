class_name AiOpponent
extends RefCounted

## Reactive bot for the right-side blob. Pure function of the sim state (plus a
## smoothed steering value), so it is trivially testable and never touches nodes.

const COURT_RIGHT := 6.2
## Distance at which steering is full strength (±1).
const FULL_SPEED_DIST := 1.6
## Soft stop zone — ease to zero instead of hard cut.
const STOP_DIST := 0.12
## How fast the steering axis catches up to the desired value (per second).
const AXIS_SMOOTH := 10.0
const JUMP_RANGE_X := 1.4
const JUMP_HEIGHT_MAX := 4.5
const JUMP_HEIGHT_MIN := 0.9
const LEAD_TIME := 0.22
## Stand this far BEHIND the ball (away from the net) so the hit sends it over the net,
## instead of popping it straight up and re-hitting it until the 3-touch fault.
const AIM_BEHIND := 0.5

## Which blob this bot drives (0 = left/Blue, 1 = right/Red).
var side: int = 1
var _axis: float = 0.0


func reset() -> void:
	_axis = 0.0


## Returns a sim input dictionary for the right blob.
func decide(state: Dictionary) -> Dictionary:
	var blob: Dictionary = state["p"][side]
	var ball: Dictionary = state["ball"]
	var step := AXIS_SMOOTH * VolleySim.DT

	if bool(ball["frozen"]) or bool(blob["dead"]):
		_axis = move_toward(_axis, 0.0, step)
		return {"x": roundi(_axis * 100.0), "j": 0, "b": 0}

	# Mirror everything into "right side" space so one code path serves both blobs.
	var sgn := 1.0 if side == 1 else -1.0
	var ball_x := float(ball["x"]) * sgn
	var ball_vx := float(ball["vx"]) * sgn
	var target_x := ball_x
	if ball_vx > 0.35:
		target_x += ball_vx * LEAD_TIME
	if ball_x > 0.0:
		target_x += AIM_BEHIND
	target_x = clampf(target_x, VolleySim.NET_LIMIT_X, COURT_RIGHT)

	_axis = move_toward(_axis, _steer_axis(target_x - float(blob["x"]) * sgn) * sgn, step)

	var near_x := absf(float(ball["x"]) - float(blob["x"])) < JUMP_RANGE_X
	var descending := float(ball["vy"]) < 0.5
	var good_height := float(ball["y"]) < JUMP_HEIGHT_MAX and float(ball["y"]) > JUMP_HEIGHT_MIN
	var on_floor := float(blob["y"]) <= VolleySim.BLOB_FLOOR_Y + 0.001
	var jump := near_x and descending and good_height and on_floor
	return {"x": roundi(_axis * 100.0), "j": 1 if jump else 0, "b": 0}


static func _steer_axis(dx: float) -> float:
	var abs_dx := absf(dx)
	if abs_dx <= STOP_DIST:
		return 0.0
	# Proportional: closer → slower, far → full speed. Smoothstep softens the ramp.
	var t := clampf((abs_dx - STOP_DIST) / (FULL_SPEED_DIST - STOP_DIST), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return signf(dx) * t
