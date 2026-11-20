extends Node
class_name AILevelManager

const LevelValidatorScript := preload("res://scripts/game/level_validator.gd")

signal level_loaded(message: String)
signal level_configured(level_data: Dictionary)
signal ai_error(message: String)

var api_key: String = ""
var model_name: String = ""
var target_mesh_name: String = ""
var obstacle_mesh_name: String = ""
var grid_map: GridMap

var base_tile_id: int = 308
var target_item_id: int = -1
var obstacle_item_id: int = -1
var plant_marker_item_id: int = 234

var current_mission: String = "reach"
var current_target_pos: Vector3i = Vector3i(0, 0, 0)
var current_obstacles: Array[Vector3i] = []
var current_plant_cells: Array[Vector3i] = []
var current_par_blocks: int = 1
var current_hint: String = ""

var http_request: HTTPRequest
var _last_start_pos: Vector3i = Vector3i(-1, 0, 19)
var _last_start_dir: int = 0
var _local_level_counter: int = 0
var _level_markers: Array[Node3D] = []

func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.accept_gzip = false
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func init_ai(key: String, m_name: String, target_name: String, obstacle_name: String, g_map: GridMap) -> void:
	api_key = key
	model_name = m_name
	target_mesh_name = target_name
	obstacle_mesh_name = obstacle_name
	grid_map = g_map
	
	if grid_map and grid_map.mesh_library:
		var lib = grid_map.mesh_library
		for id in lib.get_item_list():
			var item_name = lib.get_item_name(id).to_lower()
			if not target_mesh_name.is_empty() and target_mesh_name.to_lower() in item_name:
				target_item_id = id
			if not obstacle_mesh_name.is_empty() and obstacle_mesh_name.to_lower() in item_name:
				obstacle_item_id = id
			if "crops_dirtsingle3" in item_name:
				plant_marker_item_id = id
			if "campfire_bricks3" in item_name:
				base_tile_id = id
				
		print("IA Configurada. Meta ID: ", target_item_id, " | Obstaculo ID: ", obstacle_item_id, " | Siembra ID: ", plant_marker_item_id)
	else:
		ai_error.emit("Falta asignar GridMap o MeshLibrary al tractor.")

