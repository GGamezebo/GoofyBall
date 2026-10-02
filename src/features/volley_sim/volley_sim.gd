class_name VolleySim
extends RefCounted

## Deterministic, tick-based volleyball simulation (the single source of gameplay truth).
##
## - No nodes, no engine physics, no randomness, no wall-clock time: only + - * / and sqrt,
##   so the same inputs give the same state on every device (required for rollback netcode).
## - Whole match state lives in `s` (plain Dictionary of ints/floats/bools/arrays) so it can be
##   saved/loaded/hashed by godot-rollback-netcode and compared in tests.
## - Rendering is a pure function of `s` (see MatchView). Visual FX are derived from the
##   `*_serial` counters, never fired from inside the sim, so rollbacks cannot duplicate them.
##
## Input per player per tick: {"x": int -100..100, "j": 0|1, "b": 0|1}.

const TICK_RATE := 60
const DT := 1.0 / 60.0

enum Phase { SERVE, PLAY, POINT, MATCH_END }
enum Msg { NONE, POINT, TIMEUP, TOUCHES, WIN, LAST_CHANCE }

# Court (meters). Matches the visual Court nodes in game.tscn.
const WALL_X := 6.8
const CEILING_Y := 6.95
const NET_HALF_W := 0.06
const NET_TOP := 2.4

# Blob
const BLOB_R := 0.42
const BLOB_FLOOR_Y := 0.42
const BLOB_START_X := 3.2
const MOVE_SPEED := 6.5
const JUMP_VELOCITY := 11.6
const GRAVITY := 22.0
const AIR_CONTROL := 0.55
const GROUND_ACCEL := 18.0
const NET_LIMIT_X := 0.55
const HIT_SPEED := 8.0
const HIT_MIN_UP := 4.0
const HIT_REFLECT := 0.4
const HIT_PUSH := 0.75
const HIT_FLOOR_VY := -10.0
const BLAST_SPEED := 18.0
const BLAST_UP := 5.0
const BLAST_RADIUS := 16.0

# Ball
const BALL_R := 0.35
const BALL_GRAVITY := 3.92 # 9.8 * gravity_scale 0.4
const BALL_DAMP := 0.115 # project default 0.1 + body 0.015
const BALL_BOUNCE := 0.78
const BALL_MAX_SPEED := 38.0
const FLOOR_SCORE_Y := 0.55
const BALL_SUBSTEPS := 4
const TOUCH_COOLDOWN_TICKS := 12
const SERVE_BALL_X := 2.2

# Phase lengths (ticks)
const SERVE_TICKS := 300
const POINT_TICKS := 66

var cfg: Dictionary = {}
var s: Dictionary = {}


## Build a sim config. `allow_blast` / `snap_move` are per-player [bool, bool].
static func make_config(
	win_score: int = 7,
	serve_height: float = 5.0,
	max_touches: int = 3,
	round_sec: float = 60.0,
	alarm_sec: float = 5.0,
	allow_blast: Array = [true, false],
	snap_move: Array = [true, true]
) -> Dictionary:
	return {
		"win_score": win_score,
		"serve_height": serve_height,
		"max_touches": max_touches,
		"round_ticks": int(round_sec * TICK_RATE),
		"alarm_ticks": int(alarm_sec * TICK_RATE),
		"allow_blast": allow_blast,
		"snap_move": snap_move,
	}


static func neutral_input() -> Dictionary:
	return {"x": 0, "j": 0, "b": 0}


func reset(p_cfg: Dictionary) -> void:
	cfg = p_cfg
	s = {
		"tick": 0,
		"phase": Phase.SERVE,
		"phase_ticks": 0,
		"score_l": 0,
		"score_r": 0,
		"serving_left": true,
		"time_left": int(cfg["round_ticks"]),
		"msg": Msg.NONE,
		"msg_side": 0,
		"touch_side": -1,
		"touch_count": 0,
		"winner": -1,
		"touch_serial": 0,
		"touch_blob": 0,
		"point_serial": 0,
		"point_side": 0,
		"blast_serial": 0,
		"blast_blob": 0,
		"explode_serial": 0,
		"p": [_new_blob(-BLOB_START_X), _new_blob(BLOB_START_X)],
		"ball": {
			"x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0,
			"frozen": true, "hidden": false, "last_touch": -1, "cooldown": 0,
		},
	}
	_begin_serve()


