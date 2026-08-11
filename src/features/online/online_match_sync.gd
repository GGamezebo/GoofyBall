class_name OnlineMatchSync
extends Node

## CS-style listen-server sync.
## Host (peer 1) runs match logic + physics. Guests predict local blob,
## interpolate remote blob + ball from a delayed snapshot buffer.

signal ev_remote_match_over(payload: Dictionary)
signal ev_hud(score_left: int, score_right: int, message: String, timer_sec: int)
signal ev_names_changed(left_name: String, right_name: String)

const SYNC_HZ := 30.0
const READY_DELAY_SEC := 0.25
## Render remotes this far behind the latest snapshot (CS interpolation).
const INTERP_DELAY_SEC := 0.1
const SNAPSHOT_LIMIT := 48

var left: BlobPlayer
var right: BlobPlayer
var ball: Ball
var local_side: int = 0
var local_display_name: String = "YOU"
var active: bool = false

var left_display_name: String = "BLUE"
var right_display_name: String = "RED"

var _remote_axis: float = 0.0
var _remote_jump: bool = false
var _remote_blast: bool = false
var _sync_accum: float = 0.0
var _ready_accum: float = 0.0
var _peers_ready: bool = false
var _last_message: String = ""
var _last_timer: int = -1
var _score_left: int = 0
var _score_right: int = 0
var _last_sent_axis: float = 0.0
var _last_sent_jump: bool = false
var _hello_sent: bool = false
var _server_tick: int = 0

## Guest snapshot buffer: each entry stamped with local recv time.
var _snapshots: Array[Dictionary] = []
var _latest_snap: Dictionary = {}
## Local blast prediction: wait until authority reports dead before accepting revive.
var _local_auth_saw_dead: bool = false


func setup(
	p_left: BlobPlayer,
	p_right: BlobPlayer,
	p_ball: Ball,
	p_local_side: int,
	p_local_name: String = ""
) -> void:
	left = p_left
	right = p_right
	ball = p_ball
	local_side = p_local_side
	local_display_name = p_local_name.strip_edges()
	if local_display_name.is_empty():
		local_display_name = "YOU"
	active = true
	_peers_ready = false
	_ready_accum = 0.0
	_hello_sent = false
	_server_tick = 0
	_snapshots.clear()
	_latest_snap.clear()
	_local_auth_saw_dead = false
	process_physics_priority = -100
	set_multiplayer_authority(1)
	_configure_actors()
	_apply_local_name()
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	ev_names_changed.emit(left_display_name, right_display_name)


func shutdown() -> void:
	active = false
	_peers_ready = false
	_snapshots.clear()
	_latest_snap.clear()
	var api := multiplayer
	if api == null:
		return
	if api.peer_connected.is_connected(_on_peer_connected):
		api.peer_connected.disconnect(_on_peer_connected)
	if api.peer_disconnected.is_connected(_on_peer_disconnected):
		api.peer_disconnected.disconnect(_on_peer_disconnected)


func request_local_blast() -> void:
	if not active:
		return
	var axis := Input.get_axis("p1_left", "p1_right")
	var jump := Input.is_action_pressed("p1_jump")
	if is_host():
		_apply_input_to_side(local_side, axis, jump, true)
	elif _peers_ready and _has_peer(1):
		# Predict blast locally; host confirms via world state.
		_apply_input_to_side(local_side, axis, jump, true)
		rpc_id(1, "_rpc_input", axis, jump, true)


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func notify_hud(score_left: int, score_right: int, message: String, timer_sec: int) -> void:
	if not active or not is_host():
		return
	_score_left = score_left
	_score_right = score_right
	_last_message = message
	_last_timer = timer_sec
	if _peers_ready:
		_broadcast_state(true)


func notify_match_over(payload: Dictionary) -> void:
	if not active or not is_host():
		return
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "_rpc_match_over", payload)


func _apply_local_name() -> void:
	if local_side == 0:
		left_display_name = local_display_name
	else:
		right_display_name = local_display_name


