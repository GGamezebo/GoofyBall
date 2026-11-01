class_name LagProfile
extends Resource

## Fake bad network for debug builds (applied to OUR outgoing messages, so each side adds
## its own half of the round trip). Real relay traffic is TCP: order is kept, a "lost" input
## packet is simply dropped and recovered from the resent history in later messages.

@export var title: String = "Без эмуляции"
## One-way delay added to every outgoing message.
@export_range(0, 500) var delay_ms: int = 0
## Random extra delay 0..jitter_ms (order is still preserved, like TCP).
@export_range(0, 200) var jitter_ms: int = 0
## Share of input packets dropped (0..1).
@export_range(0.0, 0.5) var drop_rate: float = 0.0


func is_active() -> bool:
	return delay_ms > 0 or jitter_ms > 0 or drop_rate > 0.0