func save_state() -> Dictionary:
	return s.duplicate(true)


func load_state(state: Dictionary) -> void:
	s = state.duplicate(true)


func is_match_over() -> bool:
	return int(s["phase"]) == Phase.MATCH_END


## Advance one tick. `inputs` = [input_left, input_right].
func step(inputs: Array) -> void:
	s["tick"] = int(s["tick"]) + 1
	var blobs: Array = s["p"]
	for i in 2:
		var inp: Dictionary = inputs[i] if i < inputs.size() else neutral_input()
		_step_blob(i, blobs[i], inp)

	match int(s["phase"]):
		Phase.SERVE:
			s["phase_ticks"] = int(s["phase_ticks"]) + 1
			if int(s["phase_ticks"]) >= SERVE_TICKS:
				_start_play()
		Phase.PLAY:
			_step_play()
		Phase.POINT:
			s["phase_ticks"] = int(s["phase_ticks"]) + 1
			if int(s["phase_ticks"]) >= POINT_TICKS:
				_after_point()
		Phase.MATCH_END:
			s["phase_ticks"] = int(s["phase_ticks"]) + 1


# --- derived helpers for views / AI -------------------------------------------------

func serve_countdown_sec() -> int:
	return maxi(0, ceili(float(SERVE_TICKS - int(s["phase_ticks"])) / float(TICK_RATE)))


func time_left_sec() -> int:
	return maxi(0, ceili(float(int(s["time_left"])) / float(TICK_RATE)))


func is_alarm() -> bool:
	return int(s["phase"]) == Phase.PLAY and int(s["time_left"]) <= int(cfg["alarm_ticks"])


func can_blast(i: int) -> bool:
	if not bool(cfg["allow_blast"][i]):
		return false
	var blob: Dictionary = s["p"][i]
	var ball: Dictionary = s["ball"]
	if bool(blob["dead"]) or bool(blob["used"]) or bool(ball["frozen"]):
		return false
	return not _ball_on_opponent_half(i)


func is_on_floor(i: int) -> bool:
	var blob: Dictionary = s["p"][i]
	return float(blob["y"]) <= BLOB_FLOOR_Y + 0.001


func result_payload() -> Dictionary:
	return {
		"score_left": int(s["score_l"]),
		"score_right": int(s["score_r"]),
		"winner_side": int(s["winner"]),
	}


# --- blobs ------------------------------------------------------------------------

static func _new_blob(x: float) -> Dictionary:
	return {"x": x, "y": BLOB_FLOOR_Y, "vx": 0.0, "vy": 0.0, "dead": false, "used": false, "prev_b": 0}


func _step_blob(i: int, blob: Dictionary, inp: Dictionary) -> void:
	var blast_pressed := int(inp.get("b", 0)) != 0
	var blast_edge: bool = blast_pressed and int(blob["prev_b"]) == 0
	blob["prev_b"] = 1 if blast_pressed else 0
	if bool(blob["dead"]):
		return
	if blast_edge and can_blast(i):
		_blast(i, blob)
		return

	var axis := clampf(float(int(inp.get("x", 0))) / 100.0, -1.0, 1.0)
	var on_floor := float(blob["y"]) <= BLOB_FLOOR_Y + 0.001
	var target_vx := axis * MOVE_SPEED
	if bool(cfg["snap_move"][i]) and on_floor:
		blob["vx"] = target_vx
	else:
		var accel := GROUND_ACCEL if on_floor else MOVE_SPEED * AIR_CONTROL * 8.0
		blob["vx"] = move_toward(float(blob["vx"]), target_vx, accel * DT)

	if int(inp.get("j", 0)) != 0 and on_floor:
		blob["vy"] = JUMP_VELOCITY
		on_floor = false
	if not on_floor:
		blob["vy"] = float(blob["vy"]) - GRAVITY * DT

	blob["x"] = float(blob["x"]) + float(blob["vx"]) * DT
	blob["y"] = float(blob["y"]) + float(blob["vy"]) * DT
	if float(blob["y"]) <= BLOB_FLOOR_Y:
		blob["y"] = BLOB_FLOOR_Y
		if float(blob["vy"]) < 0.0:
			blob["vy"] = 0.0
	_clamp_blob_x(i, blob)