func _configure_actors() -> void:
	# Listen-server: host simulates both. Guests predict local side only.
	if is_host():
		for blob in [left, right]:
			if blob == null:
				continue
			blob.use_player_input = false
			blob.allow_last_chance = true
			blob.network_puppet = false
			blob.net_has_target = false
		if ball:
			ball.network_puppet = false
			ball.net_has_target = false
	else:
		if left:
			left.use_player_input = false
			left.allow_last_chance = true
			left.network_puppet = local_side != 0
			left.net_has_target = false
		if right:
			right.use_player_input = false
			right.allow_last_chance = true
			right.network_puppet = local_side != 1
			right.net_has_target = false
		if ball:
			ball.network_puppet = true
			ball.freeze = true
			ball.net_has_target = false


func _physics_process(delta: float) -> void:
	if not active or left == null or right == null:
		return
	if not _multiplayer_live():
		return

	if not _peers_ready:
		_ready_accum += delta
		if _ready_accum >= READY_DELAY_SEC and _has_remote_peer():
			_peers_ready = true
			_maybe_send_hello()
		_drive_local_only()
		return

	_maybe_send_hello()
	if is_host():
		_host_tick(delta)
	else:
		_client_tick(delta)


func _drive_local_only() -> void:
	var axis := Input.get_axis("p1_left", "p1_right")
	var jump := Input.is_action_pressed("p1_jump")
	var blast := Input.is_action_just_pressed("p1_self_destruct")
	_apply_input_to_side(local_side, axis, jump, blast)


func _host_tick(delta: float) -> void:
	var local_axis := Input.get_axis("p1_left", "p1_right")
	var local_jump := Input.is_action_pressed("p1_jump")
	var local_blast := Input.is_action_just_pressed("p1_self_destruct")

	_apply_input_to_side(local_side, local_axis, local_jump, local_blast)
	_apply_input_to_side(1 - local_side, _remote_axis, _remote_jump, _remote_blast)
	_remote_blast = false

	_sync_accum += delta
	if _sync_accum >= 1.0 / SYNC_HZ:
		_sync_accum = 0.0
		_broadcast_state(false)


func _client_tick(delta: float) -> void:
	var axis := Input.get_axis("p1_left", "p1_right")
	var jump := Input.is_action_pressed("p1_jump")
	var blast := Input.is_action_just_pressed("p1_self_destruct")
	_apply_input_to_side(local_side, axis, jump, blast)

	_apply_interpolated_world()
	_reconcile_local_from_latest()

	if not _has_peer(1):
		return
	_sync_accum += delta
	var changed := (
		blast
		or absf(axis - _last_sent_axis) > 0.015
		or jump != _last_sent_jump
		or _sync_accum >= 1.0 / SYNC_HZ
	)
	if not changed:
		return
	_sync_accum = 0.0
	_last_sent_axis = axis
	_last_sent_jump = jump
	rpc_id(1, "_rpc_input", axis, jump, blast)


func _apply_input_to_side(side: int, axis: float, jump: bool, blast: bool) -> void:
	var blob := left if side == 0 else right
	if blob == null or blob.network_puppet:
		return
	blob.external_axis = axis
	blob.external_jump = jump
	if blast:
		blob.try_last_chance()


func _broadcast_state(force_hud: bool) -> void:
	if not _has_remote_peer():
		return
	_server_tick += 1
	var packed := {
		"tick": _server_tick,
		"lp": left.global_position if left else Vector3.ZERO,
		"lv": left.velocity if left else Vector3.ZERO,
		"ld": left.is_destroyed() if left else false,
		"rp": right.global_position if right else Vector3.ZERO,
		"rv": right.velocity if right else Vector3.ZERO,
		"rd": right.is_destroyed() if right else false,
		"bp": ball.global_position if ball else Vector3.ZERO,
		"bv": ball.linear_velocity if ball else Vector3.ZERO,
		"ba": ball.angular_velocity if ball else Vector3.ZERO,
		"bf": ball.freeze if ball else true,
		"alarm": ball.is_alarm() if ball else false,
		"sl": _score_left,
		"sr": _score_right,
		"msg": _last_message,
		"tm": _last_timer,
		"hud": force_hud,
		"ln": left_display_name,
		"rn": right_display_name,
	}
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "_rpc_world_state", packed)


