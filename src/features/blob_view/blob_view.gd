class_name BlobView
extends Node2D

## Jelly blob look (concept/art-direction.md), drawn procedurally: halo, body, light spot,
## outline, highlight drop, eyes that follow the ball, floor shadow. Squash / stretch is
## view-only and keeps the bottom on the floor. Pure function of what `apply()` gets.

@export var name_label: Label
@export var outline_ratio: float = 0.07
@export var halo_alpha: float = 0.14
@export var land_squash_sec: float = 0.18

var color: Color = Color("#03B8FF")
var radius_px: float = 48.0

var _light: GradientTexture2D
var _scale := Vector2.ONE
var _floor_offset: float = 0.0
var _height_px: float = 0.0
var _look := Vector2.ZERO
var _was_on_floor: bool = true
var _land_t: float = 0.0
var _hit_t: float = 0.0


func setup(p_color: Color, p_radius_px: float, display_name: String, is_local: bool) -> void:
	color = p_color
	radius_px = p_radius_px
	_light = _make_light_texture()
	if name_label != null:
		name_label.text = ("ТЫ" if is_local else display_name)
		name_label.add_theme_color_override("font_color", color.lightened(0.35))
		name_label.position = Vector2(-name_label.size.x * 0.5, -radius_px - 64.0)
	queue_redraw()


## `pos` = body center (px), `floor_y` = floor line (px), `look_at` = ball (px).
func apply(pos: Vector2, vy_mps: float, on_floor: bool, floor_y: float, look_at: Vector2, delta: float) -> void:
	position = pos
	_floor_offset = floor_y - pos.y
	_height_px = maxf(0.0, _floor_offset - radius_px)
	if on_floor and not _was_on_floor:
		_land_t = 1.0
	_was_on_floor = on_floor
	_land_t = maxf(0.0, _land_t - delta / land_squash_sec)
	_hit_t = maxf(0.0, _hit_t - delta / 0.15)

	var stretch := 1.0
	if not on_floor:
		stretch = clampf(1.0 + absf(vy_mps) * 0.012, 1.0, 1.18)
	var squash := 1.0 - 0.06 * (1.0 if on_floor else 0.0) - 0.28 * _land_t - 0.12 * _hit_t
	var sy := stretch * squash
	_scale = Vector2(1.0 / sy, sy)
	var to_ball := look_at - pos
	_look = to_ball.normalized() if to_ball.length() > 1.0 else Vector2.ZERO
	queue_redraw()


## Short squash when this blob touches the ball.
func pulse() -> void:
	_hit_t = 1.0


func _draw() -> void:
	var r := radius_px
	_draw_shadow(r)
	# Body space: scale around the bottom point so squash keeps the blob on the floor.
	var body := Transform2D(0.0, _scale, 0.0, Vector2(0.0, r)) * Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0.0, -r))
	draw_set_transform_matrix(body)
	draw_circle(Vector2.ZERO, r * 1.2, Color(color, halo_alpha * 0.6), true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 1.09, Color(color, halo_alpha), true, -1.0, true)
	draw_circle(Vector2.ZERO, r, color, true, -1.0, true)
	if _light != null:
		draw_texture_rect(_light, Rect2(-r, -r, 2.0 * r, 2.0 * r), false)
	var outline_w := r * outline_ratio
	draw_arc(Vector2.ZERO, r - outline_w * 0.5, 0.0, TAU, 64, color.lightened(0.35), outline_w, true)
	_draw_ellipse(body, Vector2(-0.4 * r, -0.5 * r), Vector2(0.22 * r, 0.12 * r), -0.61, Color(1, 1, 1, 0.75))
	draw_circle(Vector2(-0.12 * r, -0.72 * r), 0.05 * r, Color(1, 1, 1, 0.8), true, -1.0, true)
	for side in [-1.0, 1.0]:
		var eye := Vector2(side * 0.3 * r, -0.12 * r)
		_draw_ellipse(body, eye, Vector2(0.17 * r, 0.22 * r), 0.0, Color.WHITE)
		draw_circle(eye + _look * 0.07 * r, 0.09 * r, Color("#0A0F25"), true, -1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_shadow(r: float) -> void:
	var fade := clampf(1.0 - _height_px / (6.0 * r), 0.15, 1.0)
	var center := Vector2(0.0, _floor_offset)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, r * (0.6 + 0.35 * fade), Color(0, 0, 0, 0.5 * fade), true, -1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_ellipse(base: Transform2D, center: Vector2, radii: Vector2, angle: float, fill: Color) -> void:
	draw_set_transform_matrix(base * Transform2D(angle, Vector2(radii.x / radii.y, 1.0), 0.0, center))
	draw_circle(Vector2.ZERO, radii.y, fill, true, -1.0, true)
	draw_set_transform_matrix(base)


func _make_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(color.lightened(0.6), 0.85), Color(color.lightened(0.6), 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.4, 0.35)
	texture.fill_to = Vector2(0.72, 0.35)
	return texture
