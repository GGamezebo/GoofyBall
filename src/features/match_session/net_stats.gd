class_name NetStats
extends RefCounted

## Rollback health counters for the overlay and the end-of-match log line.

var rollbacks: int = 0
var rollback_ticks_total: int = 0
var max_rollback: int = 0
var skipped_ticks: int = 0
var mismatches: int = 0
var sync_lost: int = 0
var prediction_misses: int = 0
var ping_ms: int = 0
var ping_max: int = 0
var local_lag: int = 0
var remote_lag: int = 0

var _ping_sum: int = 0
var _ping_samples: int = 0
## Rollbacks inside the current one-second window.
var _window_rollbacks: int = 0
var _window_start_ms: int = 0
var _rollbacks_per_sec: float = 0.0


func on_rollback(ticks: int) -> void:
	rollbacks += 1
	rollback_ticks_total += ticks
	max_rollback = maxi(max_rollback, ticks)
	_window_rollbacks += 1


func on_ping(rtt_ms: int, p_local_lag: int, p_remote_lag: int) -> void:
	ping_ms = rtt_ms
	ping_max = maxi(ping_max, rtt_ms)
	_ping_sum += rtt_ms
	_ping_samples += 1
	local_lag = p_local_lag
	remote_lag = p_remote_lag


func update(now_ms: int) -> void:
	if _window_start_ms == 0:
		_window_start_ms = now_ms
		return
	var elapsed := now_ms - _window_start_ms
	if elapsed >= 1000:
		_rollbacks_per_sec = float(_window_rollbacks) * 1000.0 / float(elapsed)
		_window_rollbacks = 0
		_window_start_ms = now_ms


func ping_avg() -> int:
	return roundi(float(_ping_sum) / _ping_samples) if _ping_samples > 0 else 0


func snapshot() -> Dictionary:
	return {
		"ping_ms": ping_ms,
		"ping_avg": ping_avg(),
		"ping_max": ping_max,
		"rollbacks_per_sec": _rollbacks_per_sec,
		"max_rollback": max_rollback,
		"rollbacks": rollbacks,
		"skipped_ticks": skipped_ticks,
		"mismatches": mismatches,
		"sync_lost": sync_lost,
		"prediction_misses": prediction_misses,
		"local_lag": local_lag,
		"remote_lag": remote_lag,
	}
