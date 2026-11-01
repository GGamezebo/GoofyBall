class_name ArenaPreset
extends Resource

## Court geometry (meters, x = 0 at the center, y = 0 on the floor). The court is split into
## one zone per team with a net between neighbouring zones.

@export var half_width: float = 7.0
@export var ceiling: float = 6.6
@export var net_height: float = 2.4
@export var net_half_width: float = 0.06
## Extra gap between a blob and the net.
@export var net_clearance: float = 0.07
@export var serve_height: float = 5.0
## Serve ball sits this far from the server toward the court center.
@export var serve_offset: float = 1.0
## The ball counts as landed below this height while falling.
@export var floor_score_y: float = 0.4


func to_dict() -> Dictionary:
	return {
		"half_width": half_width, "ceiling": ceiling, "net_height": net_height,
		"net_half_width": net_half_width, "net_clearance": net_clearance,
		"serve_height": serve_height, "serve_offset": serve_offset, "floor_score_y": floor_score_y,
	}
