class_name MatchView
extends Node2D

## Draws the match from sim state only (never writes to the sim):
## - meters → pixels, court fitted into the viewport;
## - positions captured per tick into a ring buffer (re-captured during rollback re-simulation);
## - rendered between the last two ticks (smooth on 90/120 Hz screens);
## - after a rollback the visible jump is turned into a fading offset (CorrectionSmoother),
##   so the ball and the opponent glide to the corrected place instead of teleporting;
##   only a rollback into another serve (ball and blobs reset) is shown as a jump.

const RING := 128
## Between two ticks a bigger move than this (m) is a teleport (serve reset): not interpolated.
const TELEPORT_M := 1.5

@export var court_view: CourtView
@export var ball_view: BallView
@export var blobs_parent: Node2D
@export var blob_template: PackedScene
@export var palette: TeamPalette
## Seconds for a small rollback correction to fade to ~37 % (≈ gone after 3×).
@export var correction_tau: float = 0.035
## Big corrections glide no faster than this (m/s); the ball flies at up to ~15.
@export var correction_max_speed: float = 25.0
@export var side_margin: float = 60.0
@export var top_margin: float = 120.0
@export var bottom_margin: float = 140.0

var px_per_m: float = 100.0
var floor_y: float = 760.0
var origin := Vector2(800, 760)

var _sim: VolleySim
var _blobs: Array[BlobView] = []
var _ring: Array = []
var _latest: int = -1
var _smoother := CorrectionSmoother.new()
var _correction_pending: bool = false
var _pre_tick: int = -1
var _pre_serve: int = -1
var _pre_players: Array[Vector2] = []
var _pre_ball := Vector2.ZERO
var _seen_touch: int = 0
var _seen_point: int = 0


func setup(sim: VolleySim, match_setup: MatchSetup, local_slots: Array[int]) -> void:
	_sim = sim
	_ring.resize(RING)
	_ring.fill(null)
	for child in blobs_parent.get_children():
		child.queue_free()
	_blobs.clear()
	var slots := match_setup.slots()
	for i in sim.player_count():
		var blob: BlobView = blob_template.instantiate()
		blobs_parent.add_child(blob)
		_blobs.append(blob)
	# Offsets: one per player, the ball last.
	_smoother.tau = correction_tau
	_smoother.max_speed = correction_max_speed
	_smoother.resize(_blobs.size() + 1)
	_correction_pending = false
	_layout()
	for i in _blobs.size():
		var team := int(sim.state["players"][i]["team"])
		var display_name := slots[i].display_name if i < slots.size() else ""
		_blobs[i].setup(palette.color(team), sim.param("blob_radius") * px_per_m, display_name, local_slots.has(i))
	ball_view.setup(sim.param("ball_radius") * px_per_m)
	_seen_touch = int(sim.state["touch_serial"])
	_seen_point = int(sim.state["point_serial"])
	capture(int(sim.state["tick"]))
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)


func capture(tick: int) -> void:
	var state: Dictionary = _sim.state
	var players: Array = state["players"]
	var p := PackedVector2Array()
	var vy := PackedFloat32Array()
	for player in players:
		p.append(Vector2(float(player["x"]), float(player["y"])))
		vy.append(float(player["vy"]))
	var ball: Dictionary = state["balls"][0]
	_ring[tick % RING] = {
		"tick": tick, "serve": _serve_number(state), "p": p, "vy": vy,
		"b": Vector2(float(ball["x"]), float(ball["y"])), "bvx": float(ball["vx"]), "bf": bool(ball["frozen"]),
	}
	_latest = tick


## Called when the session restored an older state; the next frame compares the old and the
## re-simulated value of the same tick and keeps the difference as a fading offset.
func on_rolled_back() -> void:
	if _correction_pending or _latest < 0:
		return
	var entry = _ring[_latest % RING]
	if entry == null:
		return
	_pre_tick = _latest
	_pre_serve = int(entry["serve"])
	_pre_players.assign(Array(entry["p"]))
	_pre_ball = entry["b"]
	_correction_pending = true


