extends CharacterBody3D

@export var grid_map: GridMap
@export var move_speed: float = 0.2
@export var check_grid_bounds: bool = true

var current_grid_pos: Vector3i
var current_dir_index: int = 0
var is_animating: bool = false
var stop_requested: bool = false
var current_tween: Tween = null

var initial_global_position: Vector3
var initial_global_rotation: Vector3
var initial_grid_pos: Vector3i
var initial_dir_index: int

var obstacle_item_id: int = -1
var planted_cells: Array[Vector3i] = []
var _cached_wheat_item_id: int = -2

# Límites del campo (definidos por las esquinas del GridMap)
# X: -1 a 6  |  Z: 11 a 18
const GRID_MIN_X: int = -1
const GRID_MAX_X: int = 6
const GRID_MIN_Z: int = 11
const GRID_MAX_Z: int = 18

# Vectores de dirección en el espacio 3D (Norte, Este, Sur, Oeste) -> (-Z, +X, +Z, -X)
var directions = [
	Vector3i(0, 0, -1), # 0: Hacia -Z (Norte / Adelante)
	Vector3i(1, 0, 0),  # 1: Hacia +X (Este / Derecha)
	Vector3i(0, 0, 1),  # 2: Hacia +Z (Sur / Atrás)
	Vector3i(-1, 0, 0)  # 3: Hacia -X (Oeste / Izquierda)
]

var direction_names = ["Norte (-Z)", "Este (+X)", "Sur (+Z)", "Oeste (-X)"]

signal action_completed(success: bool)
signal error_ocurrido(mensaje: String)
signal cell_planted(grid_pos: Vector3i)

func _ready() -> void:
	if grid_map:
		_snap_to_grid()
	else:
		print("ADVERTENCIA: El Tractor no tiene un GridMap asignado en el Inspector.")

# Ajusta el tractor al centro de la casilla más cercana al iniciar
func _snap_to_grid() -> void:
	var local_to_grid = grid_map.to_local(global_position)
	current_grid_pos = grid_map.local_to_map(local_to_grid)
	
	# Mover visualmente al centro exacto X, Z de la casilla
	var exact_local = grid_map.map_to_local(current_grid_pos)
	var exact_global = grid_map.to_global(exact_local)
	
	global_position.x = exact_global.x
	global_position.z = exact_global.z
	
	# Deduce hacia dónde mira el tractor basado en su rotación inicial
	var forward_vec = -global_transform.basis.z.normalized()
	var best_match: int = 0
	var best_dot: float = -2.0
	for i in range(directions.size()):
		var dot = forward_vec.dot(Vector3(directions[i]))
		if dot > best_dot:
			best_dot = dot
			best_match = i
	current_dir_index = best_match
	
	initial_global_position = global_position
	initial_global_rotation = global_rotation
	initial_grid_pos = current_grid_pos
	initial_dir_index = current_dir_index

func reset_state() -> void:
	stop_requested = true
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	_clear_crash_flash()
	
	global_position = initial_global_position
	global_rotation = initial_global_rotation
	current_grid_pos = initial_grid_pos
	current_dir_index = initial_dir_index
	planted_cells.clear()
	is_animating = false
	
	print("Tractor inicializado:")
	print("   Casilla: ", current_grid_pos)
	print("   Direccion: ", direction_names[current_dir_index])

func has_planted_all(required_cells: Array[Vector3i]) -> bool:
	for cell in required_cells:
		if cell not in planted_cells:
			return false
	return true

# Verifica si una casilla está dentro de los límites del campo
func _is_within_bounds(pos: Vector3i) -> bool:
	return pos.x >= GRID_MIN_X and pos.x <= GRID_MAX_X and pos.z >= GRID_MIN_Z and pos.z <= GRID_MAX_Z

# Detiene cualquier ejecución en curso
func stop() -> void:
	stop_requested = true
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	is_animating = false

# --- COMANDOS DEL TRACTOR (ASINCRÓNICOS) ---

func avanzar() -> bool:
	if stop_requested or not grid_map:
		return false
		
	var dir = directions[current_dir_index]
	var target_pos = current_grid_pos + dir
	
	# Validación de límites del campo
	if check_grid_bounds:
		# Si el tractor está FUERA del campo, permitir moverse hacia DENTRO
		var currently_outside = not _is_within_bounds(current_grid_pos)
		var target_inside = _is_within_bounds(target_pos)
		
		if not currently_outside:
			# Estamos dentro: solo permitir moverse a casillas válidas del GridMap
			var cell_item = grid_map.get_cell_item(target_pos)
			if not target_inside or cell_item == GridMap.INVALID_CELL_ITEM:
				await _play_crash_feedback()
				error_ocurrido.emit("¡Crash! El tractor llegó al límite del campo.")
				stop()
				return false
			if obstacle_item_id != -1 and cell_item == obstacle_item_id:
				await _play_crash_feedback()
				error_ocurrido.emit("¡Crash! El tractor chocó con un obstáculo.")
				stop()
				return false
		else:
			# Estamos fuera: solo permitir moverse si el destino está dentro del campo y libre
			if not target_inside:
				await _play_crash_feedback()
				error_ocurrido.emit("El tractor no puede moverse fuera de los límites.")
				stop()
				return false
			if obstacle_item_id != -1 and grid_map.get_cell_item(target_pos) == obstacle_item_id:
				await _play_crash_feedback()
				error_ocurrido.emit("¡Crash! El tractor chocó con un obstáculo.")
				stop()
				return false
	
	current_grid_pos = target_pos
	await _animate_movement()
	print("Tractor movido a casilla: ", current_grid_pos)
	return true

func girar_derecha() -> void:
	if stop_requested: return
	current_dir_index = (current_dir_index + 1) % 4
	await _animate_rotation(-PI / 2)
	print("Tractor giro a: ", direction_names[current_dir_index])

