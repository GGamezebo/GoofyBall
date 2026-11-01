class_name RuleSet
extends Resource

## Match rules. `kind` picks the scoring rule inside the sim.

enum Kind { TWO_TEAM_POINTS }

@export var kind: Kind = Kind.TWO_TEAM_POINTS
@export var win_score: int = 7
@export var max_touches: int = 3
## Ball hangs above the server this long before it drops.
@export var serve_delay_ticks: int = 60
## Pause after a point before the next serve.
@export var point_pause_ticks: int = 66


func to_dict() -> Dictionary:
	return {
		"kind": kind, "win_score": win_score, "max_touches": max_touches,
		"serve_delay_ticks": serve_delay_ticks, "point_pause_ticks": point_pause_ticks,
	}
