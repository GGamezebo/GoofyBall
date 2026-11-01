class_name MatchSession
extends Node

## Drives the deterministic sim tick loop. Game code is session-agnostic: it hands over
## callables and listens to the signals; where inputs come from (keyboard, bot, network)
## and when ticks run (locally, or re-simulated after a rollback) is the session's business.
##   sample(slot) -> Dictionary   local input of a slot for this tick
##   step(inputs: Array) -> int   advance the sim one tick, return the new tick
##   save() -> Dictionary / load(state) -> void   snapshot / restore (rollback only)

## The tick loop runs (online: both peers are in sync).
@warning_ignore("unused_signal")
signal ev_started
## After every sim step, including re-simulated ones during a rollback.
@warning_ignore("unused_signal")
signal ev_ticked(tick: int)
## State was restored `ticks` back; the following ev_ticked calls re-simulate them.
@warning_ignore("unused_signal")
signal ev_rolled_back(ticks: int)
## Short status for the HUD ("" = clear).
@warning_ignore("unused_signal")
signal ev_status(text: String)
## The tick loop stopped normally (online: the host stopped the match).
@warning_ignore("unused_signal")
signal ev_stopped
## The match cannot continue (opponent left, sync lost, desync).
@warning_ignore("unused_signal")
signal ev_aborted(reason: String)

var _sample: Callable
var _step: Callable
var _save: Callable
var _load: Callable
var _slot_count: int = 0
var _neutral: Dictionary = {}


func bind_sim(slot_count: int, sample: Callable, step: Callable, save_fn: Callable, load_fn: Callable, neutral: Dictionary) -> void:
	_slot_count = slot_count
	_sample = sample
	_step = step
	_save = save_fn
	_load = load_fn
	_neutral = neutral


func start() -> void:
	pass


func shutdown() -> void:
	pass


func set_paused(_paused: bool) -> void:
	pass


## True when the current tick can no longer be rolled back (safe to show the final result).
func is_tick_confirmed() -> bool:
	return true


func is_online() -> bool:
	return false


## Numbers for the net overlay; empty for local play.
func get_stats() -> Dictionary:
	return {}
