class_name FiniteStateMachineConditional
extends RefCounted

signal state_changed(previous_state: FSMConditionalState, new_state: FSMConditionalState)

const MAX_TRANSITIONS = 100

var _state_map: Dictionary = {} # {id: State}
var _states: Array[FSMConditionalState] = []
var _transitions: Dictionary = {} # {from_idx: {to_idx: [Callable, Callable]}}
var _current_state_index: int = 0
var is_destroyed: bool = false

## Create an FSM from config (similar to Python make)
static func make_from_config(config: Dictionary) -> FiniteStateMachineConditional:
	var init_state = config["init"]
	var state_set = []
	
	for t in config["transitions"]:
		if not state_set.has(t["src"]): state_set.append(t["src"])
		if not state_set.has(t["dst"]): state_set.append(t["dst"])
	
	state_set.erase(init_state)
	
	var fsm = FiniteStateMachineConditional.new()
	fsm.init_fsm(init_state, state_set)
	
	for t in config["transitions"]:
		fsm.add_transition(t["src"], t.get("condition"), t["dst"], t.get("callback"))
	
	return fsm

func init_fsm(default_state: FSMConditionalState, other_states: Array = []) -> void:
	add_state(default_state)
	for s in other_states:
		add_state(s)
	
	_current_state_index = 0
	current_state().activate()
	is_destroyed = false

func deinit() -> void:
	is_destroyed = true
	for s in _states:
		s.deinit()
	_states.clear()
	_state_map.clear()
	_transitions.clear()

func current_state() -> FSMConditionalState:
	return _states[_current_state_index]

func get_state_by_id(p_id: int) -> FSMConditionalState:
	return _state_map.get(p_id)

func add_state(new_state: FSMConditionalState) -> void:
	assert(not _states.has(new_state), "State already added")
	_states.append(new_state)
	
	if new_state.state_id != FSMConditionalState.UNINITIALIZED_STATE_ID:
		assert(not _state_map.has(new_state.state_id), "State ID collision")
		_state_map[new_state.state_id] = new_state

func add_transition(from_state: FSMConditionalState, condition: Callable, to_state: FSMConditionalState, callback: Callable = Callable()) -> void:
	var from_idx = _states.find(from_state)
	var to_idx = _states.find(to_state)
	
	assert(from_idx != -1 and to_idx != -1, "States must be added to FSM first")
	
	if not _transitions.has(from_idx):
		_transitions[from_idx] = {}
	
	_transitions[from_idx][to_idx] = [condition, callback]

func update(dt: float) -> void:
	var transition_count = 0
	while true:
		var transited = _update_transitions()
		if not transited or is_destroyed:
			break
		
		transition_count += 1
		if transition_count > MAX_TRANSITIONS:
			push_warning("FSM: Exceeded max transitions per tick")
			break
	
	if not is_destroyed:
		current_state().update(dt)

func force_transit(to_state: FSMConditionalState) -> void:
	var to_idx = _states.find(to_state)
	assert(to_idx != -1, "Target state not found")
	
	var callback = Callable()
	if _transitions.has(_current_state_index):
		var trans_data = _transitions[_current_state_index].get(to_idx)
		if trans_data:
			callback = trans_data[1]
	
	_perform_transition(to_idx, callback, true)

func reset() -> void:
	current_state().interrupt()
	for s in _states:
		s.reset()
	_current_state_index = 0
	current_state().activate()

func _update_transitions() -> bool:
	var curr_idx = _current_state_index
	if current_state().can_transit() and _transitions.has(curr_idx):
		var possible_transitions = _transitions[curr_idx]
		for to_idx in possible_transitions:
			var data = possible_transitions[to_idx]
			var condition = data[0]
			var callback = data[1]
			
			# Transition when there is no condition or it returns true
			if not condition.is_valid() or condition.call():
				_perform_transition(to_idx, callback)
				return true
	return false
	
func _perform_transition(to_idx: int, callback: Callable, forced: bool = false) -> void:
	var previous_state = current_state()
	
	if forced:
		previous_state.interrupt()
	else:
		previous_state.deactivate()
	
	_current_state_index = to_idx
	var new_state = current_state()
	new_state.activate()
	
	if callback.is_valid():
		callback.call()
	
	if not is_destroyed:
		state_changed.emit(previous_state, new_state)