func _process(delta: float) -> void:
	if _sim == null or _latest < 0:
		return
	_apply_correction()
	var cur = _ring[_latest % RING]
	var prev = _ring[(_latest - 1 + RING) % RING]
	if cur == null:
		return
	if prev == null or int(prev["tick"]) != _latest - 1:
		prev = cur
	var frac := Engine.get_physics_interpolation_fraction()

	var ball_m := _lerp_m(prev["b"], cur["b"], frac) + _smoother.offset(_blobs.size())
	var ball_px := to_px(ball_m)
	for i in _blobs.size():
		var pos_m := _lerp_m(prev["p"][i], cur["p"][i], frac) + _smoother.offset(i)
		var on_floor := pos_m.y <= _sim.param("blob_radius") + 0.01
		_blobs[i].apply(to_px(pos_m), float(cur["vy"][i]), on_floor, floor_y, ball_px, delta)
	ball_view.apply(ball_px, float(cur["bvx"]), bool(cur["bf"]), floor_y, px_per_m, delta)
	_smoother.step(delta)
	_update_fx()


func to_px(pos_m: Vector2) -> Vector2:
	return origin + Vector2(pos_m.x * px_per_m, -pos_m.y * px_per_m)


func _apply_correction() -> void:
	if not _correction_pending:
		return
	_correction_pending = false
	var entry = _ring[_pre_tick % RING]
	if entry == null or int(entry["tick"]) != _pre_tick:
		return
	if int(entry["serve"]) != _pre_serve:
		_smoother.clear()
		return
	for i in mini(_pre_players.size(), _blobs.size()):
		_smoother.add(i, _pre_players[i] - entry["p"][i])
	_smoother.add(_blobs.size(), _pre_ball - entry["b"])


func _update_fx() -> void:
	var touch_serial := int(_sim.state["touch_serial"])
	if touch_serial > _seen_touch:
		var player := int(_sim.state["touch_player"])
		if player >= 0 and player < _blobs.size():
			_blobs[player].pulse()
	_seen_touch = touch_serial
	var point_serial := int(_sim.state["point_serial"])
	if point_serial > _seen_point:
		var ball: Dictionary = _sim.state["balls"][0]
		var team := int(_sim.state["point_team"])
		court_view.flash_zone(_sim.zone_of(float(ball["x"])), palette.color(team))
	_seen_point = point_serial


func _layout() -> void:
	var view := get_viewport_rect().size
	var arena: Dictionary = _sim.cfg["arena"]
	var half_width := float(arena["half_width"])
	var ceiling := float(arena["ceiling"])
	floor_y = view.y - bottom_margin
	px_per_m = minf((view.x - 2.0 * side_margin) / (2.0 * half_width), (floor_y - top_margin) / ceiling)
	origin = Vector2(view.x * 0.5, floor_y)
	var court := Rect2(origin.x - half_width * px_per_m, floor_y - ceiling * px_per_m, 2.0 * half_width * px_per_m, ceiling * px_per_m)
	var nets: Array[Dictionary] = []
	for net in _sim.state["nets"]:
		nets.append({
			"x": to_px(Vector2(float(net["x"]), 0.0)).x,
			"top": floor_y - float(net["top"]) * px_per_m,
			"w": 2.0 * float(net["half_w"]) * px_per_m,
		})
	var zones: Array[Dictionary] = []
	for zone in _sim.state["zones"]:
		zones.append({"x_min": to_px(Vector2(float(zone["x_min"]), 0.0)).x, "x_max": to_px(Vector2(float(zone["x_max"]), 0.0)).x})
	court_view.setup(court, nets, zones)


func _on_viewport_resized() -> void:
	if _sim == null:
		return
	_layout()
	for blob in _blobs:
		blob.radius_px = _sim.param("blob_radius") * px_per_m
	ball_view.radius_px = _sim.param("ball_radius") * px_per_m


static func _lerp_m(a: Vector2, b: Vector2, t: float) -> Vector2:
	if a.distance_to(b) > TELEPORT_M:
		return b
	return a.lerp(b, t)


## Counts serves begun: changes exactly when ball and blobs are reset to serve places.
static func _serve_number(state: Dictionary) -> int:
	var phase := int(state["phase"])
	var serving := phase == VolleySim.Phase.SERVE or phase == VolleySim.Phase.PLAY
	return int(state["point_serial"]) + (1 if serving else 0)
