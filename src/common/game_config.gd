class_name GameConfig
extends Resource

## Match settings. Scene ships a default .tres; parents override via initialize.

@export var vs_ai: bool = false
## Online 1v1 over Nakama MultiplayerBridge (host-authoritative sync).
@export var online: bool = false
## When online: write `global_wins` via submit_match_result.
@export var ranked: bool = false
## Local player's court side: 0 = Blue/left, 1 = Red/right.
@export var local_side: int = 0
@export var win_score: int = 7
@export var serve_height: float = 5.0
## Max hits on one side before a fault (classic volleyball = 3).
@export var max_touches: int = 3
## Active play time per rally before the ball explodes.
@export var round_duration_sec: float = 60.0
## Seconds left when the ball starts alarm-blinking red.
@export var round_alarm_sec: float = 5.0
