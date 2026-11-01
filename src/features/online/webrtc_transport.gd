class_name WebRTCTransport
extends PeerTransport

## Direct UDP link to the other player of a room (WebRTC data channels, webrtc-native extension
## on PC / Android). Two pre-negotiated channels: "fast" (unordered, no retransmits) for inputs
## and pings — rollback already resends unacknowledged input — and "sure" (reliable) for match
## start / stop. Offer / answer / ICE candidates travel through `ev_signal_out` → the room's
## signaling (Nakama) → `on_signal_in` on the other side. STUN finds a path through home routers.

## {"sdp": [type, sdp]} or {"ice": [media, index, name]} for the other peer.
signal ev_signal_out(message: Dictionary)
signal ev_ready
signal ev_closed

const CHANNEL_FAST := 1
const CHANNEL_SURE := 2

var remote_peer_id: int = 0

var _conn: WebRTCPeerConnection
var _fast: WebRTCDataChannel
var _sure: WebRTCDataChannel
var _ready: bool = false
var _remote_description_set: bool = false
var _pending_ice: Array[Dictionary] = []


static func is_supported() -> bool:
	return ClassDB.class_exists(&"WebRTCPeerConnection")


func open(p_remote_peer_id: int, stun_urls: PackedStringArray) -> bool:
	remote_peer_id = p_remote_peer_id
	_conn = WebRTCPeerConnection.new()
	var config := {}
	if not stun_urls.is_empty():
		config["iceServers"] = [{"urls": Array(stun_urls)}]
	if _conn.initialize(config) != OK:
		_conn = null
		return false
	_conn.session_description_created.connect(_on_description_created)
	_conn.ice_candidate_created.connect(_on_ice_created)
	_fast = _conn.create_data_channel("fast", {"id": CHANNEL_FAST, "negotiated": true, "ordered": false, "maxRetransmits": 0})
	_sure = _conn.create_data_channel("sure", {"id": CHANNEL_SURE, "negotiated": true})
	return _fast != null and _sure != null


## Only one side (the room host) makes the offer; the other answers automatically.
func make_offer() -> void:
	if _conn != null:
		_conn.create_offer()


func on_signal_in(message: Dictionary) -> void:
	if _conn == null:
		return
	if message.has("sdp"):
		var description: Array = message["sdp"]
		_conn.set_remote_description(str(description[0]), str(description[1]))
		_remote_description_set = true
		for candidate in _pending_ice:
			_add_ice(candidate)
		_pending_ice.clear()
	elif message.has("ice"):
		if _remote_description_set:
			_add_ice(message)
		else:
			_pending_ice.append(message)


func close() -> void:
	if _conn != null:
		_conn.close()
	_conn = null
	_fast = null
	_sure = null
	if _ready:
		_ready = false
		ev_closed.emit()


func connection_state() -> String:
	if _conn == null:
		return "closed"
	return String(ClassDB.class_get_enum_constants(&"WebRTCPeerConnection", &"ConnectionState")[_conn.get_connection_state()]).to_lower()


# --- PeerTransport ----------------------------------------------------------------------

func is_ready(peer_id: int) -> bool:
	return _ready and peer_id == remote_peer_id


func send(peer_id: int, reliable: bool, data: PackedByteArray) -> bool:
	if not is_ready(peer_id):
		return false
	return (_sure if reliable else _fast).put_packet(data) == OK


func receive() -> Array:
	var out: Array = []
	if _conn == null:
		return out
	for channel in [_sure, _fast]:
		while channel.get_available_packet_count() > 0:
			out.append([remote_peer_id, channel.get_packet()])
	return out


func poll() -> void:
	if _conn == null:
		return
	_conn.poll()
	var open := _fast.get_ready_state() == WebRTCDataChannel.STATE_OPEN \
		and _sure.get_ready_state() == WebRTCDataChannel.STATE_OPEN
	if open and not _ready:
		_ready = true
		ev_ready.emit()
	elif _ready and not open:
		_ready = false
		ev_closed.emit()


func _add_ice(message: Dictionary) -> void:
	var candidate: Array = message["ice"]
	_conn.add_ice_candidate(str(candidate[0]), int(candidate[1]), str(candidate[2]))


func _on_description_created(type: String, sdp: String) -> void:
	_conn.set_local_description(type, sdp)
	ev_signal_out.emit({"sdp": [type, sdp]})


func _on_ice_created(media: String, index: int, name: String) -> void:
	ev_signal_out.emit({"ice": [media, index, name]})
