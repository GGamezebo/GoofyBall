extends IScene

## Battle context — orchestration only: MatchSetup → sim → session (local or rollback) →
## inputs → view → HUD (via GameEvents) → result (`root_events.ev_exit_game`).
## F6: plays the exported default setup (vs AI) on its own.

@export var root_events: RootEvents
@export var online_events: OnlineEvents
@export var game_events: GameEvents
@export var default_setup: MatchSetup
@export var palette: TeamPalette
@export var log_settings: LogSettings
@export var net_tuning: NetTuning
## Network emulation presets for the debug overlay (index 0 = off).
@export var lag_profiles: Array[LagProfile] = []
@export var determinism_probe: DeterminismProbe
@export var match_view: MatchView
@export var hud: Hud
@export var session_parent: Node
## Keep showing the final rally this long before the results screen.
@export var end_linger_ticks: int = 120
@export var abort_delay_sec: float = 2.0

var _setup: MatchSetup
var _sim := VolleySim.new()
var _session: MatchSession
var _inputs: MatchInputs
var _listener := EventListener.new()
var _log: LogChannel
var _online: bool = false
var _finished: bool = false
var _seen_point_serial: int = 0
var _last_scores: Array = []
var _over_announced: bool = false


func initialize(data: Dictionary) -> void:
	_log = LogChannel.new("match", log_settings)
	var payload_setup := data.get("match_setup") as MatchSetup
	_setup = payload_setup if payload_setup != null else default_setup.duplicate(true)
	if payload_setup == null:
		_setup.match_seed = randi()
	_sim.reset(_setup.to_sim_config())

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	_online = _setup.has_remote_peers(my_id)
	_inputs = MatchInputs.new(_setup, my_id, _sim)

	if _online:
		_session = RollbackSession.new()
	else:
		_session = LocalSession.new()
	_session.name = "Session"
	session_parent.add_child(_session)
	_session.bind_sim(_inputs.slot_count(), _inputs.sample, _step, _sim.save_state, _sim.load_state, VolleySim.neutral_input())
	_listener.add(_session.ev_started, _on_session_started)
	_listener.add(_session.ev_ticked, match_view.capture)
	_listener.add(_session.ev_rolled_back, func(_ticks: int) -> void: match_view.on_rolled_back())
	_listener.add(_session.ev_status, func(text: String) -> void: game_events.ev_status.emit(text))
	_listener.add(_session.ev_stopped, _on_session_stopped)
	_listener.add(_session.ev_aborted, _on_session_aborted)

	hud.initialize()
	_listener.add(game_events.ev_pause_requested, func() -> void: _session.set_paused(true))
	_listener.add(game_events.ev_resume_requested, func() -> void: _session.set_paused(false))
	_listener.add(game_events.ev_exit_requested, _on_exit_requested)
	_listener.add(hud.net_overlay.ev_lag_preset_selected, _on_lag_preset_selected)
	_listener.add(hud.net_overlay.ev_probe_requested, _on_probe_requested)
	hud.net_overlay.bind_stats(_session.get_stats)
	var lag_titles: Array[String] = []
	if _online:
		for profile in lag_profiles:
			lag_titles.append(profile.title)
	hud.net_overlay.set_lag_presets(lag_titles)

	var local_slots := _inputs.local_slots()
	match_view.setup(_sim, _setup, local_slots)
	_last_scores = (_sim.state["scores"] as Array).duplicate()
	_seen_point_serial = int(_sim.state["point_serial"])
	game_events.ev_match_started.emit(_match_info(local_slots))

	_log.info("match_start", {
		"mode": _mode_name(), "seed": _setup.match_seed, "players": _sim.player_count(),
		"teams": _sim.team_count(), "me": my_id,
	})
	if _online:
		var slot_peers: Array[int] = []
		for slot in _setup.slots():
			slot_peers.append(slot.peer_id)
		(_session as RollbackSession).tuning = net_tuning
		(_session as RollbackSession).setup(slot_peers, LogChannel.new("net", log_settings))
	else:
		_session.start()


func deinit() -> void:
	if _session != null:
		if _finished:
			_session.shutdown()
		else:
			_session.leave()
	hud.deinit()
	_listener.deinit()
	super.deinit()


func _step(inputs: Array) -> int:
	_sim.step(inputs)
	return int(_sim.state["tick"])