func girar_izquierda() -> void:
	if stop_requested: return
	current_dir_index = (current_dir_index - 1 + 4) % 4
	await _animate_rotation(PI / 2)
	print("Tractor giro a: ", direction_names[current_dir_index])

func interactuar() -> void:
	if stop_requested: return
	if is_inside_tree():
		is_animating = true
		var start_y = global_position.y
		current_tween = create_tween()
		current_tween.tween_property(self, "global_position:y", start_y + 0.15, move_speed * 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		current_tween.tween_property(self, "global_position:y", start_y, move_speed * 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await current_tween.finished
		is_animating = false
		if stop_requested:
			return

	if current_grid_pos not in planted_cells:
		planted_cells.append(current_grid_pos)
		cell_planted.emit(current_grid_pos)

	if is_inside_tree():
		_spawn_burst_particles(
			global_position + Vector3(0.0, 0.35, 0.0),
			Color(0.95, 0.85, 0.25, 1.0),
			Color(0.25, 0.88, 0.35, 0.0),
			28
		)

	# Lógica para cambiar la casilla en el GridMap
	if grid_map and grid_map.mesh_library and (not check_grid_bounds or _is_within_bounds(current_grid_pos)):
		var item_id: int = _get_wheat_item_id()
		if item_id != -1:
			var current_orientation: int = grid_map.get_cell_item_orientation(current_grid_pos)
			grid_map.set_cell_item(current_grid_pos, item_id, current_orientation)
			print("Tractor planto 'crops_wheatStageB3' (ID:", item_id, ") en casilla: ", current_grid_pos)
		else:
			print("Advertencia: No se encontro 'crops_wheatStageB3' en la MeshLibrary.")
	elif not grid_map or not grid_map.mesh_library:
		print("Error: grid_map: ", grid_map, " | mesh_library: ", grid_map.mesh_library if grid_map else "null")

# --- ANIMACIONES Y EFECTOS (TWEENS / PARTICULAS) ---

func _get_wheat_item_id() -> int:
	if _cached_wheat_item_id != -2:
		return _cached_wheat_item_id
	_cached_wheat_item_id = -1
	if grid_map and grid_map.mesh_library:
		var lib := grid_map.mesh_library
		for id in lib.get_item_list():
			if "crops_wheatStageB3" in lib.get_item_name(id):
				_cached_wheat_item_id = id
				break
	return _cached_wheat_item_id

func _get_tractor_mesh() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null

func _clear_crash_flash() -> void:
	var mesh_node := _get_tractor_mesh()
	if mesh_node:
		mesh_node.material_overlay = null

func _play_crash_feedback() -> void:
	if not is_inside_tree():
		return
	is_animating = true
	var origin_pos := global_position
	var mesh_node := _get_tractor_mesh()
	var overlay_mat := StandardMaterial3D.new()
	overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_mat.albedo_color = Color(1.0, 0.15, 0.12, 0.65)
	if mesh_node:
		mesh_node.material_overlay = overlay_mat

	var forward_world := Vector3(directions[current_dir_index]) * 0.45
	_spawn_burst_particles(
		origin_pos + Vector3(0.0, 0.45, 0.0) + forward_world,
		Color(1.0, 0.25, 0.15, 1.0),
		Color(0.45, 0.35, 0.25, 0.0),
		20
	)

	var flash_tween := create_tween()
	flash_tween.tween_property(overlay_mat, "albedo_color:a", 0.0, 0.18)

	var shake_tween := create_tween()
	var shake_a := Vector3(0.09, 0.0, 0.05)
	var shake_b := Vector3(-0.09, 0.0, -0.05)
	shake_tween.tween_property(self, "global_position", origin_pos + shake_a, 0.04)
	shake_tween.tween_property(self, "global_position", origin_pos + shake_b, 0.04)
	shake_tween.tween_property(self, "global_position", origin_pos + shake_a * 0.5, 0.04)
	shake_tween.tween_property(self, "global_position", origin_pos, 0.04)
	await shake_tween.finished

	if not stop_requested:
		global_position = origin_pos
	_clear_crash_flash()
	is_animating = false

func _spawn_burst_particles(world_pos: Vector3, start_color: Color, end_color: Color, count: int) -> void:
	if not is_inside_tree():
		return
	var particles := CPUParticles3D.new()
	particles.top_level = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = 0.65
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 65.0
	particles.initial_velocity_min = 1.8
	particles.initial_velocity_max = 3.6
	particles.gravity = Vector3(0.0, -6.5, 0.0)
	particles.scale_amount_min = 0.09
	particles.scale_amount_max = 0.18

	var grad := Gradient.new()
	grad.set_color(0, start_color)
	grad.set_color(1, end_color)
	particles.color_ramp = grad

	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(start_color.r, start_color.g, start_color.b, 1.0) * 0.5
	mesh.material = mat
	particles.mesh = mesh

	add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true

	var cleanup := particles.create_tween()
	cleanup.tween_interval(1.0)
	cleanup.tween_callback(particles.queue_free)

func _animate_movement() -> void:
	is_animating = true
	var target_local = grid_map.map_to_local(current_grid_pos)
	var target_global = grid_map.to_global(target_local)
	target_global.y = global_position.y
	
	current_tween = create_tween()
	current_tween.tween_property(self, "global_position", target_global, move_speed)\
		 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await current_tween.finished
	is_animating = false

func _animate_rotation(angle_offset: float) -> void:
	is_animating = true
	var target_rotation = rotation
	target_rotation.y += angle_offset
	
	current_tween = create_tween()
	current_tween.tween_property(self, "rotation", target_rotation, move_speed * 0.8)\
		 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await current_tween.finished
	is_animating = false