func _clamp_blob_x(i: int, blob: Dictionary) -> void:
	var x := float(blob["x"])
	var vx := float(blob["vx"])
	var limit := WALL_X - BLOB_R
	if i == 0:
		if x > -NET_LIMIT_X:
			x = -NET_LIMIT_X
			if vx > 0.0:
				vx = 0.0
		if x < -limit:
			x = -limit
			if vx < 0.0:
				vx = 0.0
	else:
		if x < NET_LIMIT_X:
			x = NET_LIMIT_X
			if vx < 0.0:
				vx = 0.0
		if x > limit:
			x = limit
			if vx > 0.0:
				vx = 0.0
	blob["x"] = x
	blob["vx"] = vx


func _ball_on_opponent_half(i: int) -> bool:
	var bx := float(s["ball"]["x"])
	return bx > 0.0 if i == 0 else bx < 0.0


func _blast(i: int, blob: Dictionary) -> void:
	blob["used"] = true
	blob["dead"] = true
	blob["vx"] = 0.0
	blob["vy"] = 0.0
	s["blast_serial"] = int(s["blast_serial"]) + 1
	s["blast_blob"] = i
	s["msg"] = Msg.LAST_CHANCE
	var ball: Dictionary = s["ball"]
	var dx := float(ball["x"]) - float(blob["x"])
	var dy := float(ball["y"]) - float(blob["y"])
	var dist := sqrt(dx * dx + dy * dy)
	var toward_opp := 1.0 if i == 0 else -1.0
	var dirx: float
	var diry: float
	if dist < 0.05:
		dirx = toward_opp
		diry = 0.35
	else:
		dirx = dx / dist
		diry = dy / dist
	var n0 := sqrt(dirx * dirx + diry * diry)
	dirx /= n0
	diry /= n0
	dirx = dirx + (toward_opp - dirx) * 0.35
	var n1 := sqrt(dirx * dirx + diry * diry)
	dirx /= n1
	diry /= n1
	var falloff := 1.0 - clampf(dist / BLAST_RADIUS, 0.0, 1.0)
	var power := BLAST_SPEED * (0.55 + 0.45 * falloff)
	ball["vx"] = dirx * power
	ball["vy"] = diry * power + BLAST_UP * (0.5 + 0.5 * falloff)


# --- phases -----------------------------------------------------------------------

func _begin_serve() -> void:
	s["phase"] = Phase.SERVE
	s["phase_ticks"] = 0
	s["touch_side"] = -1
	s["touch_count"] = 0
	s["time_left"] = int(cfg["round_ticks"])
	s["msg"] = Msg.NONE
	var blobs: Array = s["p"]
	for i in 2:
		var blob: Dictionary = blobs[i]
		blob["x"] = -BLOB_START_X if i == 0 else BLOB_START_X
		blob["y"] = BLOB_FLOOR_Y
		blob["vx"] = 0.0
		blob["vy"] = 0.0
		blob["dead"] = false
		blob["used"] = false
	var ball: Dictionary = s["ball"]
	ball["x"] = -SERVE_BALL_X if bool(s["serving_left"]) else SERVE_BALL_X
	ball["y"] = float(cfg["serve_height"])
	ball["vx"] = 0.0
	ball["vy"] = 0.0
	ball["frozen"] = true
	ball["hidden"] = false
	ball["last_touch"] = -1
	ball["cooldown"] = 0


