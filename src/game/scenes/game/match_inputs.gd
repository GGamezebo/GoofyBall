class_name MatchInputs
extends RefCounted

## Per-slot input sources for this machine, picked from MatchSetup data:
## bot → AiOpponent, slot of another peer → remote (the session fills it), else → InputMap
## actions `<prefix>_move_left/right`, `<prefix>_jump`, `<prefix>_action` (touch presses p1_*).

enum Kind { LOCAL, BOT, REMOTE }

var _sim: VolleySim
var _kinds: Array[int] = []
var _prefixes: Array = []
var _bots: Dictionary = {}


func _init(match_setup: MatchSetup, my_peer_id: int, sim: VolleySim) -> void:
	_sim = sim
	var slots := match_setup.slots()
	# A single human on this machine may use either key set (WASD or arrows) and the touch pad.
	var solo := match_setup.local_human_count() <= 1
	for index in slots.size():
		var slot := slots[index]
		if slot.is_bot:
			_kinds.append(Kind.BOT)
			_prefixes.append([])
			_bots[index] = AiOpponent.new(index)
		elif slot.peer_id != 0 and slot.peer_id != my_peer_id:
			_kinds.append(Kind.REMOTE)
			_prefixes.append([])
		else:
			_kinds.append(Kind.LOCAL)
			var prefix := String(slot.local_input) if not slot.local_input.is_empty() else "p1"
			_prefixes.append(["p1", "p2"] if solo else [prefix])


func slot_count() -> int:
	return _kinds.size()


## Slots driven by a human on this machine.
func local_slots() -> Array[int]:
	var out: Array[int] = []
	for index in _kinds.size():
		if _kinds[index] == Kind.LOCAL:
			out.append(index)
	return out


func sample(slot: int) -> Dictionary:
	match _kinds[slot]:
		Kind.BOT:
			return (_bots[slot] as AiOpponent).decide(_sim.state, _sim.cfg["physics"], _sim.cfg["arena"])
		Kind.LOCAL:
			return read_actions(_prefixes[slot])
	return VolleySim.neutral_input()


static func read_actions(prefixes: Array) -> Dictionary:
	var axis := 0.0
	var jump := false
	var action := false
	for prefix in prefixes:
		axis += Input.get_axis(prefix + "_move_left", prefix + "_move_right")
		jump = jump or Input.is_action_pressed(prefix + "_jump")
		action = action or Input.is_action_pressed(prefix + "_action")
	return {"x": roundi(clampf(axis, -1.0, 1.0) * 100.0), "j": 1 if jump else 0, "a": 1 if action else 0}
