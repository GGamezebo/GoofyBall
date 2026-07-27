extends Node

## App entry: boots HFSM. Gameplay/UI live in mounted IScene nodes + HFSM states.

@export_file("*.json") var _hfsm_config_path: String = "res://src/game/hfsm/app_hfsm.json"
@export var _scene_paths: HfsmScenePaths
@export var loading_screen_scene: PackedScene
@export var min_load_time: float = 0.0

var _hfsm: HFSM


func _ready() -> void:
	PerformanceTune.apply_boot(get_viewport())
	_hfsm = HFSM.new(
		HfsmLoader.load_tree(_hfsm_config_path),
		{},
		{
			"host": self,
			"paths": _scene_paths.SCENES,
			"loading_screen": loading_screen_scene,
			"min_load_time": min_load_time,
		}
	)


func _exit_tree() -> void:
	if _hfsm:
		_hfsm.clear()
	_hfsm = null


func get_hfsm() -> HFSM:
	return _hfsm