func request_next_level(tractor_pos: Vector3i, user_code: String = "") -> void:
	_last_start_pos = tractor_pos
	_last_start_dir = 0
	_local_level_counter += 1

	if api_key.is_empty() or http_request == null or not is_inside_tree():
		_apply_fallback_level()
		return
		
	var url = "https://generativelanguage.googleapis.com/v1beta/models/" + model_name + ":generateContent?key=" + api_key
	var unlocked := _get_unlocked_blocks()
	var can_plant := "interactuar" in unlocked
	
	var prompt = "Eres el director de un juego educativo donde el jugador programa un tractor usando bloques. "
	prompt += "El grid del campo va exactamente de X: -1 a 6 y Z: 11 a 18. El tractor inicia en X:" + str(tractor_pos.x) + " Z:" + str(tractor_pos.z) + " mirando al Norte (-Z). "
	prompt += "Bloques desbloqueados del jugador: [" + ", ".join(unlocked) + "]. "
	if can_plant:
		prompt += "Puedes elegir 'mission': 'reach' o 'plant'. En 'plant', incluye de 1 a 4 casillas en 'plant_cells' (sin obstaculos ni meta encima) donde el jugador usara interactuar() antes de llegar a 'target'. "
	else:
		prompt += "El jugador NO tiene 'interactuar' desbloqueado: DEBES usar 'mission': 'reach' y 'plant_cells': []. "
	
	if user_code.is_empty():
		prompt += "Este es el primer nivel. Haz algo sencillo. "
	else:
		prompt += "El jugador acaba de pasar un nivel usando este código:\n" + user_code + "\n"
		if "for_loop" in unlocked or "while_loop" in unlocked:
			prompt += "Tiene bucles desbloqueados; diseña un nivel donde los bucles ayuden y pon 1 a 3 obstáculos. "
		else:
			prompt += "Aún no tiene bucles; mantén un recorrido corto con 0 a 2 obstáculos. "
		
	prompt += "Debes responder ÚNICAMENTE con un JSON válido usando este esquema exacto:\n"
	prompt += '{"mission": "reach"|"plant", "target": {"x": int, "z": int}, "obstacles": [{"x": int, "z": int}], "plant_cells": [{"x": int, "z": int}], "par_blocks": int, "hint": "Pista corta util", "message": "Mensaje corto motivacional"}'
	
	var body = JSON.stringify({
		"contents": [{
			"parts": [{"text": prompt}]
		}],
		"generationConfig": {
			"temperature": 0.4,
			"response_mime_type": "application/json"
		}
	})
	
	var headers = ["Content-Type: application/json"]
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("AI HTTP request failed locally (err=", err, "), usando generador local.")
		_apply_fallback_level()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var err_str = body.get_string_from_utf8()
		print("AI Error (Result ", result, " / HTTP ", response_code, "): ", err_str, " -> usando generador local.")
		_apply_fallback_level()
		return
		
	var response_string = body.get_string_from_utf8().trim_prefix("\uFEFF").strip_edges()
	var json = JSON.new()
	var err = json.parse(response_string)
	
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		print("Gemini JSON invalido -> usando generador local.")
		_apply_fallback_level()
		return
		
	var root: Dictionary = json.data
	if root.has("candidates") and root["candidates"] is Array and root["candidates"].size() > 0:
		var content_text: String = str(root["candidates"][0]["content"]["parts"][0]["text"])
		
		# Limpiar formato si Gemini devuelve markdown block ```json ... ```
		content_text = content_text.strip_edges()
		if content_text.begins_with("```json"):
			content_text = content_text.substr(7)
		elif content_text.begins_with("```"):
			content_text = content_text.substr(3)
		if content_text.ends_with("```"):
			content_text = content_text.substr(0, content_text.length() - 3)
			
		var inner_json = JSON.new()
		var parse_err = inner_json.parse(content_text.strip_edges())
		if parse_err == OK and typeof(inner_json.data) == TYPE_DICTIONARY:
			var validated: Dictionary = LevelValidatorScript.sanitize_or_fallback(
				inner_json.data, _last_start_pos, _last_start_dir, _get_unlocked_blocks(), _get_level_index()
			)
			_apply_level_data(validated)
		else:
			print("Gemini no devolvió un objeto JSON válido -> usando generador local.")
			_apply_fallback_level()
	else:
		print("Respuesta de Gemini vacía -> usando generador local.")
		_apply_fallback_level()

func _apply_fallback_level() -> void:
	var fallback: Dictionary = LevelValidatorScript.generate_fallback_level(
		_last_start_pos, _last_start_dir, _get_unlocked_blocks(), _get_level_index()
	)
	_apply_level_data(fallback)

func _apply_level_data(data: Dictionary) -> void:
	clear_current_level()
	
	current_mission = str(data.get("mission", "reach"))
	current_par_blocks = maxi(1, int(data.get("par_blocks", 1)))
	current_hint = str(data.get("hint", "Planifica cada giro y usa bucles cuando repitas movimientos."))
	
	if data.has("target"):
		current_target_pos = _parse_cell(data["target"])
		
	if data.has("obstacles") and typeof(data["obstacles"]) == TYPE_ARRAY:
		for obs in data["obstacles"]:
			var obs_pos := _parse_cell(obs)
			if obs_pos != current_target_pos and obs_pos not in current_obstacles:
				current_obstacles.append(obs_pos)
				
	if data.has("plant_cells") and typeof(data["plant_cells"]) == TYPE_ARRAY:
		for cell in data["plant_cells"]:
			var plant_pos := _parse_cell(cell)
			if plant_pos != current_target_pos and plant_pos not in current_obstacles and plant_pos not in current_plant_cells:
				current_plant_cells.append(plant_pos)
				
	if current_mission == "plant" and current_plant_cells.is_empty():
		current_mission = "reach"
		
	reset_level_tiles()
	_spawn_level_markers()
					
	var msg: String = str(data.get("message", "¡Nuevo nivel generado!"))
	var configured_data: Dictionary = {
		"mission": current_mission,
		"target": current_target_pos,
		"obstacles": current_obstacles.duplicate(),
		"plant_cells": current_plant_cells.duplicate(),
		"par_blocks": current_par_blocks,
		"hint": current_hint,
		"message": msg,
	}
	level_loaded.emit("IA: " + msg)
	level_configured.emit(configured_data)

