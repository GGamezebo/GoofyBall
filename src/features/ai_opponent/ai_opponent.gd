class_name AiOpponent
extends RefCounted

## Bot for one player. Reads the sim state (and its static physics / arena numbers), returns
## a sim input. Predicts where the ball comes down on our side, stands a bit behind that point
## (away from the net) so the hit goes over, and jumps when the ball is in reach.
## Works for any team zone: positions are mirrored into "net at u = 0, my zone at u > 0" space.

const DT := 1.0 / 60.0
## Distance at which steering is full strength (±1).
const FULL_SPEED_DIST := 1.2
## Soft stop zone: ease to zero instead of a hard cut.
const STOP_DIST := 0.08
## How fast the steering axis catches up with the desired value (per second).
const AXIS_SMOOTH := 14.0
## Stand this far behind the landing point (away from the net) so the hit sends the ball over.
const AIM_BEHIND := 0.38
## Where to wait (fraction of the zone depth) while the ball is on the other side.
const HOME_FRACTION := 0.45
const JUMP_RANGE_X := 0.9
const JUMP_HEIGHT_MIN := 1.4
const JUMP_HEIGHT_MAX := 3.4
const PREDICT_STEPS := 300

## Player index in the sim this bot drives.
var player_index: int = 0
var _axis: float = 0.0


func _init(p_player_index: int = 0) -> void:
	player_index = p_player_index


func reset() -> void:
	_axis = 0.0


func decide(state: Dictionary, physics: Dictionary, arena: Dictionary) -> Dictionary:
	var player: Dictionary = state["players"][player_index]
	var ball: Dictionary = state["balls"][0]
	var blob_radius := float(physics["blob_radius"])
	var ball_radius := float(physics["ball_radius"])
	var step := AXIS_SMOOTH * DT
	if bool(ball["frozen"]) and int(state["phase"]) != 0:
		_axis = move_toward(_axis, 0.0, step)
		return {"x": roundi(_axis * 100.0), "j": 0, "a": 0}

	var zone: Dictionary = state["zones"][int(player["team"])]
	var zone_min := float(zone["x_min"])
	var zone_max := float(zone["x_max"])
	# Net side = the zone edge closer to the court center; `away` turns x into u.
	var net_x := zone_min if absf(zone_min) < absf(zone_max) else zone_max
	var away := 1.0 if (zone_min + zone_max) * 0.5 >= net_x else -1.0
	var depth := zone_max - zone_min

	var meet_y := 2.0 * blob_radius + ball_radius * 0.5
	var landing_x := float(ball["x"]) if bool(ball["frozen"]) else predict_x(ball, physics, float(arena["half_width"]), meet_y)
	var landing_u := (landing_x - net_x) * away
	var target_u := depth * HOME_FRACTION
	if landing_u > 0.0:
		target_u = landing_u + AIM_BEHIND
	target_u = clampf(target_u, blob_radius + 0.15, depth - blob_radius)

	var player_u := (float(player["x"]) - net_x) * away
	_axis = move_toward(_axis, _steer_axis(target_u - player_u) * away, step)

	var ball_u := (float(ball["x"]) - net_x) * away
	var near_x := absf(float(ball["x"]) - float(player["x"])) < JUMP_RANGE_X
	var descending := float(ball["vy"]) < 0.0
	var in_reach := float(ball["y"]) > JUMP_HEIGHT_MIN and float(ball["y"]) < JUMP_HEIGHT_MAX
	var on_floor := float(player["y"]) <= blob_radius + 0.001
	var jump := ball_u > 0.0 and near_x and descending and in_reach and on_floor and not bool(ball["frozen"])
	return {"x": roundi(_axis * 100.0), "j": 1 if jump else 0, "a": 0}


## Where the ball will be (x) when it falls to `target_y`: same gravity, damping and wall
## bounces as the sim, ignoring nets and players.
static func predict_x(ball: Dictionary, physics: Dictionary, half_width: float, target_y: float) -> float:
	var x := float(ball["x"])
	var y := float(ball["y"])
	var vx := float(ball["vx"])
	var vy := float(ball["vy"])
	var gravity := float(physics["ball_gravity"])
	var damp := maxf(0.0, 1.0 - float(physics["ball_damp"]) * DT)
	var bounce := float(physics["ball_bounce"])
	var limit := half_width - float(physics["ball_radius"])
	for _i in PREDICT_STEPS:
		if vy < 0.0 and y <= target_y:
			return x
		vy -= gravity * DT
		vx *= damp
		vy *= damp
		x += vx * DT
		y += vy * DT
		if x > limit:
			x = limit
			vx = -absf(vx) * bounce
		elif x < -limit:
			x = -limit
			vx = absf(vx) * bounce
	return x


static func _steer_axis(du: float) -> float:
	var distance := absf(du)
	if distance <= STOP_DIST:
		return 0.0
	# Proportional: closer → slower, far → full speed. Smoothstep softens the ramp.
	var t := clampf((distance - STOP_DIST) / (FULL_SPEED_DIST - STOP_DIST), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return signf(du) * t
