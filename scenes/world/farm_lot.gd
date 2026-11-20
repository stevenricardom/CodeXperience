class_name FarmLot
extends Node3D
## Controlador 3D para cada lote comprable de la granja: cartel "SE VENDE",
## aparición con rebote + partículas al comprarse y animaciones pasivas.

const EconomyScript := preload("res://scripts/game/economy.gd")
const SIGN_SCENE := preload("res://assets/scenes/farm_assets/structures/Bld_Farm_Sign_01.tscn")
const FENCE_PANEL_SCENE := preload("res://assets/scenes/farm_assets/structures/Bld_02_Fence_Wood_01.tscn")
const FENCE_POLE_SCENE := preload("res://assets/scenes/farm_assets/structures/Bld_02_Fence_Wood_Pole_01.tscn")

@export var building_id: String = ""
@export var building_scene: PackedScene
@export var building_scale: Vector3 = Vector3.ONE
@export var fence_field_center: Vector3 = Vector3(6.0, 1.0, 30.0)

var _sign_root: Node3D = null
var _sign_label: Label3D = null
var _sign_label_base_y: float = 1.85
var _building_root: Node3D = null
var _windmill_fan: Node3D = null
var _bob_time: float = 0.0

func _ready() -> void:
	_setup_sale_sign()
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_signal("building_purchased") and not gs.building_purchased.is_connected(_on_building_purchased):
			gs.building_purchased.connect(_on_building_purchased)
		if gs.has_method("is_building_purchased") and gs.is_building_purchased(building_id):
			_set_sign_visible(false)
			_spawn_building(false)
			return
	_set_sign_visible(true)

func _process(delta: float) -> void:
	_bob_time += delta
	if is_instance_valid(_sign_label) and is_instance_valid(_sign_root) and _sign_root.visible:
		_sign_label.position.y = _sign_label_base_y + sin(_bob_time * 2.4) * 0.06
	if is_instance_valid(_windmill_fan) and is_instance_valid(_building_root) and _building_root.visible:
		_windmill_fan.rotate_z(delta * 1.4)

## Reproduce la animación de construcción (escala ~0 -> building_scale) y partículas doradas.
func play_build_animation() -> void:
	if not is_instance_valid(_building_root):
		_spawn_building(true)
	if not is_instance_valid(_building_root):
		return

	_building_root.visible = true
	_building_root.scale = Vector3.ONE * 0.001
	if not is_inside_tree():
		_building_root.scale = building_scale
		return

	var tw := create_tween()
	tw.tween_property(_building_root, "scale", building_scale, 0.65)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_build_particles()

func _on_building_purchased(purchased_id: String) -> void:
	if purchased_id != building_id:
		return
	_set_sign_visible(false)
	if not is_instance_valid(_building_root):
		_spawn_building(true)
	play_build_animation()

func _setup_sale_sign() -> void:
	if is_instance_valid(_sign_root):
		return
	_sign_root = Node3D.new()
	_sign_root.name = "SaleSign"
	add_child(_sign_root)

	if SIGN_SCENE != null:
		var sign_mesh := SIGN_SCENE.instantiate()
		if sign_mesh is Node3D:
			sign_mesh.scale = Vector3(1.15, 1.15, 1.15)
		_sign_root.add_child(sign_mesh)

	var info: Dictionary = EconomyScript.BUILDING_INFO.get(building_id, {})
	var b_name: String = str(info.get("name", building_id.capitalize() if not building_id.is_empty() else "Lote"))
	var b_price: int = int(info.get("price", 0))

	_sign_label = Label3D.new()
	_sign_label.text = "EN VENTA: %s\n%d monedas" % [b_name, b_price]
	_sign_label.position = Vector3(0.0, _sign_label_base_y, 0.0)
	_sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign_label.font_size = 32
	_sign_label.pixel_size = 0.0045
	_sign_label.outline_size = 8
	_sign_label.outline_modulate = Color(0.05, 0.07, 0.10, 1.0)
	_sign_label.modulate = Color(1.0, 0.94, 0.72, 1.0)
	_sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sign_root.add_child(_sign_label)

