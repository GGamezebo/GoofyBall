class_name HfsmSceneRegistry
extends RefCounted

## Mounts Godot scenes declared on HFSM states (`scene: { id, loading_screen, async_loading, on_event }`).
## Nesting matches the HFSM tree: a state's scene is parented under the nearest ancestor scene
## (or `_host` for the root). Sibling order follows JSON `states` key order.

var _paths: Dictionary = {}
var _loading_screen_scene: PackedScene = null
var _min_load_time: float = 0.0

## state_name -> mounted Node
var _instances: Dictionary = {}
## state_name -> mount generation (cancel token)
var _tokens: Dictionary = {}
var _loading_screens: Dictionary = {}
var _is_loading: Dictionary = {}
## state_name -> Array[HfsmEvent] while mount in flight
var _pending_events: Dictionary = {}
var _hfsm: HFSM = null
var _host: Node = null


func setup(
	hfsm: HFSM,
	host: Node,
	paths: Dictionary,
	loading_screen_scene: PackedScene = null,
	min_load_time: float = 0.0,
) -> void:
	_hfsm = hfsm
	_host = host
	_paths = paths.duplicate()
	_loading_screen_scene = loading_screen_scene
	_min_load_time = min_load_time

func on_enter(state: HfsmStateNode, data: Dictionary = {}) -> void:
	if not state.has_scene():
		return
	_pending_events[state.name] = []
	var payload: Dictionary = data if data else {}
	if state.scene.get("async_loading", true):
		_mount_async(state, payload)
	else:
		_mount(state, payload)


func on_event(state: HfsmStateNode, event: HfsmEvent) -> void:
	var node: Node = _instances.get(state.name)
	if node != null and is_instance_valid(node):
		if node.has_method("on_event"):
			node.on_event(event.name, event.data)
		return
	if state.name in _pending_events:
		(_pending_events[state.name] as Array).append(event)


func on_leave(state: HfsmStateNode) -> void:
	if not state.has_scene() and state.name not in _instances and state.name not in _tokens:
		return
	_pending_events.erase(state.name)
	_release(state.name)


func on_reset_all(states: Array) -> void:
	for state in states:
		if state is HfsmStateNode:
			on_leave(state)


func get_instance(state_name: String) -> Node:
	var node: Node = _instances.get(state_name)
	if node != null and is_instance_valid(node):
		return node
	return null


func clear() -> void:
	var names: Array = _tokens.keys()
	for state_name in names:
		_release(str(state_name))
	_instances.clear()
	_tokens.clear()
	_loading_screens.clear()
	_is_loading.clear()
	_pending_events.clear()
	_hfsm = null
	_host = null


func _release(state_name: String) -> void:
	_bump_token(state_name)
	_is_loading[state_name] = false
	_free_loading_screen(state_name)

	var node: Node = _instances.get(state_name)
	_instances.erase(state_name)
	if node == null or not is_instance_valid(node):
		return
	if node.has_method("deinit"):
		node.deinit()
	node.queue_free()


func _resolve_path(state: HfsmStateNode) -> Dictionary:
	var state_name: String = state.name
	var scene_id: String = str(state.scene.id)
	var path: String = str(_paths.get(scene_id, ""))
	if path.is_empty():
		push_error("[HfsmSceneRegistry] Unknown scene id '%s' (state '%s')" % [scene_id, state_name])
		return {}
	return {"state_name": state_name, "path": path}


func _finish_mount(state: HfsmStateNode, packed: PackedScene, data: Dictionary) -> void:
	var state_name: String = state.name
	if packed == null:
		_is_loading[state_name] = false
		push_error("[HfsmSceneRegistry] Failed to load scene for state '%s'" % state_name)
		return
	var instance: IScene = packed.instantiate()
	_instances[state_name] = instance
	_attach_instance(state, instance)
	instance.sync_hfsm(_hfsm)
	instance.initialize(data)
	var post_mount_event: String = str(state.scene.get("on_event", ""))
	if not post_mount_event.is_empty() and _hfsm != null:
		_hfsm.add_event(post_mount_event, data)
	_is_loading[state_name] = false
	if is_instance_valid(instance):
		_flush_pending_events(state_name, instance)


## Parent under nearest ancestor scene instance; fall back to host for the tree root.
func _resolve_mount_parent(state: HfsmStateNode) -> Node:
	var ancestor := state.parent
	while ancestor != null:
		if ancestor.has_scene():
			var parent_inst: Node = _instances.get(ancestor.name)
			if parent_inst != null and is_instance_valid(parent_inst):
				return parent_inst
		ancestor = ancestor.parent
	return _host


func _attach_instance(state: HfsmStateNode, instance: Node) -> void:
	var parent_node := _resolve_mount_parent(state)
	parent_node.add_child(instance)
	_sort_mounted_siblings(state, parent_node)


## Keep HFSM-mounted siblings in the same order as `states` in the JSON config.
func _sort_mounted_siblings(state: HfsmStateNode, parent_node: Node) -> void:
	var parent_state := state.parent
	if parent_state == null or parent_node == null:
		return
	var desired: Array[Node] = []
	for child_name in parent_state.children.keys():
		var child: HfsmStateNode = parent_state.children[child_name]
		if child == null or not child.has_scene():
			continue
		var inst: Node = _instances.get(child.name)
		if inst != null and is_instance_valid(inst) and inst.get_parent() == parent_node:
			desired.append(inst)
	if desired.is_empty():
		return
	var start := parent_node.get_child_count()
	for child in parent_node.get_children():
		if child in desired:
			start = child.get_index()
			break
	for i in range(desired.size()):
		parent_node.move_child(desired[i], start + i)


