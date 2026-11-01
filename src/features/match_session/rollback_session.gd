class_name RollbackSession
extends MatchSession

## Online play: godot-rollback-netcode `SyncManager` over whatever `multiplayer.multiplayer_peer`
## is set (Nakama relay in the game, ENet in e2e tests). Only inputs travel; every peer runs the
## same sim, predicts missing remote input and rolls back + re-simulates when it was wrong.
## Flow: setup() → peers exchange `_rpc_ready` (resent until the match starts) → the host
## (peer 1) calls `SyncManager.start()` → ticks run in lockstep.

const READY_RESEND_SEC := 0.5
const STATS_PERIOD_MS := 1000
## INFO health line period: enough to read a stall from a phone log, not per-frame spam.
const HEALTH_LOG_PERIOD_MS := 5000

@export var tuning: NetTuning
## Network emulation for debug builds; null or inactive = real network only.
@export var lag_profile: LagProfile
## Direct P2P link to the opponent (set before setup); null = relay only.
var transport: PeerTransport

var stats := NetStats.new()

var _log: LogChannel
var _inputs: Array[RollbackInput] = []
var _remote_peers: Array[int] = []
var _ready_peers: Dictionary = {}
var _adaptor: LagNetworkAdaptor
## Kept from setup(): `multiplayer` is null once the node leaves the tree (app quit).
var _multiplayer: MultiplayerAPI
var _active: bool = false
var _started: bool = false
var _finished: bool = false
var _start_requested: bool = false
var _resend_left: float = 0.0
var _handshake_left: float = 0.0
var _last_stats_ms: int = 0
var _last_health_ms: int = 0
## Between sync_lost and sync_regained (see `_on_sync_lost` for the deadlock workaround).
var _sync_lost: bool = false
var _lost_since_ms: int = 0
var _notice_shown: bool = false


## `slot_peers[i]` = peer id that owns slot i. Call after `bind_sim()`.
func setup(slot_peers: Array[int], log_channel: LogChannel) -> bool:
	_log = log_channel if log_channel != null else LogChannel.new("net")
	if not multiplayer.has_multiplayer_peer():
		_abort("no_connection")
		return false
	var my_id := multiplayer.get_unique_id()
	for peer_id in slot_peers:
		if peer_id != my_id and not _remote_peers.has(peer_id):
			_remote_peers.append(peer_id)
	var connected := multiplayer.get_peers()
	for peer_id in _remote_peers:
		if not connected.has(peer_id):
			_abort("opponent_missing")
			return false

	bind_inputs(slot_peers, my_id)

	var lag := lag_profile if lag_profile != null and OS.is_debug_build() else null
	_adaptor = LagNetworkAdaptor.new()
	_adaptor.profile = lag
	if transport != null:
		transport.receive() # drop late packets of the previous match
	_adaptor.transport = transport
	SyncManager.set_network_adaptor(_adaptor)
	if tuning != null:
		tuning.apply_to(SyncManager)
	SyncManager.clear_peers()
	for peer_id in _remote_peers:
		SyncManager.add_peer(peer_id)

	SyncManager.sync_started.connect(_on_sync_started)
	SyncManager.sync_stopped.connect(_on_sync_stopped)
	SyncManager.sync_lost.connect(_on_sync_lost)
	SyncManager.sync_regained.connect(_on_sync_regained)
	SyncManager.sync_error.connect(_on_sync_error)
	SyncManager.skip_ticks_flagged.connect(_on_skip_ticks)
	SyncManager.remote_state_mismatch.connect(_on_state_mismatch)
	SyncManager.prediction_missed.connect(_on_prediction_missed)
	_multiplayer = multiplayer
	_multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_active = true
	_handshake_left = tuning.handshake_timeout_sec if tuning != null else 15.0
	_log.info("session_setup", {
		"me": my_id, "host": multiplayer.is_server(), "remote": _remote_peers,
		"input_delay": SyncManager.input_delay, "buffer": SyncManager.max_buffer_size,
		"lag": lag.title if lag != null and lag.is_active() else "none",
		"link": _link_name(),
	})
	ev_status.emit("Ждём соперника…")
	_announce_ready()
	return true


## Creates one input node per slot; `authority` = peer that supplies the real input.
## Split from `setup()` so tests can drive SyncManager offline (mechanized mode).
func bind_inputs(slot_peers: Array[int], my_id: int) -> void:
	for slot in slot_peers.size():
		var node := RollbackInput.new()
		node.name = "Input%d" % slot
		var peer_id: int = slot_peers[slot]
		node.set_multiplayer_authority(peer_id)
		if peer_id == my_id:
			node.sample = _sample.bind(slot)
		node.add_to_group("network_sync")
		add_child(node)
		_inputs.append(node)
	add_to_group("network_sync")
	if not SyncManager.state_loaded.is_connected(_on_state_loaded):
		SyncManager.state_loaded.connect(_on_state_loaded)


