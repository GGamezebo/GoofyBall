class_name VolleySim
extends RefCounted

## Deterministic volleyball simulation (rollback-safe). The only gameplay truth.
## - State is a plain Dictionary (save / load / hash), ticks at 60 Hz, no nodes or engine physics.
## - Floats use only + - * / and sqrt; randomness = xorshift int stored in the state.
## - N teams × N players: the court is split into one zone per team, nets between neighbours.
## - Never emits signals or FX: views read `state` and edge-detect the `*_serial` counters.
## Input per player: {"x": -100..100, "j": 0|1, "a": 0|1}.

enum Phase { SERVE, PLAY, POINT, MATCH_END }
enum Reason { NONE, FLOOR, TOUCHES }

const TICK_RATE := 60
const DT := 1.0 / 60.0

## Static per match: physics, arena, rules, team sizes (see MatchSetup.to_sim_config()).
var cfg: Dictionary = {}
var state: Dictionary = {}


static func neutral_input() -> Dictionary:
	return {"x": 0, "j": 0, "a": 0}


func reset(config: Dictionary) -> void:
	cfg = config.duplicate(true)
	var arena: Dictionary = cfg["arena"]
	var team_sizes: Array = cfg["team_sizes"]
	var teams := team_sizes.size()
	var half_width := float(arena["half_width"])
	var zone_width := 2.0 * half_width / float(teams)

	var zones: Array = []
	var nets: Array = []
	for team in teams:
		var x_min := -half_width + zone_width * float(team)
		zones.append({"team": team, "x_min": x_min, "x_max": x_min + zone_width})
		if team > 0:
			nets.append({"x": x_min, "half_w": float(arena["net_half_width"]), "top": float(arena["net_height"])})

	var players: Array = []
	for team in teams:
		for _k in int(team_sizes[team]):
			players.append({"team": team, "x": 0.0, "y": param("blob_radius"), "vx": 0.0, "vy": 0.0})

	var scores: Array = []
	for _team in teams:
		scores.append(0)

	var rng := int(cfg["seed"]) & 0xFFFFFFFF
	if rng == 0:
		rng = 0x9E3779B9
	state = {
		"tick": 0,
		"phase": Phase.SERVE,
		"phase_ticks": 0,
		"rng": rng,
		"scores": scores,
		"serving_team": 0,
		"winner_team": -1,
		"touch_team": -1,
		"touch_count": 0,
		"zones": zones,
		"nets": nets,
		"players": players,
		"balls": [{"x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "frozen": true, "last_toucher": -1, "cooldown": 0}],
		"touch_serial": 0,
		"touch_player": -1,
		"point_serial": 0,
		"point_team": -1,
		"point_reason": Reason.NONE,
	}
	state["serving_team"] = _next_random() % teams
	_begin_serve()


func save_state() -> Dictionary:
	return state.duplicate(true)


func load_state(saved: Dictionary) -> void:
	state = saved.duplicate(true)


func state_hash() -> int:
	return state.hash()


func team_count() -> int:
	return (cfg["team_sizes"] as Array).size()


func player_count() -> int:
	return (state["players"] as Array).size()


func is_match_over() -> bool:
	return int(state["phase"]) == Phase.MATCH_END


## One tick. `inputs[i]` belongs to player i (MatchSetup slot order); missing = neutral.
func step(inputs: Array) -> void:
	state["tick"] = int(state["tick"]) + 1
	var players: Array = state["players"]
	for i in players.size():
		var input: Dictionary = inputs[i] if i < inputs.size() and inputs[i] is Dictionary else {}
		_step_player(players[i], input)

	var rules: Dictionary = cfg["rules"]
	match int(state["phase"]):
		Phase.SERVE:
			state["phase_ticks"] = int(state["phase_ticks"]) + 1
			if int(state["phase_ticks"]) >= int(rules["serve_delay_ticks"]):
				_start_play()
		Phase.PLAY:
			_step_play()
		Phase.POINT:
			state["phase_ticks"] = int(state["phase_ticks"]) + 1
			if int(state["phase_ticks"]) >= int(rules["point_pause_ticks"]):
				_after_point()
		Phase.MATCH_END:
			state["phase_ticks"] = int(state["phase_ticks"]) + 1


## Physics value for `target` (player / ball dict). Iteration 1: the preset value; buffs will
## stack modifiers on top here (preset ⊕ modifiers) without touching the callers.
func param(name: String, _target: Dictionary = {}) -> float:
	return float(cfg["physics"][name])


func is_on_floor(player_index: int) -> bool:
	var player: Dictionary = state["players"][player_index]
	return float(player["y"]) <= param("blob_radius") + 0.001


## Horizontal limits [lo, hi] for a player center inside its team zone (walls and nets).
func player_limits(team: int) -> Array:
	var arena: Dictionary = cfg["arena"]
	var radius := param("blob_radius")
	var zone: Dictionary = state["zones"][team]
	var half_width := float(arena["half_width"])
	var net_gap := float(arena["net_half_width"]) + radius + float(arena["net_clearance"])
	var lo := float(zone["x_min"]) + (radius if float(zone["x_min"]) <= -half_width + 0.0001 else net_gap)
	var hi := float(zone["x_max"]) - (radius if float(zone["x_max"]) >= half_width - 0.0001 else net_gap)
	return [lo, hi]


func zone_of(x: float) -> int:
	var zones: Array = state["zones"]
	for zone in zones:
		if x < float(zone["x_max"]):
			return int(zone["team"])
	return int(zones.back()["team"])


# --- players ----------------------------------------------------------------------------

func _step_player(player: Dictionary, input: Dictionary) -> void:
	var physics: Dictionary = cfg["physics"]
	var radius := param("blob_radius")
	var move_speed := param("move_speed")
	var axis := clampf(float(int(input.get("x", 0))) / 100.0, -1.0, 1.0)
	var on_floor := float(player["y"]) <= radius + 0.001
	var target_vx := axis * move_speed
	if bool(physics["snap_move"]) and on_floor:
		player["vx"] = target_vx
	else:
		var accel := param("ground_accel") if on_floor else move_speed * param("air_control") * 8.0
		player["vx"] = move_toward(float(player["vx"]), target_vx, accel * DT)

	if int(input.get("j", 0)) != 0 and on_floor:
		player["vy"] = param("jump_velocity")
		on_floor = false
	if not on_floor:
		player["vy"] = float(player["vy"]) - param("gravity") * DT

	player["x"] = float(player["x"]) + float(player["vx"]) * DT
	player["y"] = float(player["y"]) + float(player["vy"]) * DT
	if float(player["y"]) <= radius:
		player["y"] = radius
		if float(player["vy"]) < 0.0:
			player["vy"] = 0.0

	var limits := player_limits(int(player["team"]))
	var x := float(player["x"])
	if x < float(limits[0]):
		player["x"] = float(limits[0])
		if float(player["vx"]) < 0.0:
			player["vx"] = 0.0
	elif x > float(limits[1]):
		player["x"] = float(limits[1])
		if float(player["vx"]) > 0.0:
			player["vx"] = 0.0


# --- rally flow -------------------------------------------------------------------------

func _begin_serve() -> void:
	var arena: Dictionary = cfg["arena"]
	state["phase"] = Phase.SERVE
	state["phase_ticks"] = 0
	state["touch_team"] = -1
	state["touch_count"] = 0

	var radius := param("blob_radius")
	var players: Array = state["players"]
	var zones: Array = state["zones"]
	var team_sizes: Array = cfg["team_sizes"]
	var index := 0
	for team in team_sizes.size():
		var zone: Dictionary = zones[team]
		var size := int(team_sizes[team])
		for k in size:
			var player: Dictionary = players[index]
			var t := float(k + 1) / float(size + 1)
			player["x"] = float(zone["x_min"]) + (float(zone["x_max"]) - float(zone["x_min"])) * t
			player["y"] = radius
			player["vx"] = 0.0
			player["vy"] = 0.0
			index += 1

	var server := _first_player_of(int(state["serving_team"]))
	var server_x := float(server["x"])
	var toward_center := 0.0
	if server_x < 0.0:
		toward_center = 1.0
	elif server_x > 0.0:
		toward_center = -1.0
	var ball: Dictionary = state["balls"][0]
	ball["x"] = server_x + toward_center * float(arena["serve_offset"])
	ball["y"] = float(arena["serve_height"])
	ball["vx"] = 0.0
	ball["vy"] = 0.0
	ball["frozen"] = true
	ball["last_toucher"] = -1
	ball["cooldown"] = 0


func _start_play() -> void:
	state["phase"] = Phase.PLAY
	state["phase_ticks"] = 0
	for ball in state["balls"]:
		ball["frozen"] = false


func _rally_lost(losing_team: int, reason: int) -> void:
	var scoring_team := TwoTeamPoints.rally_winner(losing_team)
	var scores: Array = state["scores"]
	scores[scoring_team] = int(scores[scoring_team]) + 1
	state["serving_team"] = scoring_team
	state["point_serial"] = int(state["point_serial"]) + 1
	state["point_team"] = scoring_team
	state["point_reason"] = reason
	state["phase"] = Phase.POINT
	state["phase_ticks"] = 0
	for ball in state["balls"]:
		ball["frozen"] = true
		ball["vx"] = 0.0
		ball["vy"] = 0.0


func _after_point() -> void:
	var winner := TwoTeamPoints.match_winner(state["scores"], int(cfg["rules"]["win_score"]))
	if winner >= 0:
		state["phase"] = Phase.MATCH_END
		state["phase_ticks"] = 0
		state["winner_team"] = winner
		return
	_begin_serve()


func _first_player_of(team: int) -> Dictionary:
	for player in state["players"]:
		if int(player["team"]) == team:
			return player
	return state["players"][0]


# --- ball -------------------------------------------------------------------------------

func _step_play() -> void:
	var physics: Dictionary = cfg["physics"]
	var arena: Dictionary = cfg["arena"]
	var ball: Dictionary = state["balls"][0]
	ball["cooldown"] = maxi(0, int(ball["cooldown"]) - 1)

	var vx := float(ball["vx"])
	var vy := float(ball["vy"])
	vy -= param("ball_gravity") * DT
	var damp := maxf(0.0, 1.0 - param("ball_damp") * DT)
	vx *= damp
	vy *= damp
	var max_speed := param("ball_max_speed")
	var speed := sqrt(vx * vx + vy * vy)
	if speed > max_speed:
		vx = vx / speed * max_speed
		vy = vy / speed * max_speed
	ball["vx"] = vx
	ball["vy"] = vy

	var substeps := int(physics["ball_substeps"])
	var sub_dt := DT / float(substeps)
	for _k in substeps:
		ball["x"] = float(ball["x"]) + float(ball["vx"]) * sub_dt
		ball["y"] = float(ball["y"]) + float(ball["vy"]) * sub_dt
		_collide_walls(ball)
		for net in state["nets"]:
			_collide_net(ball, net)
		if _collide_players(ball):
			return # touch fault ended the rally

	var ball_radius := param("ball_radius")
	if float(ball["y"]) <= float(arena["floor_score_y"]) and (float(ball["vy"]) < -1.0 or float(ball["y"]) <= ball_radius + 0.01):
		_rally_lost(zone_of(float(ball["x"])), Reason.FLOOR)


func _collide_walls(ball: Dictionary) -> void:
	var arena: Dictionary = cfg["arena"]
	var radius := param("ball_radius")
	var bounce := param("ball_bounce")
	var limit := float(arena["half_width"]) - radius
	var x := float(ball["x"])
	if x > limit:
		ball["x"] = limit
		ball["vx"] = -absf(float(ball["vx"])) * bounce
	elif x < -limit:
		ball["x"] = -limit
		ball["vx"] = absf(float(ball["vx"])) * bounce
	var top := float(arena["ceiling"]) - radius
	if float(ball["y"]) > top:
		ball["y"] = top
		ball["vy"] = -absf(float(ball["vy"])) * bounce


func _collide_net(ball: Dictionary, net: Dictionary) -> void:
	var radius := param("ball_radius")
	var x := float(ball["x"])
	var y := float(ball["y"])
	var net_x := float(net["x"])
	var half_w := float(net["half_w"])
	var cx := clampf(x, net_x - half_w, net_x + half_w)
	var cy := clampf(y, 0.0, float(net["top"]))
	var dx := x - cx
	var dy := y - cy
	var d2 := dx * dx + dy * dy
	if d2 >= radius * radius:
		return
	var nx: float
	var ny: float
	var dist := sqrt(d2)
	if dist < 0.0001:
		# Center inside the net box: push out sideways, away from the net center.
		nx = 1.0 if x >= net_x else -1.0
		ny = 0.0
		dist = 0.0
	else:
		nx = dx / dist
		ny = dy / dist
	var push := radius - dist
	ball["x"] = x + nx * push
	ball["y"] = y + ny * push
	var vn := float(ball["vx"]) * nx + float(ball["vy"]) * ny
	if vn < 0.0:
		var bounce := param("ball_bounce")
		ball["vx"] = float(ball["vx"]) - (1.0 + bounce) * vn * nx
		ball["vy"] = float(ball["vy"]) - (1.0 + bounce) * vn * ny


## Returns true when a touch fault ended the rally.
func _collide_players(ball: Dictionary) -> bool:
	var physics: Dictionary = cfg["physics"]
	var reach := param("blob_radius") + param("ball_radius")
	var players: Array = state["players"]
	for i in players.size():
		var player: Dictionary = players[i]
		var dx := float(ball["x"]) - float(player["x"])
		var dy := float(ball["y"]) - float(player["y"])
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

		if int(ball["last_toucher"]) == i and int(ball["cooldown"]) > 0:
			continue
		_apply_hit(player, ball, nx, ny)
		ball["last_toucher"] = i
		ball["cooldown"] = int(physics["touch_cooldown_ticks"])
		state["touch_serial"] = int(state["touch_serial"]) + 1
		state["touch_player"] = i
		if _register_touch(int(player["team"])):
			return true
	return false


func _apply_hit(player: Dictionary, ball: Dictionary, nx: float, ny: float) -> void:
	var loft := clampf(ny, 0.0, 1.0)
	var ivx := float(ball["vx"])
	var ivy := float(ball["vy"])
	var dot := ivx * nx + ivy * ny
	var bx := ivx - 2.0 * dot * nx
	var by := ivy - 2.0 * dot * ny
	var hit := param("hit_speed") * param("hit_push")
	var reflect := param("hit_reflect")
	var nvx := bx * reflect + nx * hit + float(player["vx"]) * 0.75
	var nvy := by * reflect + ny * hit + float(player["vy"]) * 0.5
	if loft > 0.2:
		nvy = maxf(nvy, param("hit_min_up") * loft)
	else:
		nvy = maxf(nvy, param("hit_floor_vy"))
	ball["vx"] = nvx
	ball["vy"] = nvy


## Returns true when this touch is one too many for the team (rally lost).
func _register_touch(team: int) -> bool:
	if team != int(state["touch_team"]):
		state["touch_team"] = team
		state["touch_count"] = 1
	else:
		state["touch_count"] = int(state["touch_count"]) + 1
	if int(state["touch_count"]) > int(cfg["rules"]["max_touches"]):
		_rally_lost(team, Reason.TOUCHES)
		return true
	return false


## xorshift32 on the int stored in the state.
func _next_random() -> int:
	var x := int(state["rng"])
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	x &= 0xFFFFFFFF
	state["rng"] = x
	return x
