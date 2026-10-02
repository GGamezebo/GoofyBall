class_name BallView
extends Node3D

## Pure view of the ball: pose + alarm blink + explosion FX. No physics here —
## all motion comes from the simulation through `apply_state`.

const PLANE_Z := 0.0
const SHADOW_FLOOR_Y := 0.02

const COLOR_NORMAL := Color(1.0, 0.82, 0.12, 1.0)
const COLOR_ALARM := Color(1.0, 0.08, 0.12, 1.0)
const EMISSION_NORMAL := Color(0.75, 0.35, 0.02, 1.0)
const EMISSION_ALARM := Color(1.0, 0.05, 0.05, 1.0)

var _alarm := false
var _hidden := false
var _body_mat: StandardMaterial3D
var _stripe_mat: StandardMaterial3D

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _stripe: MeshInstance3D = $Stripe
@onready var _stripe2: MeshInstance3D = $Stripe2
@onready var _ground_shadow: MeshInstance3D = $GroundShadow
@onready var _glow: OmniLight3D = $GlowLight
@onready var _sparks: GPUParticles3D = $ExplosionSparks


func _ready() -> void:
	_cache_materials()
	_set_visuals_visible(true)
	if _sparks:
		_sparks.emitting = false
	if _ground_shadow:
		_ground_shadow.top_level = true
		_ground_shadow.transparency = 0.55
	if PerformanceTune.is_constrained():
		if _glow:
			_glow.visible = false
		for m in [_mesh, _stripe]:
			if m:
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if _alarm and not _hidden:
		_update_alarm_visuals()


func apply_state(x: float, y: float, hidden: bool, alarm: bool) -> void:
	global_position = Vector3(x, y, PLANE_Z)
	if hidden != _hidden:
		_hidden = hidden
		_set_visuals_visible(not hidden)
	if alarm != _alarm:
		_alarm = alarm
		if not alarm:
			_apply_ball_color(COLOR_NORMAL, EMISSION_NORMAL, 0.7, 0.85)
			if _glow:
				_glow.light_color = Color(1.0, 0.72, 0.12, 1.0)
				_glow.light_energy = 1.6
	_update_ground_shadow(y)


## Burst of sparks (call once per explosion).
func play_explosion() -> void:
	if _sparks:
		_sparks.restart()
		_sparks.emitting = true


func _update_ground_shadow(y: float) -> void:
	if _ground_shadow == null:
		return
	_ground_shadow.global_position = Vector3(global_position.x, SHADOW_FLOOR_Y, PLANE_Z)
	var t := clampf(1.0 - (y - 0.35) / 6.0, 0.4, 1.0)
	_ground_shadow.scale = Vector3(t, 1.0, t)


func _cache_materials() -> void:
	if _mesh:
		var src := _mesh.get_active_material(0)
		if src is StandardMaterial3D:
			_body_mat = (src as StandardMaterial3D).duplicate()
			_mesh.set_surface_override_material(0, _body_mat)
	if _stripe:
		var src2 := _stripe.get_active_material(0)
		if src2 is StandardMaterial3D:
			_stripe_mat = (src2 as StandardMaterial3D).duplicate()
			_stripe.set_surface_override_material(0, _stripe_mat)
			if _stripe2:
				_stripe2.set_surface_override_material(0, _stripe_mat)


func _update_alarm_visuals() -> void:
	# Fast red blink for the last seconds of the round (wall-clock: cosmetic only).
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.028)
	var albedo := COLOR_NORMAL.lerp(COLOR_ALARM, pulse)
	var emission := EMISSION_NORMAL.lerp(EMISSION_ALARM, pulse)
	_apply_ball_color(albedo, emission, lerpf(0.7, 4.5, pulse), lerpf(0.85, 5.0, pulse))
	if _glow:
		_glow.light_color = Color(1.0, 0.12, 0.08, 1.0).lerp(Color(1.0, 0.75, 0.15, 1.0), 1.0 - pulse)
		_glow.light_energy = lerpf(1.2, 4.0, pulse)


func _apply_ball_color(albedo: Color, emission: Color, body_energy: float, stripe_energy: float) -> void:
	if _body_mat:
		_body_mat.albedo_color = albedo
		_body_mat.emission = emission
		_body_mat.emission_energy_multiplier = body_energy
	if _stripe_mat:
		_stripe_mat.albedo_color = albedo.lightened(0.1)
		_stripe_mat.emission = emission.lightened(0.15)
		_stripe_mat.emission_energy_multiplier = stripe_energy


func _set_visuals_visible(show_visuals: bool) -> void:
	if _mesh:
		_mesh.visible = show_visuals
	if _stripe:
		_stripe.visible = show_visuals
	if _stripe2:
		_stripe2.visible = show_visuals
	if _glow and not PerformanceTune.is_constrained():
		_glow.visible = show_visuals
	if _ground_shadow:
		_ground_shadow.visible = show_visuals
