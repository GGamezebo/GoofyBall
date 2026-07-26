class_name HfsmScenePaths
extends Node

@export_category("Scenes")
@export_file("*.tscn") var app_root: String = "res://src/game/scenes/app_root/root.tscn"
@export_file("*.tscn") var menu: String = "res://src/game/scenes/menu/menu.tscn"
@export_file("*.tscn") var game: String = "res://src/game/scenes/game/game.tscn"
@export_file("*.tscn") var post_battle: String = "res://src/game/scenes/post_battle/post_battle.tscn"

var SCENES: Dictionary = {}


func _ready() -> void:
	SCENES = _get_exports_in_category("Scenes")


func _get_exports_in_category(category_name: String) -> Dictionary:
	var result := {}
	var in_category := false
	for prop in get_property_list():
		var usage: int = prop.usage
		if usage & PROPERTY_USAGE_CATEGORY:
			in_category = (str(prop.name) == category_name)
			continue
		if in_category and (usage & PROPERTY_USAGE_EDITOR) and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			result[prop.name] = get(prop.name)
	return result