func _push_snapshot(packed: Dictionary) -> void:
	var snap := packed.duplicate()
	snap["_recv"] = Time.get_ticks_msec() * 0.001
	_latest_snap = snap
	_snapshots.append(snap)
	while _snapshots.size() > SNAPSHOT_LIMIT:
		_snapshots.remove_at(0)


func _sample_interpolated() -> Dictionary:
	if _snapshots.is_empty():
		return {}
	if _snapshots.size() == 1:
		return _snapshots[0]

	var render_t := Time.get_ticks_msec() * 0.001 - INTERP_DELAY_SEC
	# Not enough history yet — show newest.
	if render_t <= float(_snapshots[0].get("_recv", 0.0)):
		return _snapshots[0]
	if render_t >= float(_snapshots[_snapshots.size() - 1].get("_recv", 0.0)):
		return _snapshots[_snapshots.size() - 1]

	for i in range(1, _snapshots.size()):
		var a: Dictionary = _snapshots[i - 1]
		var b: Dictionary = _snapshots[i]
		var ta := float(a.get("_recv", 0.0))
		var tb := float(b.get("_recv", 0.0))
		if render_t > tb:
			continue
		var span := maxf(tb - ta, 0.0001)
		var alpha := clampf((render_t - ta) / span, 0.0, 1.0)
		return _lerp_snapshot(a, b, alpha)
	return _snapshots[_snapshots.size() - 1]


func _lerp_snapshot(a: Dictionary, b: Dictionary, alpha: float) -> Dictionary:
	return {
		"lp": _as_vec3(a.get("lp")).lerp(_as_vec3(b.get("lp")), alpha),
		"lv": _as_vec3(a.get("lv")).lerp(_as_vec3(b.get("lv")), alpha),
		"ld": bool(b.get("ld", false)) if alpha > 0.5 else bool(a.get("ld", false)),
		"rp": _as_vec3(a.get("rp")).lerp(_as_vec3(b.get("rp")), alpha),
		"rv": _as_vec3(a.get("rv")).lerp(_as_vec3(b.get("rv")), alpha),
		"rd": bool(b.get("rd", false)) if alpha > 0.5 else bool(a.get("rd", false)),
		"bp": _as_vec3(a.get("bp")).lerp(_as_vec3(b.get("bp")), alpha),
		"bv": _as_vec3(a.get("bv")).lerp(_as_vec3(b.get("bv")), alpha),
		"ba": _as_vec3(a.get("ba")).lerp(_as_vec3(b.get("ba")), alpha),
		"bf": bool(b.get("bf", true)) if alpha > 0.5 else bool(a.get("bf", true)),
		"alarm": bool(b.get("alarm", false)) if alpha > 0.5 else bool(a.get("alarm", false)),
	}


func _as_vec3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	return Vector3.ZERO


func _apply_interpolated_world() -> void:
	var snap := _sample_interpolated()
	if snap.is_empty():
		return

	# Life state from latest authority (fixes forever-invisible after boom).
	if not _latest_snap.is_empty():
		_apply_life_state(left, bool(_latest_snap.get("ld", false)), local_side == 0)
		_apply_life_state(right, bool(_latest_snap.get("rd", false)), local_side == 1)

	if local_side == 0:
		# Remote = right
		if right:
			right.apply_interp_pose(snap.get("rp", right.global_position), snap.get("rv", Vector3.ZERO))
	else:
		if left:
			left.apply_interp_pose(snap.get("lp", left.global_position), snap.get("lv", Vector3.ZERO))

	if ball:
		var frozen := bool(snap.get("bf", true))
		# During serve hold, snap tightly from latest to avoid floaty ball.
		if frozen and not _latest_snap.is_empty():
			ball.apply_interp_pose(
				_latest_snap.get("bp", ball.global_position),
				Vector3.ZERO,
				true,
				bool(_latest_snap.get("alarm", false))
			)
		else:
			ball.apply_interp_pose(
				snap.get("bp", ball.global_position),
				snap.get("bv", Vector3.ZERO),
				frozen,
				bool(snap.get("alarm", false))
			)


