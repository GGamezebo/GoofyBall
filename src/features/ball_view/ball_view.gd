class_name BallView
extends Node2D

## Glowing volleyball (concept): yellow halo, light spot, dark rim, two spinning seams,
## a short fading trail and a floor shadow. View-only state (spin, trail) never feeds back.

@export var trail_length: int = 5
@export var trail_spacing_px: float = 14.0

var radius_px: float = 34.0

var _light: GradientTexture2D
var _spin: float = 0.0
var _trail: Array[Vector2] = []
var _floor_offset: float = 0.0
var _height_px: float = 0.0
var _frozen: bool = true


func setup(p_radius_px: float) -> void:
	radius_px = p_radius_px
	_light = _make_light_texture()
	_trail.clear()
	queue_redraw()


func apply(pos: Vector2, vx_mps: float, frozen: bool, floor_y: float, px_per_m: float, delta: float) -> void:
	if not frozen and (_trail.is_empty() or _trail.back().distance_to(pos) >= trail_spacing_px):
		_trail.append(pos)
		while _trail.size() > trail_length:
			_trail.pop_front()
	if frozen:
		_trail.clear()
	_frozen = frozen
	position = pos
	_floor_offset = floor_y - pos.y
	_height_px = maxf(0.0, _floor_offset - radius_px)
	_spin += vx_mps * px_per_m * delta / maxf(radius_px, 1.0)
	queue_redraw()


func _draw() -> void:
	var r := radius_px
	var fade := clampf(1.0 - _height_px / (10.0 * r), 0.1, 1.0)
	draw_set_transform(Vector2(0.0, _floor_offset), 0.0, Vector2(1.0, 0.2))
	draw_circle(Vector2.ZERO, r * (0.5 + 0.5 * fade), Color(0, 0, 0, 0.45 * fade), true, -1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	for i in _trail.size():
		var t := float(i + 1) / float(_trail.size() + 1)
		draw_circle(_trail[i] - position, r * (0.35 + 0.45 * t), Color(1.0, 0.82, 0.04, 0.18 * t), true, -1.0, true)

	draw_circle(Vector2.ZERO, r * 1.45, Color(1.0, 0.82, 0.04, 0.07), true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 1.2, Color(1.0, 0.82, 0.04, 0.14), true, -1.0, true)
	draw_circle(Vector2.ZERO, r, Color("#FFD20A"), true, -1.0, true)
	if _light != null:
		draw_texture_rect(_light, Rect2(-r, -r, 2.0 * r, 2.0 * r), false)
	var seam := Color("#B07B00", 0.6)
	var seam_w := r * 0.08
	for k in 2:
		var angle := _spin + PI * float(k)
		var offset := Vector2(cos(angle), sin(angle)) * r * 0.9
		draw_arc(offset, r * 0.75, angle + PI - 0.9, angle + PI + 0.9, 16, seam, seam_w, true)
	draw_arc(Vector2.ZERO, r - r * 0.06, 0.0, TAU, 48, Color("#C98F00"), r * 0.12, true)


func _make_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color("#FFF6C2", 0.95), Color("#FFF6C2", 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.38, 0.33)
	texture.fill_to = Vector2(0.72, 0.33)
	return texture
