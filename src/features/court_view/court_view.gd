class_name CourtView
extends Node2D

## Court lines (concept): dark floor strip with a cyan neon edge, faint walls and ceiling,
## glowing nets with a white cap. A zone flashes in the scoring team color after a point.

@export var line_color: Color = Color("#03B8FF")
@export var floor_color: Color = Color("#1A2340")
@export var net_color: Color = Color("#9AE2FF")
@export var flash_sec: float = 0.6

## Court rectangle in px: x from left wall to right wall, y from ceiling to floor.
var court := Rect2(60, 120, 1480, 640)
## Each net: {"x": px, "top": px, "w": px}.
var nets: Array[Dictionary] = []
## Each zone: {"x_min": px, "x_max": px}.
var zones: Array[Dictionary] = []

var _flash_zone: int = -1
var _flash_color := Color.WHITE
var _flash_t: float = 0.0


func setup(p_court: Rect2, p_nets: Array[Dictionary], p_zones: Array[Dictionary]) -> void:
	court = p_court
	nets = p_nets
	zones = p_zones
	queue_redraw()


func flash_zone(zone: int, color: Color) -> void:
	_flash_zone = zone
	_flash_color = color
	_flash_t = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta / flash_sec)
		queue_redraw()


func _draw() -> void:
	var floor_y := court.end.y
	if _flash_t > 0.0 and _flash_zone >= 0 and _flash_zone < zones.size():
		var zone: Dictionary = zones[_flash_zone]
		var rect := Rect2(float(zone["x_min"]), court.position.y, float(zone["x_max"]) - float(zone["x_min"]), court.size.y)
		draw_rect(rect, Color(_flash_color, 0.12 * _flash_t))

	var walls := PackedVector2Array([
		Vector2(court.position.x, floor_y), court.position,
		Vector2(court.end.x, court.position.y), Vector2(court.end.x, floor_y),
	])
	draw_polyline(walls, Color(line_color, 0.25), 2.0, true)

	draw_rect(Rect2(court.position.x - 24.0, floor_y, court.size.x + 48.0, 14.0), floor_color)
	draw_line(Vector2(court.position.x - 24.0, floor_y), Vector2(court.end.x + 24.0, floor_y), Color(line_color, 0.18), 14.0, true)
	draw_line(Vector2(court.position.x - 24.0, floor_y), Vector2(court.end.x + 24.0, floor_y), Color(line_color, 0.9), 4.0, true)

	for net in nets:
		var x := float(net["x"])
		var top := float(net["top"])
		var w := maxf(float(net["w"]), 6.0)
		draw_rect(Rect2(x - w * 1.5, top, w * 3.0, floor_y - top), Color(net_color, 0.12))
		draw_rect(Rect2(x - w * 0.5, top, w, floor_y - top), net_color)
		draw_circle(Vector2(x, top), 14.0, Color(1, 1, 1, 0.18), true, -1.0, true)
		draw_circle(Vector2(x, top), 8.0, Color.WHITE, true, -1.0, true)
