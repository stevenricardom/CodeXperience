@tool
extends Node3D
## Plataformas existentes con sus colisiones; la rampa tiene un único sólido.
const TILE = preload("res://assets/scenes/platforms_assets/platform.tscn")

func _ready() -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.31, 0.23, 0.16)
	timber.roughness = 0.9
	for x in range(5):
		for z in range(4):
			var tile: Node3D = TILE.instantiate()
			tile.position = Vector3(-3 + x * 2, 2.06, 45 + z * 2)
			tile.scale = Vector3.ONE * 2.0
			add_child(tile)
	# Rampa de pendiente 1:4, transitable sin saltar.
	var ramp := _solid("AccessRamp", Vector3(6.185, 0.18, 3), Vector3(9, 1.60723, 45.5), timber)
	ramp.rotation.z = -atan(0.25)
	_solid("Landing", Vector3(4, 0.2, 3), Vector3(14, 0.85, 45.5), timber)
	# Barandas bajas: el frente queda despejado y la entrada oriental libre.
	_solid("RearRail", Vector3(10, 0.12, 0.12), Vector3(1, 3.25, 51.9), timber)
	_solid("WestRail", Vector3(0.12, 0.12, 8), Vector3(-3.9, 3.25, 48), timber)
	for point in [Vector3(-3.9, 2.85, 44.1), Vector3(-3.9, 2.85, 51.9), Vector3(5.9, 2.85, 51.9)]:
		_solid("Post", Vector3(0.14, 0.8, 0.14), point, timber)

func _solid(label: String, dimensions: Vector3, at: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body
