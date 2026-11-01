class_name LocalSession
extends MatchSession

## Offline play (vs AI, two players on one PC): one sim step per physics tick (60 Hz),
## every slot sampled locally.

var _running: bool = false
var _paused: bool = false


func _ready() -> void:
	set_physics_process(false)


func start() -> void:
	_running = true
	set_physics_process(true)
	ev_started.emit()


func shutdown() -> void:
	_running = false
	set_physics_process(false)


func set_paused(paused: bool) -> void:
	_paused = paused


func _physics_process(_delta: float) -> void:
	if not _running or _paused:
		return
	var inputs: Array = []
	for slot in _slot_count:
		inputs.append(_sample.call(slot))
	var tick: int = _step.call(inputs)
	ev_ticked.emit(tick)
