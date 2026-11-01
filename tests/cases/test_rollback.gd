extends TestCase

## Drives the real SyncManager (mechanized mode, no network) through RollbackSession with LATE
## remote input, so it must predict, roll back and re-simulate — and still end up on exactly the
## same states as a plain, rollback-free replay.

const SETUP_PATH := "res://src/common/setups/local_2p.tres"
const TOTAL_TICKS := 400
const REMOTE_DELAY := 5


func _scripted(tick: int, salt: int) -> Dictionary:
	var a := ((tick + salt) * 1103515245 + 12345) & 0x7fffffff
	return {"x": ((a >> 8) % 201) - 100, "j": (a >> 4) & 1, "a": 0}


func test_late_remote_input_rolls_back_to_identical_state() -> void:
	var setup := (load(SETUP_PATH) as MatchSetup).duplicate(true) as MatchSetup
	setup.match_seed = 31337
	var config := setup.to_sim_config()

	var ref := VolleySim.new()
	ref.reset(config)
	var ref_states := {0: ref.save_state()}
	for t in range(1, TOTAL_TICKS + 1):
		ref.step([_scripted(t, 0), _scripted(t, 7)])
		ref_states[t] = ref.save_state()

	var live := VolleySim.new()
	live.reset(config)
	await tree.process_frame
	var session := RollbackSession.new()
	session.name = "RollbackSessionTest"
	tree.root.add_child(session)
	var rolled_back := [0]
	session.ev_rolled_back.connect(func(_ticks: int) -> void: rolled_back[0] += 1)
	session.bind_sim(2,
		func(_slot: int) -> Dictionary: return VolleySim.neutral_input(),
		func(inputs: Array) -> int:
			live.step(inputs)
			return int(live.state["tick"]),
		live.save_state, live.load_state, VolleySim.neutral_input())
	var slot_peers: Array[int] = [1, 2]
	session.bind_inputs(slot_peers, 1)

	SyncManager.set_mechanized(true)
	SyncManager.set_network_adaptor(load("res://addons/godot-rollback-netcode/DummyNetworkAdaptor.gd").new(1))
	SyncManager.clear_peers()
	SyncManager.add_peer(2)
	SyncManager.start()
	expect(SyncManager.started, "SyncManager started (mechanized)")

	var left_path := str(session.get_node("Input0").get_path())
	var right_path := str(session.get_node("Input1").get_path())
	var misses := 0
	var calls: int = TOTAL_TICKS + SyncManager.input_delay
	for call_index in range(1, calls + 1):
		SyncManager.mechanized_input_received[1] = {call_index: {left_path: _scripted(call_index, 0)}}
		var arriving := call_index - REMOTE_DELAY
		if arriving >= 1:
			var actual := {right_path: _scripted(arriving, 7)}
			SyncManager._calculate_data_hash(actual)
			# Mechanized mode has no network receive path: mirror _on_received_input_tick().
			var frame = SyncManager.get_input_frame(arriving)
			if frame != null and frame.players.has(2) and frame.players[2].predicted \
					and frame.players[2].input["$"] != actual["$"]:
				misses += 1
				SyncManager.mechanized_rollback_ticks = maxi(
					SyncManager.mechanized_rollback_ticks, SyncManager.current_tick - arriving + 1)
			SyncManager.mechanized_input_received[2] = {arriving: actual}
		SyncManager.execute_mechanized_tick()
		SyncManager.execute_mechanized_interpolation_frame(1.0 / 60.0)

	expect(misses > 0, "late remote input caused prediction misses (%d)" % misses)
	expect(rolled_back[0] > 0, "session reported rollbacks (%d)" % rolled_back[0])

	var checked := 0
	for frame in SyncManager.state_buffer:
		if frame.tick > SyncManager._state_complete_tick or frame.tick < 1 or frame.tick > TOTAL_TICKS:
			continue
		var got: Dictionary = frame.data[str(session.get_path())]
		expect(got == ref_states[frame.tick], "tick %d identical after rollback/resim" % frame.tick)
		checked += 1
	expect(checked > 5, "enough confirmed ticks compared (%d)" % checked)

	SyncManager.stop()
	SyncManager.clear_peers()
	SyncManager.set_mechanized(false)
	SyncManager.reset_network_adaptor()
	session.remove_from_group("network_sync")
	for child in session.get_children():
		child.remove_from_group("network_sync")
	session.queue_free()
