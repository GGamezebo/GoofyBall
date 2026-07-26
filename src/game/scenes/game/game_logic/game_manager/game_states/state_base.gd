class_name StateBase
extends FSMState

static func get_state() -> String:
	return ""

var game_manager: GameManager
var event_listener := EventListener.new()
var game_config: GameConfig


func _init() -> void:
	super(get_state())


func initialize(_game_manager: GameManager, _game_config: GameConfig) -> void:
	game_manager = _game_manager
	game_config = _game_config


func deinit() -> void:
	event_listener.deinit()
	game_manager = null
