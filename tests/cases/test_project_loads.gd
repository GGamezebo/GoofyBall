extends TestCase

## Every script must parse and every scene must load + instantiate on its own
## (project rule: scenes open in isolation).

const ROOTS: Array[String] = ["res://src", "res://core"]


func test_all_scripts_compile() -> void:
	for path in _collect(ROOTS, ".gd"):
		var script := load(path) as GDScript
		expect(script != null and script.can_instantiate(), "script does not compile: %s" % path)


func test_all_scenes_instantiate() -> void:
	for path in _collect(ROOTS, ".tscn"):
		var packed := load(path) as PackedScene
		expect(packed != null, "scene does not load: %s" % path)
		if packed == null:
			continue
		var inst := packed.instantiate()
		expect(inst != null, "scene does not instantiate: %s" % path)
		if inst:
			inst.free()


func _collect(roots: Array[String], suffix: String) -> Array[String]:
	var out: Array[String] = []
	for root in roots:
		_walk(root, suffix, out)
	out.sort()
	return out


func _walk(dir_path: String, suffix: String, out: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(suffix):
			out.append("%s/%s" % [dir_path, file_name])
	for sub in DirAccess.get_directories_at(dir_path):
		_walk("%s/%s" % [dir_path, sub], suffix, out)
