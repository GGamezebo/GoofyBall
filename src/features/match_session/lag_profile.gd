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
## Wi-Fi hiccups: every `stall_every_ms` all outgoing messages are held for `stall_ms`
## and then arrive together (0 = never).
@export_range(0, 20000) var stall_every_ms: int = 0
@export_range(0, 3000) var stall_ms: int = 0


func is_active() -> bool:
	return delay_ms > 0 or jitter_ms > 0 or drop_rate > 0.0 or (stall_every_ms > 0 and stall_ms > 0)


## When a message sent at `now_ms` may leave at the earliest (end of the current stall).
func stall_release_ms(now_ms: int) -> int:
	if stall_every_ms <= 0 or stall_ms <= 0:
		return now_ms
	var phase := now_ms % stall_every_ms
	return now_ms - phase + stall_ms if phase < stall_ms else now_ms
