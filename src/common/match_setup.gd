class_name MatchSetup
extends Resource

## Everything that defines one match: teams and slots, presets, seed.
## One format for every mode (vs AI, local 2P, online) and for tests.

@export var teams: Array[TeamSetup] = []
@export var physics: PhysicsPreset
@export var arena: ArenaPreset
@export var rules: RuleSet
@export var match_seed: int = 1


func slots() -> Array[SlotSetup]:
	var out: Array[SlotSetup] = []
	for team in teams:
		out.append_array(team.slots)
	return out


func slot_team(slot_index: int) -> int:
	var index := 0
	for team_index in teams.size():
		for _slot in teams[team_index].slots:
			if index == slot_index:
				return team_index
			index += 1
	return -1


func has_remote_peers(local_peer_id: int) -> bool:
	for slot in slots():
		if slot.peer_id != 0 and slot.peer_id != local_peer_id:
			return true
	return false


func local_human_count() -> int:
	var count := 0
	for slot in slots():
		if not slot.is_bot and not slot.local_input.is_empty():
			count += 1
	return count


## Plain data for the deterministic sim (no Resources inside).
func to_sim_config() -> Dictionary:
	var team_sizes: Array = []
	for team in teams:
		team_sizes.append(team.slots.size())
	return {
		"team_sizes": team_sizes,
		"physics": physics.to_dict(),
		"arena": arena.to_dict(),
		"rules": rules.to_dict(),
		"seed": match_seed,
	}
