extends SceneTree

## End-to-end rollback check on one machine: two Godot processes connect over ENet (instead of
## the Nakama relay) and play through the REAL game scene, RollbackSession and SyncManager with
## network emulation (delay + jitter + dropped input packets) and forced random rollbacks.
## SyncManager compares state hashes, so any divergence shows up as a mismatch.
##   godot --headless --path . --script res://tests/e2e/online_peer.gd -- role=host  port=24777
##   godot --headless --path . --script res://tests/e2e/online_peer.gd -- role=guest port=24777
## Options (pass the same to both): lag=none|wifi|4g|bad|spikes (default 4g),
## input=scripted|idle (idle = nobody moves, predictions always right), stress=1|0 (forced rollbacks).

const RUN_SECONDS := 20.0
const CONNECT_TIMEOUT := 20.0
const LAG_PROFILE := "res://src/features/match_session/lag_profiles/lag_%s.tres"

var _host := true
var _port := 24777
var _lag := "4g"
var _idle := false
var _stress := true
var _sync_lost := 0
var _sync_regained := 0
var _started := false
var _ticks := 0
var _state_loads := 0
var _mismatches := 0
var _errors := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "role=guest":
			_host = false
		elif arg.begins_with("port="):
			_port = int(arg.trim_prefix("port="))
		elif arg.begins_with("lag="):
			_lag = arg.trim_prefix("lag=")
		elif arg == "input=idle":
			_idle = true
		elif arg == "stress=0":
			_stress = false
	_run()


func _run() -> void:
	await process_frame
	var role := "host" if _host else "guest"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(_port, 1) if _host else peer.create_client("127.0.0.1", _port)
	if err != OK:
		printerr("[e2e] %s: cannot start ENet (%d)" % [role, err])
		quit(2)
		return
	root.multiplayer.multiplayer_peer = peer
	var waited := 0.0
	while root.multiplayer.get_peers().is_empty() and waited < CONNECT_TIMEOUT:
		await create_timer(0.1).timeout
		waited += 0.1
	if root.multiplayer.get_peers().is_empty():
		printerr("[e2e] %s: no peer connected" % role)
		quit(2)
		return
	await create_timer(0.3).timeout

	# Autoloads are not compile-time identifiers inside a MainLoop script.
	var sync = root.get_node("SyncManager")
	sync.sync_started.connect(func() -> void: _started = true)
	sync.tick_finished.connect(func(_rb: bool) -> void: _ticks += 1)
	sync.state_loaded.connect(func(_n: int) -> void: _state_loads += 1)
	sync.remote_state_mismatch.connect(func(tick: int, _p: int, lh: int, rh: int) -> void:
		_mismatches += 1
		printerr("[e2e] %s: STATE MISMATCH tick %d local %d remote %d" % [role, tick, lh, rh]))
	sync.sync_error.connect(func(msg: String) -> void:
		_errors += 1
		printerr("[e2e] %s: sync error: %s" % [role, msg]))
	sync.sync_lost.connect(func() -> void: _sync_lost += 1)
	sync.sync_regained.connect(func() -> void: _sync_regained += 1)
	sync.debug_random_rollback_ticks = 6 if _stress else 0

	if not _idle:
		var driver: Node = load("res://tests/e2e/input_driver.gd").new()
		driver.salt = 3 if _host else 11
		root.add_child(driver)

	var guest_id: int = root.multiplayer.get_peers()[0] if _host else root.multiplayer.get_unique_id()
	var setup := (load("res://src/common/setups/online_1v1.tres") as MatchSetup).duplicate(true) as MatchSetup
	var slots := setup.slots()
	slots[0].peer_id = 1
	slots[1].peer_id = guest_id
	setup.match_seed = 4242

	var game: Node = (load("res://src/game/scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.initialize({"match_setup": setup})
	var session = game.get_node("Sessions/Session")
	session.set_lag_profile(load(LAG_PROFILE % _lag))

	await create_timer(RUN_SECONDS).timeout

	var stats: Dictionary = session.get_stats()
	print("[e2e] %s: lag=%s idle=%s started=%s ticks=%d state_loads=%d sync_lost=%d regained=%d mismatches=%d errors=%d ping=%d max_rollback=%d" % [
		role, _lag, _idle, _started, _ticks, _state_loads, _sync_lost, _sync_regained, _mismatches, _errors,
		stats.get("ping_ms", -1), stats.get("max_rollback", -1)])
	var ok := _started and _ticks > 600 and _mismatches == 0 and _errors == 0
	if _stress:
		ok = ok and _state_loads > 20
	game.deinit()
	await create_timer(0.5).timeout
	quit(0 if ok else 1)
