extends TestCase

## Every script compiles and every scene instantiates (catches broken paths / exports early).

const ROOTS: Array[String] = ["res://core", "res://src"]


func test_scripts_compile() -> void:
	for path in _files_with(".gd"):
		var script := load(path) as Script
		expect(script != null and script.can_instantiate(), "script loads: %s" % path)


func test_scenes_instantiate() -> void:
	for path in _files_with(".tscn"):
		var packed := load(path) as PackedScene
		expect(packed != null, "scene loads: %s" % path)
		if packed == null:
			continue
		var node := packed.instantiate()
		expect(node != null, "scene instantiates: %s" % path)
		if node != null:
			node.free()


func test_main_scene_and_hfsm_config() -> void:
	expect(load("res://main.tscn") != null, "main scene loads")
	var loaded := HfsmLoader.try_load_tree("res://src/game/hfsm/app_hfsm.json")
	expect(loaded.get("tree") != null, "app HFSM config parses: %s" % str(loaded.get("error", "")))


func _files_with(extension: String) -> Array[String]:
	var out: Array[String] = []
	for root in ROOTS:
		_walk(root, extension, out)
	out.sort()
	return out


func _walk(dir_path: String, extension: String, out: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(extension):
			out.append(dir_path.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir_path):
		_walk(dir_path.path_join(sub), extension, out)