func _start_play() -> void:
	s["phase"] = Phase.PLAY
	s["phase_ticks"] = 0
	s["touch_side"] = -1
	s["touch_count"] = 0
	s["time_left"] = int(cfg["round_ticks"])
	s["msg"] = Msg.NONE
	s["ball"]["frozen"] = false


func _after_point() -> void:
	var win: int = int(cfg["win_score"])
	var sl := int(s["score_l"])
	var sr := int(s["score_r"])
	if sl >= win or sr >= win:
		s["phase"] = Phase.MATCH_END
		s["phase_ticks"] = 0
		s["winner"] = 0 if sl > sr else (1 if sr > sl else -1)
		s["msg"] = Msg.WIN
		s["msg_side"] = int(s["winner"])
	else:
		_begin_serve()


## `loser` = side that lost the rally (0 = left/Blue, 1 = right/Red).
func _award_point(loser: int, msg: int) -> void:
	if loser == 0:
		s["score_r"] = int(s["score_r"]) + 1
		s["serving_left"] = false
	else:
		s["score_l"] = int(s["score_l"]) + 1
		s["serving_left"] = true
	s["msg"] = msg
	s["msg_side"] = loser
	s["point_serial"] = int(s["point_serial"]) + 1
	s["point_side"] = loser
	s["phase"] = Phase.POINT
	s["phase_ticks"] = 0
	s["ball"]["frozen"] = true


func _explode_ball() -> void:
	var ball: Dictionary = s["ball"]
	ball["frozen"] = true
	ball["hidden"] = true
	ball["vx"] = 0.0
	ball["vy"] = 0.0
	s["explode_serial"] = int(s["explode_serial"]) + 1


# --- ball -------------------------------------------------------------------------

func _step_play() -> void:
	var ball: Dictionary = s["ball"]
	s["time_left"] = int(s["time_left"]) - 1
	ball["cooldown"] = maxi(0, int(ball["cooldown"]) - 1)

	var vx := float(ball["vx"])
	var vy := float(ball["vy"])
	vy -= BALL_GRAVITY * DT
	var damp := maxf(0.0, 1.0 - BALL_DAMP * DT)
	vx *= damp
	vy *= damp
	var speed := sqrt(vx * vx + vy * vy)
	if speed > BALL_MAX_SPEED:
		vx = vx / speed * BALL_MAX_SPEED
		vy = vy / speed * BALL_MAX_SPEED
	ball["vx"] = vx
	ball["vy"] = vy

	var sub_dt := DT / float(BALL_SUBSTEPS)
	for _k in BALL_SUBSTEPS:
		ball["x"] = float(ball["x"]) + float(ball["vx"]) * sub_dt
		ball["y"] = float(ball["y"]) + float(ball["vy"]) * sub_dt
		_collide_walls(ball)
		_collide_net(ball)
		if _collide_blobs(ball):
			return # round ended by a touch fault

	if float(ball["y"]) <= FLOOR_SCORE_Y and (float(ball["vy"]) < -1.0 or float(ball["y"]) <= BALL_R + 0.01):
		var side := 0 if float(ball["x"]) < 0.0 else 1
		_award_point(side, Msg.POINT)
		return

	if int(s["time_left"]) <= 0:
		var side_t := 0 if float(ball["x"]) < 0.0 else 1
		_explode_ball()
		_award_point(side_t, Msg.TIMEUP)


func _collide_walls(ball: Dictionary) -> void:
	var x := float(ball["x"])
	var y := float(ball["y"])
	var lim := WALL_X - BALL_R
	if x > lim:
		ball["x"] = lim
		ball["vx"] = -absf(float(ball["vx"])) * BALL_BOUNCE
	elif x < -lim:
		ball["x"] = -lim
		ball["vx"] = absf(float(ball["vx"])) * BALL_BOUNCE
	var top := CEILING_Y - BALL_R
	if y > top:
		ball["y"] = top
		ball["vy"] = -absf(float(ball["vy"])) * BALL_BOUNCE


