class_name BlobView
extends Node3D

## Pure view of a blob: the simulation owns all motion and rules, this node only
## shows a pose (`apply_state`) and plays cosmetic FX. Safe to call every frame.

@export var player_index: int = 0
@export var blob_color: Color = Color.CORNFLOWER_BLUE

const PLANE_Z := 0.0
const SHADOW_FLOOR_Y := 0.02

@onready var mesh_root: Node3D = $MeshRoot
@onready var _ground_shadow: MeshInstance3D = $GroundShadow
@onready var _glow: OmniLight3D = $GlowLight
@onready var _sparks: GPUParticles3D = $ExplosionSparks
@onready var _blast_flash: OmniLight3D = $BlastFlash

var _dead: bool = false
var _prev_vy: float = 0.0
var _squash: float = 1.0
var _stretch: float = 1.0


func _ready() -> void:
	_apply_color()
	if _ground_shadow:
		_ground_shadow.top_level = true
		_ground_shadow.transparency = 0.55
	if _sparks:
		_sparks.emitting = false
	if _blast_flash:
		_blast_flash.visible = false
	if PerformanceTune.is_constrained():
		if _glow:
			_glow.visible = false
		if mesh_root:
			for child in mesh_root.get_children():
				if child is MeshInstance3D:
					(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_squash = lerpf(_squash, 1.0, minf(1.0, delta * 14.0))
	_stretch = lerpf(_stretch, 1.0, minf(1.0, delta * 14.0))
	if mesh_root and not _dead:
		mesh_root.scale = Vector3(_stretch, _squash, _stretch)


## `vy` is only used to derive jump / landing squash (cosmetic).
func apply_state(x: float, y: float, vy: float, dead: bool) -> void:
	global_position = Vector3(x, y, PLANE_Z)
	if dead != _dead:
		_set_dead(dead)
	if not dead:
		if _prev_vy <= 0.0 and vy > 1.0:
			_squash = 1.25
			_stretch = 0.78
		elif _prev_vy < -2.0 and vy >= 0.0:
			_squash = 0.62
			_stretch = 1.32
	_prev_vy = vy
	_update_ground_shadow(y)


## Ball bounced off this blob.
func play_hit() -> void:
	_squash = 0.7
	_stretch = 1.25


## Last-chance self-destruct FX (sparks + flash).
func play_blast() -> void:
	if _sparks:
		_tint_sparks()
		_sparks.restart()
		_sparks.emitting = true
	if _blast_flash:
		_blast_flash.light_color = blob_color.lightened(0.35)
		_blast_flash.visible = true
		_blast_flash.light_energy = 8.0
		var tw := create_tween()
		tw.tween_property(_blast_flash, "light_energy", 0.0, 0.45)
		tw.tween_callback(func() -> void:
			if is_instance_valid(_blast_flash):
				_blast_flash.visible = false
		)


func _set_dead(dead: bool) -> void:
	_dead = dead
	if mesh_root:
		mesh_root.visible = not dead
	if _ground_shadow:
		_ground_shadow.visible = not dead
	if _glow and not PerformanceTune.is_constrained():
		_glow.visible = not dead
	if not dead:
		_squash = 1.0
		_stretch = 1.0
		if mesh_root:
			mesh_root.scale = Vector3.ONE
		if _sparks:
			_sparks.emitting = false
		if _blast_flash:
			_blast_flash.visible = false
			_blast_flash.light_energy = 0.0


func _update_ground_shadow(y: float) -> void:
	if _ground_shadow == null or _dead:
		return
	_ground_shadow.global_position = Vector3(global_position.x, SHADOW_FLOOR_Y, PLANE_Z)
	var t := clampf(1.0 - (y - 0.42) / 5.5, 0.45, 1.0)
	_ground_shadow.scale = Vector3(t, 1.0, t)


func _tint_sparks() -> void:
	if _sparks == null:
		return
	var proc := _sparks.process_material
	if proc is ParticleProcessMaterial:
		var colored: ParticleProcessMaterial = (proc as ParticleProcessMaterial).duplicate()
		colored.color = blob_color.lightened(0.25)
		_sparks.process_material = colored
	var pass_mesh := _sparks.draw_pass_1
	if pass_mesh is SphereMesh:
		var sm := (pass_mesh as SphereMesh).duplicate() as SphereMesh
		var src := sm.material
		if src is StandardMaterial3D:
			var mat: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			mat.albedo_color = blob_color.lightened(0.3)
			mat.emission_enabled = true
			mat.emission = blob_color
			mat.emission_energy_multiplier = 4.0
			sm.material = mat
		_sparks.draw_pass_1 = sm


func _apply_color() -> void:
	if mesh_root == null:
		return
	var body := mesh_root.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var mat := body.get_active_material(0)
	if mat is StandardMaterial3D:
		var colored: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
		colored.albedo_color = blob_color
		colored.emission_enabled = true
		colored.emission = blob_color.darkened(0.35)
		colored.emission_energy_multiplier = 0.55
		body.set_surface_override_material(0, colored)

	if _glow:
		_glow.light_color = blob_color
