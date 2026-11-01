class_name LagNetworkAdaptor
extends "res://addons/godot-rollback-netcode/RPCNetworkAdaptor.gd"

## RPC network adaptor with optional network emulation (debug builds): delays every outgoing
## message by `delay ± jitter` (order kept, like TCP through the relay) and drops a share of
## input packets. Pings are delayed too, so the measured RTT includes the fake lag.
## Both peers must use this script (RPC methods are matched by node path and script).

enum Kind { PING, PING_BACK, REMOTE_START, INPUT }

var profile: LagProfile

var _sync_manager: Node
var _queue: Array[Dictionary] = []
var _last_due_ms: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func attach_network_adaptor(sync_manager) -> void:
	_sync_manager = sync_manager


## The match stopped: anything still waiting in the emulation queue is for a finished match.
func stop_network_adaptor(_sync_manager_arg) -> void:
	_queue.clear()


## A ping answer can arrive after the match stopped and SyncManager forgot the peer
## (it would index its peer list and crash): drop it.
@rpc("any_peer", "unreliable")
func _remote_ping_back(msg: Dictionary) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if _sync_manager != null and not _sync_manager.peers.has(peer_id):
		return
	received_ping_back.emit(peer_id, msg)


func send_ping(peer_id: int, msg: Dictionary) -> void:
	_enqueue({"kind": Kind.PING, "peer": peer_id, "msg": msg}, false)


func send_ping_back(peer_id: int, msg: Dictionary) -> void:
	_enqueue({"kind": Kind.PING_BACK, "peer": peer_id, "msg": msg}, false)


func send_remote_start(peer_id: int) -> void:
	_enqueue({"kind": Kind.REMOTE_START, "peer": peer_id}, false)


func send_input_tick(peer_id: int, msg: PackedByteArray) -> void:
	_enqueue({"kind": Kind.INPUT, "peer": peer_id, "msg": msg}, true)


## Sent when the match stops — often because this very peer just left the room, and an RPC
## to an unknown peer is an engine error. Never delayed: the match scene goes away right after.
func send_remote_stop(peer_id: int) -> void:
	if _is_connected(peer_id):
		super.send_remote_stop(peer_id)


func poll() -> void:
	_flush()


func _process(_delta: float) -> void:
	_flush()


func _enqueue(item: Dictionary, droppable: bool) -> void:
	if profile == null or not profile.is_active():
		_send_now(item)
		return
	if droppable and profile.drop_rate > 0.0 and _rng.randf() < profile.drop_rate:
		return
	var now := Time.get_ticks_msec()
	var due := profile.stall_release_ms(now) + profile.delay_ms
	if profile.jitter_ms > 0:
		due += _rng.randi_range(0, profile.jitter_ms)
	due = maxi(due, _last_due_ms)
	_last_due_ms = due
	item["due"] = due
	_queue.append(item)


func _flush() -> void:
	var now := Time.get_ticks_msec()
	while not _queue.is_empty() and int(_queue[0]["due"]) <= now:
		_send_now(_queue.pop_front())


func _send_now(item: Dictionary) -> void:
	var peer_id: int = item["peer"]
	if not _is_connected(peer_id):
		return
	match int(item["kind"]):
		Kind.PING:
			super.send_ping(peer_id, item["msg"])
		Kind.PING_BACK:
			super.send_ping_back(peer_id, item["msg"])
		Kind.REMOTE_START:
			super.send_remote_start(peer_id)
		Kind.INPUT:
			super.send_input_tick(peer_id, item["msg"])


func _is_connected(peer_id: int) -> bool:
	return multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(peer_id)
