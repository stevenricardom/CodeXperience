extends Node3D
## Mano estilizada original (geometría procedural local, sin assets externos).
## Silueta blanda tipo cartoon: palma redondeada, pulgar unido y cuatro dedos
## articulados en tres segmentos. Material mate. La mano izquierda se construye
## espejada (X invertido) para que el pulgar quede en el lado correcto.

const POSE_IDLE := "idle"
const POSE_POINT := "point"
const POSE_GRAB := "grab"

@export var handedness: int = 1  ## 1 = derecha, -1 = izquierda
@export var skin_color: Color = Color(0.93, 0.78, 0.68)
@export var cuff_color: Color = Color(0.15, 0.18, 0.27)
@export var pose_speed: float = 12.0

var _pose: String = POSE_IDLE
var _joints: Array[Node3D] = []
var _angles: Array[float] = []
var _targets: Array[float] = []
var _pose_angles: Dictionary = {}
var _thumb_base: Node3D
var _skin: StandardMaterial3D
var _cuff: StandardMaterial3D

func _ready() -> void:
	_build_materials()
	_build_geometry()
	_collect_pose_angles()
	_apply_target()

func _build_materials() -> void:
	_skin = StandardMaterial3D.new()
	_skin.albedo_color = skin_color
	_skin.roughness = 0.92
	_skin.metallic = 0.0
	_skin.metallic_specular = 0.15
	_cuff = StandardMaterial3D.new()
	_cuff.albedo_color = cuff_color
	_cuff.roughness = 0.85
	_cuff.metallic = 0.0
	_cuff.metallic_specular = 0.2

func _build_geometry() -> void:
	var s: float = 1.0 if handedness >= 0 else -1.0

	# Muñeca / puño: cilindro redondeado con material mate.
	var cuff_mesh := CylinderMesh.new()
	cuff_mesh.top_radius = 0.046
	cuff_mesh.bottom_radius = 0.050
	cuff_mesh.height = 0.050
	cuff_mesh.radial_segments = 16
	cuff_mesh.rings = 1
	var cuff := MeshInstance3D.new()
	cuff.name = "Cuff"
	cuff.mesh = cuff_mesh
	cuff.material_override = _cuff
	cuff.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	cuff.position = Vector3(0.0, 0.0, 0.024)
	add_child(cuff)

	# Palma: esfera achatada, bordes suaves.
	var palm_mesh := SphereMesh.new()
	palm_mesh.radius = 0.045
	palm_mesh.height = 0.090
	palm_mesh.radial_segments = 20
	palm_mesh.rings = 12
	var palm := MeshInstance3D.new()
	palm.name = "Palm"
	palm.mesh = palm_mesh
	palm.material_override = _skin
	palm.scale = Vector3(1.0, 0.52, 1.05)
	palm.position = Vector3(0.0, 0.0, -0.045)
	add_child(palm)

	# Cuatro dedos con tres segmentos articulados.
	for finger in FINGERS:
		var x: float = float(finger["x"]) * s
		var lengths: Array = finger["lengths"]
		var radii: Array = finger["radii"]
		var parent: Node3D = self
		var z: float = -0.072
		# Nudillo: une el dedo con la palma para que no parezcan piezas sueltas.
		var knuckle := MeshInstance3D.new()
		knuckle.name = "Knuckle"
		var knuckle_mesh := SphereMesh.new()
		knuckle_mesh.radius = float(radii[0]) * 1.25
		knuckle_mesh.height = knuckle_mesh.radius * 2.0
		knuckle_mesh.radial_segments = 12
		knuckle_mesh.rings = 8
		knuckle.mesh = knuckle_mesh
		knuckle.material_override = _skin
		knuckle.position = Vector3(x, -0.002, z + 0.006)
		add_child(knuckle)
		for index in lengths.size():
			var joint := Node3D.new()
			joint.name = "%s_%d" % [finger["name"], index]
			joint.position = Vector3(x, -0.004, z) if index == 0 else Vector3(0.0, 0.0, -lengths[index - 1])
			parent.add_child(joint)
			var capsule := CapsuleMesh.new()
			capsule.radius = float(radii[index])
			capsule.height = maxf(float(lengths[index]), float(radii[index]) * 2.0 + 0.002)
			capsule.radial_segments = 12
			capsule.rings = 4
			var segment := MeshInstance3D.new()
			segment.name = "Segment"
			segment.mesh = capsule
			segment.material_override = _skin
			segment.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			segment.position = Vector3(0.0, 0.0, -float(lengths[index]) * 0.5)
			joint.add_child(segment)
			_joints.append(joint)
			parent = joint

	# Pulgar unido a la palma, dos segmentos.
	_thumb_base = Node3D.new()
	_thumb_base.name = "Thumb"
	_thumb_base.position = Vector3(-0.042 * s, -0.008, -0.024)
	_thumb_base.rotation = Vector3(0.0, deg_to_rad(50.0) * s, 0.0)
	add_child(_thumb_base)
	var thumb_parent: Node3D = _thumb_base
	var thumb_lengths: Array = [0.026, 0.022]
	var thumb_radii: Array = [0.0132, 0.0116]
	for index in thumb_lengths.size():
		var joint := Node3D.new()
		joint.name = "Thumb_%d" % index
		joint.position = Vector3(0.0, 0.0, 0.0) if index == 0 else Vector3(0.0, 0.0, -thumb_lengths[index - 1])
		thumb_parent.add_child(joint)
		var capsule := CapsuleMesh.new()
		capsule.radius = float(thumb_radii[index])
		capsule.height = maxf(float(thumb_lengths[index]), float(thumb_radii[index]) * 2.0 + 0.002)
		capsule.radial_segments = 12
		capsule.rings = 4
		var segment := MeshInstance3D.new()
		segment.name = "Segment"
		segment.mesh = capsule
		segment.material_override = _skin
		segment.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		segment.position = Vector3(0.0, 0.0, -float(thumb_lengths[index]) * 0.5)
		joint.add_child(segment)
		_joints.append(joint)
		thumb_parent = joint

