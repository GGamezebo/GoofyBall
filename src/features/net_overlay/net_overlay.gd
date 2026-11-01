class_name NetOverlay
extends Control

## Debug panel for network checks: F3 (`toggle_net_overlay`) or a three-finger tap.
## Shows the stats dictionary it is fed (ping, rollbacks, ...) plus FPS. In debug builds it
## also offers network emulation presets and the cross-platform determinism probe.

## Emulation preset picked (index into the titles given to `set_lag_presets`).
signal ev_lag_preset_selected(index: int)
signal ev_probe_requested

@export var stats_label: Label
@export var lag_buttons: Array[Button] = []
@export var debug_box: Control
@export var probe_button: Button
@export var probe_label: Label
@export var refresh_sec: float = 0.25

var _stats_source: Callable
var _refresh_left: float = 0.0
var _touches: Dictionary = {}


func _ready() -> void:
	visible = false
	debug_box.visible = OS.is_debug_build()
	for i in lag_buttons.size():
		lag_buttons[i].pressed.connect(func() -> void: ev_lag_preset_selected.emit(i))
	probe_button.pressed.connect(func() -> void: ev_probe_requested.emit())


## One title per emulation preset button; extra buttons are hidden.
func set_lag_presets(titles: Array[String]) -> void:
	for i in lag_buttons.size():
		lag_buttons[i].visible = i < titles.size()
		if i < titles.size():
			lag_buttons[i].text = titles[i]


## `source() -> Dictionary` is polled while the panel is open.
func bind_stats(source: Callable) -> void:
	_stats_source = source


func show_probe_result(result: Dictionary) -> void:
	var ok := bool(result.get("ok", false))
	probe_label.text = "%s хеш %d (эталон %d)" % ["✓ совпал" if ok else "✗ НЕ совпал", int(result.get("hash", 0)), int(result.get("expected", 0))]
	probe_label.add_theme_color_override("font_color", Color("#7CFF4F") if ok else Color("#FF3B3B"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_net_overlay"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = true
			if _touches.size() >= 3:
				visible = not visible
				_touches.clear()
		else:
			_touches.erase(touch.index)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = refresh_sec
	var stats: Dictionary = _stats_source.call() if _stats_source.is_valid() else {}
	stats_label.text = format_stats(stats, Engine.get_frames_per_second())


static func format_stats(stats: Dictionary, fps: float) -> String:
	if stats.is_empty():
		return "Офлайн\nFPS %d" % fps
	var lines: Array[String] = [
		"Ping %d мс  (ср. %d, макс. %d)" % [stats.get("ping_ms", 0), stats.get("ping_avg", 0), stats.get("ping_max", 0)],
		"Задержка ввода %d тик." % stats.get("input_delay", 0),
		"Откаты %.1f/с, макс. %d тик." % [stats.get("rollbacks_per_sec", 0.0), stats.get("max_rollback", 0)],
		"Пропуски тиков %d, потеря синхр. %d" % [stats.get("skipped_ticks", 0), stats.get("sync_lost", 0)],
		"Рассинхроны %d" % stats.get("mismatches", 0),
		"FPS %d" % fps,
	]
	if not str(stats.get("lag", "")).is_empty():
		lines.append("Эмуляция: %s" % stats["lag"])
	return "\n".join(lines)
