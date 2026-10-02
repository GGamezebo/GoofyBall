class_name OnlineRollback
extends Node

## Rollback netcode glue (godot-rollback-netcode `SyncManager` over the Nakama relay).
##
## The simulation is injected as Callables, so this feature does not depend on gameplay code:
##   sample_input() -> Dictionary        local player's input for this tick
##   step(inputs: Array) -> void         advance the sim one tick with [left, right] inputs
##   save() -> Dictionary / load(state)  snapshot/restore for rollback
##
## Flow: both peers build the scene → `setup()` → exchange `_rpc_ready` (resent until the
## match starts) → host calls `SyncManager.start()` → every tick SyncManager rolls back and
## re-simulates when a late remote input contradicts the prediction.

signal ev_started
signal ev_status(text: String)
signal ev_names_changed(left_name: String, right_name: String)
## The match cannot continue (peer left, desync, sync lost for good).
signal ev_aborted(reason: String)

const READY_RESEND_SEC := 0.5

var left_name: String = "BLUE"
var right_name: String = "RED"

var _step: Callable
var _save: Callable
var _load: Callable
var _local_side: int = 0
var _local_name: String = "YOU"
var _remote_id: int = 0
var _remote_ready: bool = false
var _active: bool = false
var _started: bool = false
var _aborted: bool = false
var _inputs: Array[RollbackInput] = []
var _resend: Timer


func setup(
	p_sample: Callable,
	p_step: Callable,
	p_save: Callable,
	p_load: Callable,
	p_local_side: int,
	p_local_name: String
) -> bool:
	_local_side = p_local_side
	_local_name = p_local_name
	if _local_side == 0:
		left_name = _local_name
	else:
		right_name = _local_name

	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		ev_aborted.emit("No opponent connection")
		return false
	_remote_id = multiplayer.get_peers()[0]
	# Host (peer 1) plays the left side, the guest the right side.
	var guest_id := _remote_id if multiplayer.is_server() else multiplayer.get_unique_id()
	bind_sim(p_sample, p_step, p_save, p_load, 1, guest_id)

	SyncManager.reset_network_adaptor()
	SyncManager.clear_peers()
	SyncManager.add_peer(_remote_id)
	SyncManager.sync_started.connect(_on_sync_started)
	SyncManager.sync_stopped.connect(_on_sync_stopped)
	SyncManager.sync_lost.connect(_on_sync_lost)
	SyncManager.sync_regained.connect(_on_sync_regained)
	SyncManager.sync_error.connect(_on_sync_error)
	SyncManager.remote_state_mismatch.connect(_on_state_mismatch)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_resend = Timer.new()
	_resend.wait_time = READY_RESEND_SEC
	_resend.one_shot = false
	_resend.timeout.connect(_announce_ready)
	add_child(_resend)
	_active = true
	_resend.start()
	_announce_ready()
	ev_names_changed.emit(left_name, right_name)
	ev_status.emit("Waiting for opponent…")
	return true


## Registers the sim callbacks and one input node per side. `*_authority` = peer id that
## supplies that side's real input. Split out from `setup()` so tests can drive it offline.
func bind_sim(
	p_sample: Callable,
	p_step: Callable,
	p_save: Callable,
	p_load: Callable,
	left_authority: int,
	right_authority: int
) -> void:
	_step = p_step
	_save = p_save
	_load = p_load
	for side in 2:
		var node := RollbackInput.new()
		node.name = "InputLeft" if side == 0 else "InputRight"
		node.side = side
		node.sample = p_sample if (side == _local_side) else Callable()
		node.set_multiplayer_authority(left_authority if side == 0 else right_authority)
		node.add_to_group("network_sync")
		add_child(node)
		_inputs.append(node)
	add_to_group("network_sync")


func shutdown() -> void:
	if not _active:
		return
	_active = false
	if _resend:
		_resend.stop()
	_disconnect(SyncManager.sync_started, _on_sync_started)
	_disconnect(SyncManager.sync_stopped, _on_sync_stopped)
	_disconnect(SyncManager.sync_lost, _on_sync_lost)
	_disconnect(SyncManager.sync_regained, _on_sync_regained)
	_disconnect(SyncManager.sync_error, _on_sync_error)
	_disconnect(SyncManager.remote_state_mismatch, _on_state_mismatch)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	remove_from_group("network_sync")
	for node in _inputs:
		node.remove_from_group("network_sync")
	SyncManager.stop()
	SyncManager.clear_peers()


## True while the current tick's inputs are all confirmed (safe to act on irreversible outcomes).
func is_tick_confirmed() -> bool:
	return not SyncManager.is_in_rollback() and SyncManager.is_current_tick_input_complete()


# --- SyncManager callbacks (called on every peer, in lockstep) -------------------------

func _network_postprocess(_input: Dictionary) -> void:
	var left: Dictionary = _inputs[0].latest if not _inputs[0].latest.is_empty() else VolleySim.neutral_input()
	var right: Dictionary = _inputs[1].latest if not _inputs[1].latest.is_empty() else VolleySim.neutral_input()
	_step.call([left, right])


func _save_state() -> Dictionary:
	return _save.call()


func _load_state(state: Dictionary) -> void:
	_load.call(state)


# --- handshake ------------------------------------------------------------------------

func _announce_ready() -> void:
	if not _active or _started:
		return
	_rpc_ready.rpc_id(_remote_id, _local_name, _local_side)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ready(remote_name: String, remote_side: int) -> void:
	if not _active:
		return
	if multiplayer.get_remote_sender_id() != _remote_id:
		return
	_remote_ready = true
	if remote_side == 0:
		left_name = remote_name
	else:
		right_name = remote_name
	ev_names_changed.emit(left_name, right_name)
	if multiplayer.is_server() and not _started:
		# Both sides have built the scene: start the shared tick clock.
		_started = true
		SyncManager.start()
	else:
		# Guest: make sure the host learns we are ready even if its first ping was early.
		_announce_ready()


func _on_sync_started() -> void:
	_started = true
	if _resend:
		_resend.stop()
	ev_status.emit("")
	ev_started.emit()


func _on_sync_stopped() -> void:
	if _active and not _aborted:
		ev_status.emit("")


func _on_sync_lost() -> void:
	ev_status.emit("Connection unstable…")


func _on_sync_regained() -> void:
	ev_status.emit("")


func _on_sync_error(msg: String) -> void:
	_abort("Sync lost: %s" % msg)


func _on_state_mismatch(tick: int, _peer_id: int, local_hash: int, remote_hash: int) -> void:
	push_warning("rollback: state mismatch at tick %d (local %d, remote %d)" % [tick, local_hash, remote_hash])


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id == _remote_id:
		_abort("Opponent disconnected")


func _abort(reason: String) -> void:
	if _aborted or not _active:
		return
	_aborted = true
	ev_status.emit(reason)
	ev_aborted.emit(reason)


static func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