func _mount(state: HfsmStateNode, data: Dictionary) -> void:
	var resolved := _resolve_path(state)
	if resolved.is_empty():
		return
	var state_name: String = resolved.state_name
	var path: String = resolved.path

	_bump_token(state_name)
	_is_loading[state_name] = true
	_free_loading_screen(state_name)

	var existing: Node = _instances.get(state_name)
	if existing != null and is_instance_valid(existing):
		_instances.erase(state_name)
		if existing.has_method("deinit"):
			existing.deinit()
		existing.queue_free()

	var packed: PackedScene = load(_resolve_resource_path(path)) as PackedScene
	_finish_mount(state, packed, data)


func _mount_async(state: HfsmStateNode, data: Dictionary) -> void:
	var resolved := _resolve_path(state)
	if resolved.is_empty():
		return
	var state_name: String = resolved.state_name
	var path: String = resolved.path

	var token: int = _bump_token(state_name)
	_is_loading[state_name] = true
	var use_loading_screen: bool = state.scene.get("loading_screen", false)
	var load_start: float = Time.get_unix_time_from_system()

	_free_loading_screen(state_name)
	if use_loading_screen and _loading_screen_scene != null:
		var loading_screen = _loading_screen_scene.instantiate()
		_loading_screens[state_name] = loading_screen
		_host.add_child(loading_screen)
		# Drop previous instance of this state while loading screen shows.
		var prev: Node = _instances.get(state_name)
		if prev != null and is_instance_valid(prev):
			_instances.erase(state_name)
			if prev.has_method("deinit"):
				prev.deinit()
			prev.queue_free()

	var packed: PackedScene = await _load_packed_async(
		path,
		token,
		state_name,
		func(progress: float) -> void:
			var ls = _loading_screens.get(state_name)
			if ls != null and is_instance_valid(ls) and ls.has_method("update_progress"):
				ls.update_progress(progress)
	)
	if token != int(_tokens.get(state_name, 0)):
		_is_loading[state_name] = false
		return

	if not use_loading_screen:
		var existing: Node = _instances.get(state_name)
		if existing != null and is_instance_valid(existing):
			_instances.erase(state_name)
			if existing.has_method("deinit"):
				existing.deinit()
			existing.queue_free()

	if packed == null:
		_is_loading[state_name] = false
		push_error("[HfsmSceneRegistry] Failed to load scene '%s' for state '%s'" % [path, state_name])
		return

	var elapsed: float = Time.get_unix_time_from_system() - load_start
	if elapsed < _min_load_time:
		await _host.get_tree().create_timer(_min_load_time - elapsed).timeout
		if token != int(_tokens.get(state_name, 0)):
			_is_loading[state_name] = false
			return

	if token != int(_tokens.get(state_name, 0)):
		_is_loading[state_name] = false
		return

	_finish_mount(state, packed, data)

	var ls_done = _loading_screens.get(state_name)
	_loading_screens.erase(state_name)
	if ls_done != null and is_instance_valid(ls_done):
		if ls_done.has_method("fade_out"):
			ls_done.fade_out()
		else:
			ls_done.queue_free()


func _flush_pending_events(state_name: String, instance: Node) -> void:
	var queued: Array = _pending_events.get(state_name, [])
	_pending_events.erase(state_name)
	if not instance.has_method("on_event"):
		return
	for event in queued:
		if event is HfsmEvent:
			instance.on_event(event.name, event.data)


func _resolve_resource_path(path: String) -> String:
	var resolved: String = path
	if path.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(path)
		if uid != ResourceUID.INVALID_ID:
			var uid_path := ResourceUID.get_id_path(uid)
			if not uid_path.is_empty():
				resolved = uid_path
	return resolved


func _load_packed_async(
	path: String,
	token: int,
	state_name: String,
	progress_callback: Callable
) -> PackedScene:
	var resolved: String = _resolve_resource_path(path)

	var err: Error = ResourceLoader.load_threaded_request(resolved)
	if err != OK:
		push_error(
			"[HfsmSceneRegistry] load_threaded_request failed (%s): %s"
			% [error_string(err), resolved]
		)
		if token != int(_tokens.get(state_name, 0)):
			return null
		return load(resolved) as PackedScene

	var progress_state: Array = []
	var status: int = ResourceLoader.THREAD_LOAD_IN_PROGRESS
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if token != int(_tokens.get(state_name, 0)):
			return null
		status = ResourceLoader.load_threaded_get_status(resolved, progress_state)
		if progress_state.size() > 0:
			progress_callback.call(progress_state[0])
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await _host.get_tree().process_frame

	if token != int(_tokens.get(state_name, 0)):
		return null

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(resolved) as PackedScene

	push_warning(
		"[HfsmSceneRegistry] Threaded load status %s for %s; trying sync load"
		% [status, resolved]
	)
	return load(resolved) as PackedScene


func _bump_token(state_name: String) -> int:
	var next: int = int(_tokens.get(state_name, 0)) + 1
	_tokens[state_name] = next
	return next


func _free_loading_screen(state_name: String) -> void:
	var ls = _loading_screens.get(state_name)
	_loading_screens.erase(state_name)
	if ls != null and is_instance_valid(ls):
		ls.queue_free()