func _set_sign_visible(is_visible_flag: bool) -> void:
	if not is_instance_valid(_sign_root):
		return
	_sign_root.visible = is_visible_flag
	for col in _sign_root.find_children("*", "CollisionShape3D", true, false):
		if col is CollisionShape3D:
			col.disabled = not is_visible_flag

func _spawn_building(start_hidden_for_anim: bool) -> void:
	if is_instance_valid(_building_root):
		return
	_building_root = Node3D.new()
	_building_root.name = "BuildingInstance"

	if building_id == "fences":
		_building_root.position = to_local(fence_field_center) if is_inside_tree() else Vector3.ZERO
		_build_perimeter_fences(_building_root)
	else:
		var scene_to_spawn := building_scene
		if scene_to_spawn == null and EconomyScript.BUILDING_INFO.has(building_id):
			var scene_path: String = str(EconomyScript.BUILDING_INFO[building_id].get("scene_path", ""))
			if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
				scene_to_spawn = load(scene_path) as PackedScene
		if scene_to_spawn != null:
			var inst := scene_to_spawn.instantiate()
			_building_root.add_child(inst)
			if building_id == "windmill":
				_windmill_fan = inst.find_child("Bld_Windmill_Fan_01", true, false) as Node3D

	add_child(_building_root)
	_building_root.scale = Vector3.ONE * 0.001 if start_hidden_for_anim else building_scale

func _build_perimeter_fences(parent: Node3D) -> void:
	# Rodea por fuera la valla del campo dejando libre la entrada SW del tractor (-11.2 a -4.2 en Z=11.2).
	_add_fence_run(parent, Vector3(-11.2, 0.0, -11.2), Vector3(11.2, 0.0, -11.2), 9, true, true)
	_add_fence_run(parent, Vector3(11.2, 0.0, -11.2), Vector3(11.2, 0.0, 11.2), 9, false, true)
	_add_fence_run(parent, Vector3(-11.2, 0.0, -11.2), Vector3(-11.2, 0.0, 11.2), 9, false, true)
	_add_fence_run(parent, Vector3(-4.2, 0.0, 11.2), Vector3(11.2, 0.0, 11.2), 6, true, false)

func _add_fence_run(
	parent: Node3D,
	start_pt: Vector3,
	end_pt: Vector3,
	segments: int,
	place_start_pole: bool,
	place_end_pole: bool
) -> void:
	var span := end_pt - start_pt
	var total_len := span.length()
	if segments <= 0 or total_len <= 0.01:
		return
	var dir := span / total_len
	var step := total_len / float(segments)
	var yaw := atan2(dir.z, -dir.x)

	for i in range(segments + 1):
		if i == 0 and not place_start_pole:
			continue
		if i == segments and not place_end_pole:
			continue
		var pole := FENCE_POLE_SCENE.instantiate() as Node3D
		pole.position = start_pt.lerp(end_pt, float(i) / float(segments))
		parent.add_child(pole)

	for i in range(segments):
		var pole_pos := start_pt.lerp(end_pt, float(i) / float(segments))
		var holder := Node3D.new()
		holder.position = pole_pos + dir * 0.07
		holder.rotation.y = yaw
		holder.scale.x = maxf(0.1, (step - 0.14) / 2.44)
		var panel := FENCE_PANEL_SCENE.instantiate() as Node3D
		panel.position.x = 0.0
		holder.add_child(panel)
		parent.add_child(holder)

func _spawn_build_particles() -> void:
	if not is_inside_tree():
		return
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 36
	particles.lifetime = 0.9
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 75.0
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 5.5
	particles.gravity = Vector3(0.0, -6.5, 0.0)
	particles.scale_amount_min = 0.14
	particles.scale_amount_max = 0.28
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0 if building_id == "fences" else 1.4

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.28, 1.0))
	grad.set_color(1, Color(0.88, 0.76, 0.58, 0.0))
	particles.color_ramp = grad

	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.25, 1.0)
	mesh.material = mat
	particles.mesh = mesh

	particles.position = _building_root.position + Vector3(0.0, 1.0, 0.0)
	add_child(particles)
	particles.emitting = true

	var cleanup := particles.create_tween()
	cleanup.tween_interval(1.4)
	cleanup.tween_callback(particles.queue_free)
