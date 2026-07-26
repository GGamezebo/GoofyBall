class_name GameConfig
extends Resource

## Match settings. Scene ships a default .tres; parents override via initialize.

@export var vs_ai: bool = false
@export var win_score: int = 7
@export var serve_height: float = 5.0
## Max hits on one side before a fault (classic volleyball = 3).
@export var max_touches: int = 3