## Repinta limpiamente las casillas del nivel actual para reintentos sin residuos de siembras previas.
func reset_level_tiles() -> void:
	if not grid_map:
		return
	_restore_grid_to_base()
	if plant_marker_item_id != -1:
		for plant_pos in current_plant_cells:
			if LevelValidatorScript.is_in_bounds(plant_pos):
				grid_map.set_cell_item(plant_pos, plant_marker_item_id, 0)
	if obstacle_item_id != -1:
		for obs_pos in current_obstacles:
			if LevelValidatorScript.is_in_bounds(obs_pos):
				grid_map.set_cell_item(obs_pos, obstacle_item_id, 0)
	if target_item_id != -1 and LevelValidatorScript.is_in_bounds(current_target_pos):
		grid_map.set_cell_item(current_target_pos, target_item_id, 0)

func clear_current_level() -> void:
	_clear_level_markers()
	if grid_map:
		_restore_grid_to_base()
	current_obstacles.clear()
	current_plant_cells.clear()

func _restore_grid_to_base() -> void:
	for x in range(LevelValidatorScript.MIN_X, LevelValidatorScript.MAX_X + 1):
		for z in range(LevelValidatorScript.MIN_Z, LevelValidatorScript.MAX_Z + 1):
			grid_map.set_cell_item(Vector3i(x, 0, z), base_tile_id, 0)

func _spawn_level_markers() -> void:
	if not grid_map or not grid_map.is_inside_tree():
		return
	if LevelValidatorScript.is_in_bounds(current_target_pos):
		_spawn_cell_marker(current_target_pos, Color(1.0, 0.78, 0.18, 0.92), "META", 0.78)
	for plant_pos in current_plant_cells:
		if LevelValidatorScript.is_in_bounds(plant_pos):
			_spawn_cell_marker(plant_pos, Color(0.28, 0.92, 0.45, 0.90), "SEMBRAR", 0.70)

func _spawn_cell_marker(cell: Vector3i, color: Color, label_text: String, outer_radius: float) -> void:
	var marker_root := Node3D.new()
	marker_root.name = "LevelMarker_%d_%d" % [cell.x, cell.z]
	marker_root.position = grid_map.map_to_local(cell)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = outer_radius - 0.14
	torus.outer_radius = outer_radius
	torus.rings = 24
	torus.ring_segments = 16
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.28, 0.0)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = 1.4
	ring.material_override = mat
	marker_root.add_child(ring)

	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, 1.15, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.005
	label.outline_size = 8
	label.outline_modulate = Color(0.05, 0.07, 0.10, 1.0)
	label.modulate = color.lightened(0.25)
	marker_root.add_child(label)

	grid_map.add_child(marker_root)
	_level_markers.append(marker_root)

	var bob := marker_root.create_tween().set_loops()
	bob.tween_property(label, "position:y", 1.28, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(label, "position:y", 1.12, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var pulse := marker_root.create_tween().set_loops()
	pulse.tween_property(ring, "scale", Vector3.ONE * 1.08, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(ring, "scale", Vector3.ONE * 0.94, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _clear_level_markers() -> void:
	for marker in _level_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_level_markers.clear()

func _parse_cell(entry: Variant) -> Vector3i:
	if entry is Vector3i:
		return entry
	if entry is Dictionary:
		return Vector3i(int(entry.get("x", 0)), 0, int(entry.get("z", 0)))
	return Vector3i.ZERO

func _get_game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/GameState")

func _get_unlocked_blocks() -> Array[String]:
	var gs := _get_game_state()
	if gs != null and gs.get("unlocked_blocks") != null:
		var blocks: Array[String] = []
		for b in gs.unlocked_blocks:
			blocks.append(str(b))
		if not blocks.is_empty():
			return blocks
	return ["avanzar", "girar_derecha", "girar_izquierda"]

func _get_level_index() -> int:
	var gs := _get_game_state()
	if gs != null and gs.get("levels_completed") != null:
		return int(gs.levels_completed) + 1
	return maxi(1, _local_level_counter)
