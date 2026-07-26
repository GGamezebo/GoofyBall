class_name FSM
extends Node

signal ev_state_changed(from_state_name: String, to_state_name: String)

# Special transition constants
const ALL_STATES = "*"
const SAME_DST = "="
const INIT_STATE = "__default_root_state"
const INIT_EVENT_NAME = "__default_root_setup_event"

var _states_map: Dictionary = {}        # {name: FSMState}
var _transaction_map: Dictionary = {}   # {event_name: {src_state: dst_state}}
var _current_state_name: String = INIT_STATE
var _final_state_name: String = ""
var _event_queue: Array = []
var _is_running: bool = false
var _callbacks: Dictionary = {}         # {(from, to): [Callable]}

func _init(cfg: Dictionary):
	_setup(cfg)

func _setup(cfg: Dictionary):
	if not cfg.has("initial"):
		push_error("FSM Config: missing 'initial'")
		return
	
	var initial = cfg["initial"]
	var initial_event = initial.get("event", INIT_EVENT_NAME)
	
	if not cfg.has("transitions"):
		push_error("FSM Config: missing 'transitions'")
		return

	# Register provided state objects
	if cfg.has("states"):
		for state in cfg["states"]:
			state.sync_fsm(self)
			_states_map[state.state_name] = state

	# Build the transition table
	_add_transaction(INIT_STATE, initial["state"], initial_event)
	
	for t in cfg["transitions"]:
		_add_transaction(t["src"] if t.has("src") else ALL_STATES, t["dst"], t["event"])

	_final_state_name = cfg.get("final", "")
	
	# Initial startup
	if not initial.has("event"):
		add_event(INIT_EVENT_NAME)

func deinit():
	for key in _states_map:
		_states_map[key].deinit()
	_states_map.clear()
	_transaction_map.clear()
	_callbacks.clear()
	_event_queue.clear()
	_is_running = false

func add_callback(from_state: String, to_state: String, callback: Callable):
	var k = from_state + "->" + to_state
	if not _callbacks.has(k):
		_callbacks[k] = []
	_callbacks[k].append(callback)

func remove_callback(from_state: String, to_state: String, callback: Callable):
	var key = from_state + "->" + to_state
	if _callbacks.has(key):
		_callbacks[key].erase(callback)

func add_event(event_name: String, event_data: Dictionary = {}):
	_event_queue.append({"name": event_name, "data": event_data})
	
	if _is_running:
		return
		
	_is_running = true
	_run_queue()
	_is_running = false

func _run_queue():
	while _event_queue.size() > 0:
		var event = _event_queue.pop_front()
		_process_event(event["name"], event["data"])

func _process_event(event_name: String, event_data: Dictionary):
	if not can_fire(event_name):
		push_error("FSM Error: event %s invalid in state %s" % [event_name, _current_state_name])
		return

	var src = _current_state_name
	var transitions = _transaction_map[event_name]
	var dst = transitions.get(src, transitions.get(ALL_STATES))

	if dst == SAME_DST:
		dst = src

	if _current_state_name != dst:
		var prev_state = _states_map[_current_state_name]
		prev_state.leave(event_data)

		_current_state_name = dst
		var current_state = _states_map[_current_state_name]
		current_state.enter(prev_state, event_data)

		_call_callbacks(prev_state.state_name, current_state.state_name)
	else:
		_states_map[_current_state_name].reenter(event_data)

func can_fire(event: String) -> bool:
	if is_finished() or not _transaction_map.has(event):
		return false
	var transitions = _transaction_map[event]
	return transitions.has(_current_state_name) or transitions.has(ALL_STATES)

func is_finished() -> bool:
	return _final_state_name != "" and _current_state_name == _final_state_name

func _add_transaction(src, dst: String, event: String):
	var srcs = []
	if src is Array:
		srcs = src
	else:
		srcs = [src]

	# Auto-create states missing from statesMap
	for s_name in srcs:
		_ensure_state(s_name)
	_ensure_state(dst)

	if not _transaction_map.has(event):
		_transaction_map[event] = {}

	for s_name in srcs:
		_transaction_map[event][s_name] = dst

func _ensure_state(state_name: String):
	if state_name != SAME_DST and not _states_map.has(state_name):
		var new_state = FSMState.new(state_name)
		new_state.sync_fsm(self)
		_states_map[state_name] = new_state

func _call_callbacks(from_name: String, to_name: String) -> void:
	ev_state_changed.emit(from_name, to_name)
	var key = from_name + "->" + to_name
	if _callbacks.has(key):
		for callback in _callbacks[key]:
			if callback.is_valid():
				callback.call(from_name, to_name)

func get_current_state_name() -> String:
	return _current_state_name
