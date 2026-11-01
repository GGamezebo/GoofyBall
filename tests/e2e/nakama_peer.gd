extends SceneTree

## Full-app end-to-end through a REAL Nakama relay (needs `docker compose up -d` in server/):
## boots main.tscn (HFSM → menu → App/Online), the host creates a room, the guest joins by the
## code (passed through a file), both play the real battle with scripted input, and SyncManager
## state hashes must never differ.
##   godot --headless --path . --script res://tests/e2e/nakama_peer.gd -- role=host  code_file=<path> --profile=e2e_host
##   godot --headless --path . --script res://tests/e2e/nakama_peer.gd -- role=guest code_file=<path> --profile=e2e_guest
## Add `lag=4g` (or wifi / bad) to both to emulate a bad network on top of the relay.

const RUN_SECONDS := 25.0
const STEP_TIMEOUT := 40.0

var _host := true
var _code_file := ""
## Optional network emulation on top of the real relay: lag=wifi|4g|bad.
var _lag := ""
var _failed := ""
var _started := false
var _ticks := 0
var _state_loads := 0
var _mismatches := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "role=guest":
			_host = false
		elif arg.begins_with("code_file="):
			_code_file = arg.trim_prefix("code_file=")
		elif arg.begins_with("lag="):
			_lag = arg.trim_prefix("lag=")
	_run()


func _run() -> void:
	await process_frame
	var role := "host" if _host else "guest"
	var online_events = load("res://src/game/scenes/online/online_events.tres")
	online_events.ev_room_error.connect(func(text: String) -> void: _failed = "room error: " + text)
	online_events.ev_room_created.connect(func(code: String) -> void:
		var file := FileAccess.open(_code_file, FileAccess.WRITE)
		file.store_string(code)
		print("[e2e-nakama] host: room %s" % code))

	root.add_child((load("res://main.tscn") as PackedScene).instantiate())
	if not await _wait_for(func() -> bool: return root.find_child("Menu", true, false) != null, "menu"):
		return _finish(role)

	if _host:
		online_events.ev_create_room.emit()
	else:
		var code := ""
		var waited := 0.0
		while code.is_empty() and waited < STEP_TIMEOUT:
			await create_timer(0.25).timeout
			waited += 0.25
			if FileAccess.file_exists(_code_file):
				code = FileAccess.get_file_as_string(_code_file).strip_edges()
		if code.is_empty():
			_failed = "no room code from host"
			return _finish(role)
		print("[e2e-nakama] guest: joining %s" % code)
		online_events.ev_join_room.emit(code)

	if not await _wait_for(func() -> bool: return root.find_child("Session", true, false) != null, "battle"):
		return _finish(role)
	var sync = root.get_node("SyncManager")
	sync.sync_started.connect(func() -> void: _started = true)
	sync.tick_finished.connect(func(_rb: bool) -> void: _ticks += 1)
	sync.state_loaded.connect(func(_n: int) -> void: _state_loads += 1)
	sync.remote_state_mismatch.connect(func(tick: int, _p: int, lh: int, rh: int) -> void:
		_mismatches += 1
		printerr("[e2e-nakama] %s: STATE MISMATCH tick %d local %d remote %d" % [role, tick, lh, rh]))
	if not _lag.is_empty():
		var session_node = root.find_child("Session", true, false)
		session_node.set_lag_profile(load("res://src/features/match_session/lag_profiles/lag_%s.tres" % _lag))
	var driver: Node = load("res://tests/e2e/input_driver.gd").new()
	driver.salt = 3 if _host else 11
	root.add_child(driver)

	# The match may have started before we subscribed: sample SyncManager's own flag while it runs
	# (at the very end the other process may already have quit, which correctly stops the match).
	await create_timer(3.0).timeout
	_started = _started or bool(sync.started)
	await create_timer(RUN_SECONDS - 3.0).timeout
	var session = root.find_child("Session", true, false)
	if session != null:
		var stats: Dictionary = session.get_stats()
		print("[e2e-nakama] %s: ping=%d ping_max=%d rollbacks/s=%.1f max_rollback=%d skipped=%d" % [
			role, stats.get("ping_ms", -1), stats.get("ping_max", -1), stats.get("rollbacks_per_sec", 0.0),
			stats.get("max_rollback", -1), stats.get("skipped_ticks", -1)])
	if not _started:
		_failed = "sync never started"
	elif _ticks < 600:
		_failed = "too few ticks (%d)" % _ticks
	elif _mismatches > 0:
		_failed = "%d state mismatches" % _mismatches
	_finish(role)


func _wait_for(condition: Callable, what: String) -> bool:
	var waited := 0.0
	while not condition.call() and waited < STEP_TIMEOUT and _failed.is_empty():
		await create_timer(0.25).timeout
		waited += 0.25
	if _failed.is_empty() and not condition.call():
		_failed = "timeout waiting for " + what
	return _failed.is_empty()


func _finish(role: String) -> void:
	print("[e2e-nakama] %s: %s started=%s ticks=%d state_loads=%d mismatches=%d" % [
		role, "OK" if _failed.is_empty() else "FAIL (" + _failed + ")", _started, _ticks, _state_loads, _mismatches])
	quit(0 if _failed.is_empty() else 1)