func shutdown() -> void:
	if not _active:
		return
	_active = false
	_log.info("match_summary", stats.snapshot())
	for sig_cb in [
		[SyncManager.sync_started, _on_sync_started], [SyncManager.sync_stopped, _on_sync_stopped],
		[SyncManager.sync_lost, _on_sync_lost], [SyncManager.sync_regained, _on_sync_regained],
		[SyncManager.sync_error, _on_sync_error], [SyncManager.state_loaded, _on_state_loaded],
		[SyncManager.skip_ticks_flagged, _on_skip_ticks],
		[SyncManager.remote_state_mismatch, _on_state_mismatch],
		[SyncManager.prediction_missed, _on_prediction_missed],
	]:
		var sig: Signal = sig_cb[0]
		if sig.is_connected(sig_cb[1]):
			sig.disconnect(sig_cb[1])
	if _multiplayer != null and _multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		_multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	remove_from_group("network_sync")
	for node in _inputs:
		node.remove_from_group("network_sync")
	_set_lost_recovery(false)
	if SyncManager.started:
		SyncManager.stop()
	SyncManager.clear_peers()


func leave() -> void:
	if _active and _started and not _finished and is_inside_tree():
		_log.info("left_match", {"tick": SyncManager.current_tick})
		for peer_id in _remote_peers:
			if multiplayer.get_peers().has(peer_id):
				_rpc_left.rpc_id(peer_id)
	shutdown()


func is_online() -> bool:
	return true


func is_tick_confirmed() -> bool:
	return not SyncManager.is_in_rollback() and SyncManager.is_current_tick_input_complete()


func get_stats() -> Dictionary:
	var out := stats.snapshot()
	out["input_delay"] = SyncManager.input_delay
	out["buffer"] = SyncManager.max_buffer_size
	out["link"] = _link_name()
	out["lag"] = lag_profile.title if lag_profile != null and lag_profile.is_active() else ""
	return out


## Switch network emulation during a match (debug overlay).
func set_lag_profile(profile: LagProfile) -> void:
	lag_profile = profile
	if _adaptor != null and OS.is_debug_build():
		_adaptor.profile = profile
		_log.info("lag_profile", {"title": profile.title if profile != null else "none"})


func _process(delta: float) -> void:
	if not _active:
		return
	if not _started:
		_handshake_left -= delta
		if _handshake_left <= 0.0:
			_abort("handshake_timeout")
			return
		_resend_left -= delta
		if _resend_left <= 0.0:
			_announce_ready()
		return
	var now := Time.get_ticks_msec()
	stats.update(now)
	if _sync_lost and not _notice_shown and now - _lost_since_ms >= _notice_delay_ms():
		_notice_shown = true
		ev_status.emit("Связь нестабильна…")
	if now - _last_stats_ms >= STATS_PERIOD_MS:
		_last_stats_ms = now
		_sample_ping()
	if now - _last_health_ms >= HEALTH_LOG_PERIOD_MS:
		_last_health_ms = now
		_log.info("net_health", _health())


func _sample_ping() -> void:
	for peer_id in _remote_peers:
		var peer = SyncManager.peers.get(peer_id)
		if peer != null:
			stats.on_ping(peer.rtt, peer.local_lag, peer.remote_lag)
			_log.debug("net_tick", {"tick": SyncManager.current_tick, "ping": peer.rtt,
				"rollbacks_s": stats.snapshot()["rollbacks_per_sec"], "max_rb": stats.max_rollback})


## One line with everything needed to tell a slow device from a slow network.
func _health() -> Dictionary:
	var snap := stats.snapshot()
	return {
		"tick": SyncManager.current_tick, "link": _link_name(), "ping": snap["ping_ms"], "ping_max": snap["ping_max"],
		"local_lag": snap["local_lag"], "remote_lag": snap["remote_lag"], "buffer": SyncManager.max_buffer_size,
		"rollbacks_s": snap["rollbacks_per_sec"], "max_rollback": snap["max_rollback"],
		"skipped": snap["skipped_ticks"], "sync_lost": snap["sync_lost"],
		"fps": Engine.get_frames_per_second(),
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	}


# --- SyncManager callbacks (every peer, in lockstep) ------------------------------------

func _network_postprocess(_input: Dictionary) -> void:
	var inputs: Array = []
	for node in _inputs:
		inputs.append(node.latest if not node.latest.is_empty() else _neutral)
	var tick: int = _step.call(inputs)
	ev_ticked.emit(tick)


func _save_state() -> Dictionary:
	return _save.call()


func _load_state(state: Dictionary) -> void:
	_load.call(state)


# --- handshake ------------------------------------------------------------------------