func _collect_pose_angles() -> void:
	var idle: Array[float] = []
	var point: Array[float] = []
	var grab: Array[float] = []
	for finger in FINGERS:
		var curls: Array = finger["idle"]
		for value in curls:
			idle.append(float(value))
		for value in finger["point"]:
			point.append(float(value))
		for value in finger["grab"]:
			grab.append(float(value))
	for value in THUMB_IDLE:
		idle.append(float(value))
	for value in THUMB_POINT:
		point.append(float(value))
	for value in THUMB_GRAB:
		grab.append(float(value))
	_pose_angles = {POSE_IDLE: idle, POSE_POINT: point, POSE_GRAB: grab}

func _apply_target() -> void:
	var values: Array = _pose_angles.get(_pose, [])
	_targets.clear()
	for index in _joints.size():
		_targets.append(float(values[index]) if index < values.size() else 0.0)

## Aplica una pose y avanza la interpolación de los dedos.
## delta <= 0 deja los dedos en el ángulo objetivo (usado al inicializar).
func set_pose(pose: String, delta: float = -1.0) -> void:
	if not _pose_angles.has(pose):
		return
	_pose = pose
	_apply_target()
	if delta >= 0.0:
		advance(delta)

func get_pose() -> String:
	return _pose

func get_joint_count() -> int:
	return _joints.size()

func get_thumb_local_position() -> Vector3:
	return _thumb_base.position if _thumb_base != null else Vector3.ZERO

func get_joint_angle(index: int) -> float:
	if index < 0 or index >= _angles.size():
		return 0.0
	return _angles[index]

## Avanza la interpolación de los dedos hacia la pose actual.
## Los dedos se curvan hacia la palma (-Y local), así que el ángulo se aplica
## en negativo sobre el eje X de cada articulación.
func advance(delta: float) -> void:
	if _joints.is_empty():
		return
	var alpha: float = 1.0 - exp(-pose_speed * delta)
	_angles.resize(_joints.size())
	for index in _joints.size():
		_angles[index] = lerpf(_angles[index], _targets[index], alpha)
		_joints[index].rotation.x = -_angles[index]

var FINGERS: Array = [
	{
		"name": "Index", "x": -0.026,
		"lengths": [0.030, 0.024, 0.019], "radii": [0.0094, 0.0086, 0.0078],
		"idle": [0.20, 0.28, 0.22], "point": [0.02, 0.05, 0.03], "grab": [1.05, 1.15, 0.85],
	},
	{
		"name": "Middle", "x": -0.009,
		"lengths": [0.034, 0.026, 0.020], "radii": [0.0098, 0.0088, 0.0079],
		"idle": [0.22, 0.30, 0.24], "point": [0.85, 0.95, 0.65], "grab": [1.10, 1.20, 0.90],
	},
	{
		"name": "Ring", "x": 0.008,
		"lengths": [0.030, 0.024, 0.019], "radii": [0.0092, 0.0083, 0.0075],
		"idle": [0.26, 0.34, 0.28], "point": [0.95, 1.05, 0.70], "grab": [1.10, 1.20, 0.90],
	},
	{
		"name": "Little", "x": 0.024,
		"lengths": [0.024, 0.020, 0.016], "radii": [0.0083, 0.0076, 0.0070],
		"idle": [0.30, 0.38, 0.30], "point": [1.05, 1.15, 0.75], "grab": [1.10, 1.20, 0.90],
	},
]

var THUMB_IDLE: Array = [0.18, 0.14]
var THUMB_POINT: Array = [0.30, 0.20]
var THUMB_GRAB: Array = [0.75, 0.85]
