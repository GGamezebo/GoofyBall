class_name PerformanceTune
extends RefCounted

## Runtime quality knobs for Web / Android / iOS.


static func is_constrained() -> bool:
	return (
		OS.has_feature("web")
		or OS.has_feature("android")
		or OS.has_feature("ios")
		or OS.has_feature("mobile")
	)


## Call once at boot (main scene).
static func apply_boot(viewport: Viewport) -> void:
	if not is_constrained():
		return
	Engine.max_fps = 60
	if viewport:
		# Lower 3D fill-rate before glow/lighting (big win on phones + WebGL).
		viewport.scaling_3d_scale = 0.7


## Call when the game court is ready.
static func apply_game_scene(root: Node) -> void:
	if not is_constrained() or root == null:
		return

	var world := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		var env := world.environment
		env.glow_enabled = false
		env.fog_enabled = false

	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = false

	var fill := root.get_node_or_null("FillLight") as OmniLight3D
	if fill:
		fill.visible = false

	# Ambient FX are authored heavy; keep them off on constrained targets.
	var smoke := root.get_node_or_null("Court/AmbientSmoke")
	if smoke:
		smoke.visible = false
	var ash := root.get_node_or_null("Court/AmbientAsh")
	if ash:
		ash.visible = false