func _announce_ready() -> void:
	_resend_left = READY_RESEND_SEC
	if not _active or _started:
		return
	for peer_id in _remote_peers:
		_rpc_ready.rpc_id(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ready() -> void:
	if not _active or _started:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _remote_peers.has(sender):
		return
	if not _ready_peers.has(sender):
		_ready_peers[sender] = true
		_log.info("peer_ready", {"peer": sender})
	if multiplayer.is_server():
		if _ready_peers.size() == _remote_peers.size() and not _start_requested:
			_start_requested = true
			_log.info("sync_start_requested")
			SyncManager.start()
	else:
		# Make sure the host hears us even if its first message came before our scene was up.
		_announce_ready()


## The opponent quit the match on purpose: end it now instead of waiting for input that will
## never come (and for the server to notice the disconnect).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_left() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _active or not _remote_peers.has(sender):
		return
	_log.warn("opponent_left_match", {"peer": sender, "tick": SyncManager.current_tick})
	_abort("opponent_left")


## "p2p" when traffic to the opponent goes over the direct link, "relay" otherwise.
func _link_name() -> String:
	if _adaptor == null or _remote_peers.is_empty():
		return "relay"
	return _adaptor.link_name(_remote_peers[0])


func _on_sync_started() -> void:
	_started = true
	_log.info("sync_started", {"input_delay": SyncManager.input_delay, "link": _link_name()})
	ev_status.emit("")
	ev_started.emit()


func _on_sync_stopped() -> void:
	if not _active or _finished:
		return
	_finished = true
	_log.info("sync_stopped", {"tick": SyncManager.current_tick})
	ev_stopped.emit()


func _on_sync_lost() -> void:
	stats.sync_lost += 1
	_sample_ping()
	_log.warn("sync_lost", _health())
	_lost_since_ms = Time.get_ticks_msec()
	_notice_shown = false
	_set_lost_recovery(true)


func _on_sync_regained() -> void:
	_set_lost_recovery(false)
	_log.info("sync_regained", {"tick": SyncManager.current_tick, "lost_ms": Time.get_ticks_msec() - _lost_since_ms})
	if _notice_shown:
		_notice_shown = false
		ev_status.emit("")


func _notice_delay_ms() -> int:
	return roundi((tuning.unstable_notice_sec if tuning != null else 0.4) * 1000.0)


## Workarounds for two deadlocks in godot-rollback-netcode while sync is lost:
## 1. SyncManager does not tick, and a stored state only becomes "complete" (hashable,
##    retirable) when it is saved again — never, if the late inputs matched our prediction.
##    Re-simulating the last tick each frame re-saves it and lets the buffers drain.
## 2. Acks ("next tick I need") only ride on input messages. A stuck peer has no new input to
##    send, so the other side keeps an old idea of what it needs and only sends the oldest and
##    newest few ticks — the middle never arrives. Resending the whole unacknowledged queue
##    each tick while lost fills that gap.
func _set_lost_recovery(enabled: bool) -> void:
	if enabled == _sync_lost:
		return
	_sync_lost = enabled
	SyncManager.debug_rollback_ticks = 1 if enabled else 0
	var normal := tuning if tuning != null else NetTuning.new()
	SyncManager.max_input_frames_per_message = normal.recovery_frames_per_message if enabled else normal.max_input_frames_per_message
	SyncManager.max_messages_at_once = normal.recovery_messages_at_once if enabled else normal.max_messages_at_once


func _on_sync_error(msg: String) -> void:
	_log.error("sync_error", {"msg": msg, "tick": SyncManager.current_tick})
	_abort("sync_error")


func _on_state_loaded(rollback_ticks: int) -> void:
	stats.on_rollback(rollback_ticks)
	ev_rolled_back.emit(rollback_ticks)


func _on_skip_ticks(count: int) -> void:
	stats.skipped_ticks += count
	_log.debug("skip_ticks", {"count": count, "tick": SyncManager.current_tick})


func _on_prediction_missed(_tick: int, _peer_id: int, _local_input: Dictionary, _remote_input: Dictionary) -> void:
	stats.prediction_misses += 1


func _on_state_mismatch(tick: int, peer_id: int, local_hash: int, remote_hash: int) -> void:
	stats.mismatches += 1
	_log.warn("desync", {"tick": tick, "peer": peer_id, "local_hash": local_hash, "remote_hash": remote_hash})


func _on_peer_disconnected(peer_id: int) -> void:
	if _remote_peers.has(peer_id):
		_log.warn("peer_disconnected", {"peer": peer_id, "tick": SyncManager.current_tick})
		_abort("opponent_left")


func _abort(reason: String) -> void:
	if _finished:
		return
	_finished = true
	if _log != null:
		_log.warn("session_abort", {"reason": reason})
	ev_aborted.emit(reason)
