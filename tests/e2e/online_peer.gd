extends SceneTree

## End-to-end online check on one machine: two Godot processes talk over ENet (instead of the
## Nakama relay) and play a scripted match through the REAL game scene, OnlineRollback and
## SyncManager. SyncManager exchanges state hashes itself, so any divergence between the two
## simulations shows up as `remote_state_mismatch`.
##
##   godot --headless --path . --script res://tests/e2e/online_peer.gd -- role=host  port=24777
##   godot --headless --path . --script res://tests/e2e/online_peer.gd -- role=guest port=24777

const RUN_SECONDS := 20.0
const CONNECT_TIMEOUT := 20.0

var _host := true
var _port := 24777
var _ticks_seen := 0
var _rollbacks := 0
var _mismatches := 0
var _errors := 0
var _started := false
var _local_ticks := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "role=guest":
			_host = false
		elif arg.begins_with("port="):
			_port = int(arg.trim_prefix("port="))
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
	# Give the other side a moment to be fully connected too.
	await create_timer(0.3).timeout

	SyncManager.rollback_flagged.connect(func(_tick: int) -> void: _rollbacks += 1)
	SyncManager.remote_state_mismatch.connect(func(tick: int, _p: int, lh: int, rh: int) -> void:
		_mismatches += 1
		printerr("[e2e] %s: STATE MISMATCH tick %d local %d remote %d" % [role, tick, lh, rh]))
	SyncManager.sync_error.connect(func(msg: String) -> void:
		_errors += 1
		printerr("[e2e] %s: sync error: %s" % [role, msg]))
	SyncManager.sync_started.connect(func() -> void: _started = true)
	SyncManager.tick_finished.connect(func(_rb: bool) -> void: _ticks_seen += 1)

	var game: Node = (load("res://src/game/scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var runner := game.match_runner as MatchRunner
	var salt := 3 if _host else 11
	runner.input_override = func() -> Dictionary:
		_local_ticks += 1
		var block := _local_ticks / 25
		var a := ((block + salt) * 1103515245 + 12345) & 0x7fffffff
		var b := ((_local_ticks + salt) * 1664525 + 1013904223) & 0x7fffffff
		return {"x": ((a >> 8) % 201) - 100, "j": 1 if (b >> 6) % 5 == 0 else 0, "b": 1 if (b % 397) == 0 else 0}

	var cfg := GameConfig.new()
	cfg.online = true
	cfg.vs_ai = false
	cfg.local_side = 0 if _host else 1
	game.initialize({
		"custom_battle": cfg,
		"online": true,
		"local_side": cfg.local_side,
		"local_display_name": role,
	})

	await create_timer(RUN_SECONDS).timeout

	var sim_tick: int = int(runner.sim.s.get("tick", 0))
	print("[e2e] %s: started=%s sim_tick=%d rollbacks=%d mismatches=%d errors=%d score=%d:%d" % [
		role, _started, sim_tick, _rollbacks, _mismatches, _errors,
		int(runner.sim.s.get("score_l", 0)), int(runner.sim.s.get("score_r", 0)),
	])
	var ok := _started and sim_tick > 600 and _mismatches == 0 and _errors == 0
	game.deinit()
	quit(0 if ok else 1)
