extends TestCase

## Drives the real SyncManager (mechanized mode, no network) through OnlineRollback with
## LATE remote input, so it must predict, roll back and re-simulate — and still end up on
## exactly the same state as a plain, rollback-free replay.

const TOTAL_TICKS := 400
const REMOTE_DELAY := 5


func _scripted(tick: int, salt: int) -> Dictionary:
	var a := ((tick + salt) * 1103515245 + 12345) & 0x7fffffff
	return {"x": ((a >> 8) % 201) - 100, "j": (a >> 4) & 1, "b": 1 if (a % 211) == 0 else 0}


func test_late_remote_input_rolls_back_to_identical_state() -> void:
	# Reference: plain sim with the true inputs of both players.
	var cfg := VolleySim.make_config(7, 5.0, 3, 60.0, 5.0, [true, true], [true, true])
	var ref := VolleySim.new()
	ref.reset(cfg)
	var ref_states := {0: ref.save_state()}
	for t in range(1, TOTAL_TICKS + 1):
		ref.step([_scripted(t, 0), _scripted(t, 7)])
		ref_states[t] = ref.save_state()

	# Subject: local peer 1 plays left; peer 2 (right) arrives REMOTE_DELAY ticks late.
	var live := VolleySim.new()
	live.reset(cfg)
	var sample_count := [0]
	var sampler := func() -> Dictionary:
		sample_count[0] += 1
		return _scripted(sample_count[0], 0)

	await tree.process_frame
	var rb := OnlineRollback.new()
	rb.name = "OnlineRollbackTest"
	tree.root.add_child(rb)
	rb.bind_sim(
		sampler,
		func(inputs: Array) -> void: live.step(inputs),
		func() -> Dictionary: return live.save_state(),
		func(state: Dictionary) -> void: live.load_state(state),
		1,
		2
	)

	SyncManager.set_mechanized(true)
	SyncManager.set_network_adaptor(load("res://addons/godot-rollback-netcode/DummyNetworkAdaptor.gd").new(1))
	SyncManager.clear_peers()
	SyncManager.add_peer(2)
	SyncManager.start()
	expect(SyncManager.started, "SyncManager started (mechanized)")

	var right_path := str(rb.get_node("InputRight").get_path())
	var rollbacks := [0]
	var on_rollback := func(_tick: int) -> void: rollbacks[0] += 1
	SyncManager.rollback_flagged.connect(on_rollback)

	var delay: int = SyncManager.input_delay
	var calls := TOTAL_TICKS + delay
	for call in range(1, calls + 1):
		# Remote input for sim tick n only "arrives" REMOTE_DELAY calls after it was needed.
		var arriving := call - REMOTE_DELAY
		if arriving >= 1 and arriving <= TOTAL_TICKS:
			SyncManager.mechanized_input_received[2] = {arriving: {right_path: _scripted(arriving, 7)}}
		SyncManager.execute_mechanized_tick()

	SyncManager.rollback_flagged.disconnect(on_rollback)
	expect(rollbacks[0] > 0, "late remote input caused rollbacks (%d)" % rollbacks[0])

	# Every tick whose inputs are complete must equal the clean replay.
	var checked := 0
	for frame in SyncManager.state_buffer:
		if frame.tick > SyncManager._state_complete_tick or frame.tick < 1 or frame.tick > TOTAL_TICKS:
			continue
		var got: Dictionary = frame.data[str(rb.get_path())]
		expect(got == ref_states[frame.tick], "tick %d identical after rollback/resim" % frame.tick)
		checked += 1
	expect(checked > 5, "enough confirmed ticks compared (%d)" % checked)

	SyncManager.stop()
	SyncManager.clear_peers()
	SyncManager.set_mechanized(false)
	SyncManager.reset_network_adaptor()
	rb.remove_from_group("network_sync")
	for child in rb.get_children():
		child.remove_from_group("network_sync")
	rb.queue_free()
