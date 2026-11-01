extends Control

## Dark neon backdrop (concept/art-direction.md): radial gradient comes from the scene's
## TextureRect; this script only sprinkles faint stars. Decor only, never gameplay.

@export var star_count: int = 60
@export var star_colors: Array[Color] = [Color("#03B8FF"), Color("#FF05AD"), Color("#FFFFFF")]
@export var star_seed: int = 7

var _stars: Array[Dictionary] = []


func _ready() -> void:
	resized.connect(_build_stars)
	_build_stars()


func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed
	_stars.clear()
	for i in star_count:
		var color: Color = star_colors[rng.randi() % star_colors.size()]
		color.a = rng.randf_range(0.15, 0.5)
		_stars.append({
			"pos": Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.8),
			"r": rng.randf_range(0.6, 2.0),
			"color": color,
		})
	queue_redraw()


func _draw() -> void:
	for star in _stars:
		draw_circle(star.pos, star.r, star.color, true, -1.0, true)
