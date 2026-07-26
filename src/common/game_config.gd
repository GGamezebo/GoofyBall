class_name GameConfig
extends Resource

## Match settings. Scene ships a default .tres; parents override via initialize.

@export var vs_ai: bool = false
@export var win_score: int = 7
@export var serve_height: float = 5.0
## Max hits on one side before a fault (classic volleyball = 3).
@export var max_touches: int = 3
## Active play time per rally before the ball explodes.
@export var round_duration_sec: float = 60.0
## Seconds left when the ball starts alarm-blinking red.
@export var round_alarm_sec: float = 5.0