func _collide_net(ball: Dictionary) -> void:
	var x := float(ball["x"])
	var y := float(ball["y"])
	var cx := clampf(x, -NET_HALF_W, NET_HALF_W)
	var cy := clampf(y, 0.0, NET_TOP)
	var dx := x - cx
	var dy := y - cy
	var d2 := dx * dx + dy * dy
	if d2 >= BALL_R * BALL_R:
		return
	var nx: float
	var ny: float
	var dist := sqrt(d2)
	if dist < 0.0001:
		# Center inside the net box: push out sideways along the travel direction.
		nx = 1.0 if x >= 0.0 else -1.0
		ny = 0.0
		dist = 0.0
	else:
		nx = dx / dist
		ny = dy / dist
	var push := BALL_R - dist
	ball["x"] = x + nx * push
	ball["y"] = y + ny * push
	var vn := float(ball["vx"]) * nx + float(ball["vy"]) * ny
	if vn < 0.0:
		ball["vx"] = float(ball["vx"]) - (1.0 + BALL_BOUNCE) * vn * nx
		ball["vy"] = float(ball["vy"]) - (1.0 + BALL_BOUNCE) * vn * ny


## Returns true when a touch fault ended the rally.
func _collide_blobs(ball: Dictionary) -> bool:
	var blobs: Array = s["p"]
	var reach := BLOB_R + BALL_R
	for i in 2:
		var blob: Dictionary = blobs[i]
		if bool(blob["dead"]):
			continue
		var dx := float(ball["x"]) - float(blob["x"])
		var dy := float(ball["y"]) - float(blob["y"])
		var d2 := dx * dx + dy * dy
		if d2 >= reach * reach:
			continue
		var dist := sqrt(d2)
		var nx: float
		var ny: float
		if dist < 0.001:
			nx = 0.0
			ny = 1.0
			dist = 0.0
		else:
			nx = dx / dist
			ny = dy / dist
		# Blobs are kinematic: always separate the ball.
		var push := reach - dist
		ball["x"] = float(ball["x"]) + nx * push
		ball["y"] = float(ball["y"]) + ny * push

		var debounced: bool = int(ball["last_touch"]) == i and int(ball["cooldown"]) > 0
		if debounced:
			continue
		_apply_hit(blob, ball, nx, ny)
		ball["last_touch"] = i
		ball["cooldown"] = TOUCH_COOLDOWN_TICKS
		s["touch_serial"] = int(s["touch_serial"]) + 1
		s["touch_blob"] = i
		if _register_touch(i):
			return true
	return false


func _apply_hit(blob: Dictionary, ball: Dictionary, nx: float, ny: float) -> void:
	var loft := clampf(ny, 0.0, 1.0)
	var ivx := float(ball["vx"])
	var ivy := float(ball["vy"])
	var dot := ivx * nx + ivy * ny
	var bx := ivx - 2.0 * dot * nx
	var by := ivy - 2.0 * dot * ny
	var nvx := bx * HIT_REFLECT + nx * HIT_SPEED * HIT_PUSH + float(blob["vx"]) * 0.75
	var nvy := by * HIT_REFLECT + ny * HIT_SPEED * HIT_PUSH + float(blob["vy"]) * 0.5
	if loft > 0.2:
		nvy = maxf(nvy, HIT_MIN_UP * loft)
	else:
		nvy = maxf(nvy, HIT_FLOOR_VY)
	ball["vx"] = nvx
	ball["vy"] = nvy


## Returns true when the touch caused a fault (rally ended).
func _register_touch(side: int) -> bool:
	if side != int(s["touch_side"]):
		s["touch_side"] = side
		s["touch_count"] = 1
	else:
		s["touch_count"] = int(s["touch_count"]) + 1
	if int(s["touch_count"]) > int(cfg["max_touches"]):
		_explode_ball()
		_award_point(side, Msg.TOUCHES)
		return true
	return false