func _process(_delta: float) -> void:
	if _session == null or _finished:
		return
	_emit_score_changes()
	if _sim.is_match_over():
		if not _over_announced:
			_over_announced = true
			game_events.ev_match_over.emit(int(_sim.state["winner_team"]))
		if int(_sim.state["phase_ticks"]) >= end_linger_ticks and _session.is_tick_confirmed():
			_finish(false, "")


func _emit_score_changes() -> void:
	var scores: Array = _sim.state["scores"]
	if scores != _last_scores:
		_last_scores = scores.duplicate()
		game_events.ev_score_changed.emit(_last_scores)
	var serial := int(_sim.state["point_serial"])
	if serial > _seen_point_serial:
		var team := int(_sim.state["point_team"])
		game_events.ev_point.emit(team, int(_sim.state["point_reason"]))
		_log.info("point", {"team": team, "score": ":".join(scores.map(func(v): return str(v))),
			"reason": int(_sim.state["point_reason"]), "tick": int(_sim.state["tick"])})
	elif serial < _seen_point_serial:
		_log.debug("point_rolled_back", {"serial": serial})
	_seen_point_serial = serial
	if _over_announced and not _sim.is_match_over():
		_over_announced = false


func _on_session_started() -> void:
	_log.info("session_started", {"online": _online})
	game_events.ev_status.emit("")


func _on_session_stopped() -> void:
	# Online guest: the host already saw the final confirmed tick and stopped the match.
	if _finished:
		return
	if _sim.is_match_over():
		_finish(false, "")
	else:
		_abort("stopped")


func _on_session_aborted(reason: String) -> void:
	_abort(reason)


func _abort(reason: String) -> void:
	if _finished:
		return
	_log.warn("match_abort", {"reason": reason, "tick": int(_sim.state["tick"])})
	game_events.ev_status.emit(_reason_text(reason))
	_finished = true
	_session.shutdown()
	await get_tree().create_timer(abort_delay_sec).timeout
	if not is_inside_tree():
		return
	root_events.ev_exit_game.emit(_build_result(true, reason))


func _finish(aborted: bool, reason: String) -> void:
	_finished = true
	_session.shutdown()
	var result := _build_result(aborted, reason)
	_log.info("match_end", {"winner": result["winner_team"], "score": ":".join(result["scores"].map(func(v): return str(v))),
		"ticks": int(_sim.state["tick"])})
	root_events.ev_exit_game.emit(result)


func _on_exit_requested() -> void:
	if _finished:
		return
	_finished = true
	_log.info("match_exit_by_player", {"tick": int(_sim.state["tick"])})
	_session.leave()
	if _online:
		online_events.ev_leave_room.emit()
	root_events.ev_return_to_menu.emit({})


func _on_lag_preset_selected(index: int) -> void:
	if _session is RollbackSession and index >= 0 and index < lag_profiles.size():
		(_session as RollbackSession).set_lag_profile(lag_profiles[index])


func _on_probe_requested() -> void:
	if determinism_probe == null:
		return
	var result := determinism_probe.run()
	_log.info("determinism_probe", result)
	hud.net_overlay.show_probe_result(result)


func _build_result(aborted: bool, reason: String) -> Dictionary:
	return {
		"match_setup": _setup,
		"scores": (_sim.state["scores"] as Array).duplicate(),
		"winner_team": int(_sim.state["winner_team"]),
		"local_teams": _local_teams(_inputs.local_slots()),
		"team_names": _team_names(),
		"online": _online,
		"aborted": aborted,
		"reason": reason,
	}


func _match_info(local_slots: Array[int]) -> Dictionary:
	return {"team_names": _team_names(), "local_teams": _local_teams(local_slots), "online": _online}


func _team_names() -> Array:
	var names: Array = []
	for team in _setup.teams:
		var slot_names: Array = []
		for slot in team.slots:
			slot_names.append(slot.display_name)
		names.append(", ".join(slot_names))
	return names


func _local_teams(local_slots: Array[int]) -> Array:
	var teams: Array = []
	for slot in local_slots:
		var team := _setup.slot_team(slot)
		if not teams.has(team):
			teams.append(team)
	return teams


func _mode_name() -> String:
	if _online:
		return "online"
	return "local_2p" if _setup.local_human_count() > 1 else "vs_ai"


static func _reason_text(reason: String) -> String:
	match reason:
		"opponent_left":
			return "Соперник отключился"
		"sync_error":
			return "Связь потеряна"
		"handshake_timeout", "opponent_missing":
			return "Соперник не подключился"
		"stopped":
			return "Матч остановлен"
	return "Матч прерван"