func _reconcile_local_from_latest() -> void:
	if _latest_snap.is_empty():
		return
	var blob := left if local_side == 0 else right
	if blob == null or blob.network_puppet:
		return
	var pos_key := "lp" if local_side == 0 else "rp"
	var vel_key := "lv" if local_side == 0 else "rv"
	blob.soft_reconcile(
		_latest_snap.get(pos_key, blob.global_position),
		_latest_snap.get(vel_key, Vector3.ZERO)
	)


func _apply_life_state(blob: BlobPlayer, destroyed: bool, is_local: bool) -> void:
	if blob == null:
		return
	if destroyed:
		if is_local:
			_local_auth_saw_dead = true
		if not blob.is_destroyed():
			blob.apply_network_state(blob.global_position, blob.velocity, true)
		return
	# Authority says alive.
	if not blob.is_destroyed():
		if is_local:
			_local_auth_saw_dead = false
		return
	# Local predicted boom before host ack — keep dead until authority also saw dead, then revived.
	if is_local and not _local_auth_saw_dead:
		return
	blob.apply_network_state(blob.global_position, blob.velocity, false)
	if is_local:
		_local_auth_saw_dead = false


func _maybe_send_hello() -> void:
	if _hello_sent or is_host() or not _has_peer(1):
		return
	_hello_sent = true
	rpc_id(1, "_rpc_hello", local_display_name)


func _multiplayer_live() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _has_remote_peer() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0


func _has_peer(peer_id: int) -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	if peer_id == multiplayer.get_unique_id():
		return true
	return multiplayer.get_peers().has(peer_id)


func _on_peer_connected(_peer_id: int) -> void:
	_ready_accum = maxf(_ready_accum, READY_DELAY_SEC * 0.5)
	_hello_sent = false


func _on_peer_disconnected(_peer_id: int) -> void:
	if not _has_remote_peer():
		_peers_ready = false
		_ready_accum = 0.0
		_snapshots.clear()
		_latest_snap.clear()


@rpc("any_peer", "reliable", "call_remote")
func _rpc_hello(display_name: String) -> void:
	if not is_host() or not active:
		return
	var clean := display_name.strip_edges()
	if clean.is_empty():
		clean = "Player"
	right_display_name = clean
	ev_names_changed.emit(left_display_name, right_display_name)
	_broadcast_state(true)


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _rpc_input(axis: float, jump: bool, blast: bool) -> void:
	if not is_host() or not active:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0 or sender == multiplayer.get_unique_id():
		return
	if not _has_peer(sender):
		return
	_remote_axis = clampf(axis, -1.0, 1.0)
	_remote_jump = jump
	if blast:
		_remote_blast = true


@rpc("authority", "unreliable_ordered", "call_remote")
func _rpc_world_state(packed: Dictionary) -> void:
	if is_host() or not active:
		return

	var ln := str(packed.get("ln", left_display_name))
	var rn := str(packed.get("rn", right_display_name))
	if ln != left_display_name or rn != right_display_name:
		left_display_name = ln
		right_display_name = rn
		ev_names_changed.emit(ln, rn)

	_push_snapshot(packed)

	var sl := int(packed.get("sl", _score_left))
	var sr := int(packed.get("sr", _score_right))
	var msg := str(packed.get("msg", ""))
	var tm := int(packed.get("tm", _last_timer))
	var hud := bool(packed.get("hud", false))
	if hud or sl != _score_left or sr != _score_right or msg != _last_message or tm != _last_timer:
		_score_left = sl
		_score_right = sr
		_last_message = msg
		_last_timer = tm
		ev_hud.emit(sl, sr, msg, tm)


@rpc("authority", "reliable", "call_remote")
func _rpc_match_over(payload: Dictionary) -> void:
	if is_host() or not active:
		return
	ev_remote_match_over.emit(payload)
