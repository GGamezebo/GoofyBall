class_name PData
extends Resource

## Lightweight persistent progress for the prototype.

@export var matches_played: int = 0
@export var wins_two_player: int = 0
@export var wins_vs_ai: int = 0
@export var losses_vs_ai: int = 0
@export var wins_ranked: int = 0


func to_dict() -> Dictionary:
	return {
		"matches_played": matches_played,
		"wins_two_player": wins_two_player,
		"wins_vs_ai": wins_vs_ai,
		"losses_vs_ai": losses_vs_ai,
		"wins_ranked": wins_ranked,
	}


func apply_dict(data: Dictionary) -> void:
	matches_played = int(data.get("matches_played", 0))
	wins_two_player = int(data.get("wins_two_player", 0))
	wins_vs_ai = int(data.get("wins_vs_ai", 0))
	losses_vs_ai = int(data.get("losses_vs_ai", 0))
	wins_ranked = int(data.get("wins_ranked", 0))


func reset_to_defaults() -> void:
	apply_dict({})
