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

# Límites del campo (definidos por las esquinas del GridMap)
# X: -6 a 6  |  Z: 11 a 18
const GRID_MIN_X: int = -6
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
	
	global_position = initial_global_position
	global_rotation = initial_global_rotation
	current_grid_pos = initial_grid_pos
	current_dir_index = initial_dir_index
	is_animating = false
	
	print("Tractor inicializado:")
	print("   Casilla: ", current_grid_pos)
	print("   Direccion: ", direction_names[current_dir_index])


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
			if cell_item == GridMap.INVALID_CELL_ITEM:
				error_ocurrido.emit("¡Crash! El tractor llegó al límite del campo.")
				stop()
				return false
			if obstacle_item_id != -1 and cell_item == obstacle_item_id:
				error_ocurrido.emit("¡Crash! El tractor chocó con un obstáculo.")
				stop()
				return false
		else:
			# Estamos fuera: solo permitir moverse si el destino está dentro del campo
			if not target_inside:
				error_ocurrido.emit("El tractor no puede moverse fuera de los límites.")
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
	is_animating = true
	var start_y = global_position.y
	current_tween = create_tween()
	current_tween.tween_property(self, "global_position:y", start_y + 0.15, move_speed * 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "global_position:y", start_y, move_speed * 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await current_tween.finished
	is_animating = false
	
	# Lógica para cambiar la casilla en el GridMap
	if grid_map and grid_map.mesh_library:
		var lib = grid_map.mesh_library
		var target_item_name: String = "crops_wheatStageB3"
		var item_id: int = -1
		
		# DEBUG: Imprimir todos los items disponibles en la MeshLibrary
		print("MeshLibrary: ", lib.resource_path)
		print("Items disponibles:")
		for id in lib.get_item_list():
			var name = lib.get_item_name(id)
			print("   ID ", id, ": '", name, "'")
			if target_item_name in name:
				item_id = id
				
		if item_id != -1:
			var current_orientation: int = grid_map.get_cell_item_orientation(current_grid_pos)
			grid_map.set_cell_item(current_grid_pos, item_id, current_orientation)
			print("Tractor planto '", target_item_name, "' (ID:", item_id, ") en casilla: ", current_grid_pos)
		else:
			print("Advertencia: No se encontro '", target_item_name, "' en la MeshLibrary.")
			print("Advertencia: Revisa los nombres exactos de arriba y corrigelo.")
	else:
		print("Error: grid_map: ", grid_map, " | mesh_library: ", grid_map.mesh_library if grid_map else "null")

# --- ANIMACIONES (TWEENS) ---

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
