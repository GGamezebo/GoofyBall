class_name PeerTransport
extends RefCounted

## Direct packet link to the other peer (P2P), used next to the multiplayer relay.
## The rollback network adaptor sends through it whenever `is_ready()` and falls back to RPCs
## over the relay otherwise. Implementation: WebRTCTransport (online feature).


func is_ready(_peer_id: int) -> bool:
	return false


## `reliable` = ordered and retransmitted; otherwise fire-and-forget (lost packets stay lost).
func send(_peer_id: int, _reliable: bool, _data: PackedByteArray) -> bool:
	return false


## Everything received since the last call: Array of [peer_id: int, data: PackedByteArray].
func receive() -> Array:
	return []


func poll() -> void:
	pass
