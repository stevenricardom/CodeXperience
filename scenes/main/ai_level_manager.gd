extends Node
class_name AILevelManager

signal level_loaded(message: String)
signal ai_error(message: String)

var api_key: String = ""
var model_name: String = ""
var target_mesh_name: String = ""
var obstacle_mesh_name: String = ""
var grid_map: GridMap

var target_item_id: int = -1
var obstacle_item_id: int = -1

var current_target_pos: Vector3i = Vector3i(0, 0, 0)
var current_obstacles: Array[Vector3i] = []

var http_request: HTTPRequest

func _ready() -> void:
	http_request = HTTPRequest.new()
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
			if target_mesh_name.to_lower() in item_name:
				target_item_id = id
			if obstacle_mesh_name.to_lower() in item_name:
				obstacle_item_id = id
				
		print("IA Configurada. Meta ID: ", target_item_id, " | Obstaculo ID: ", obstacle_item_id)
	else:
		ai_error.emit("Falta asignar GridMap o MeshLibrary al tractor.")

func request_next_level(tractor_pos: Vector3i, user_code: String = "") -> void:
	if api_key.is_empty():
		ai_error.emit("Falta la API Key de Gemini. Configúrala en el nodo Main.")
		return
		
	var url = "https://generativelanguage.googleapis.com/v1beta/models/" + model_name + ":generateContent?key=" + api_key
	
	var prompt = "Eres el director de un juego educativo donde el jugador programa un tractor usando bloques. "
	prompt += "El grid del campo va de X: -6 a 6 y Z: 11 a 18. El tractor está en X:" + str(tractor_pos.x) + " Z:" + str(tractor_pos.z) + ". "
	
	if user_code.is_empty():
		prompt += "Este es el primer nivel. Haz algo sencillo. "
	else:
		prompt += "El jugador acaba de pasar un nivel usando este código:\n" + user_code + "\n"
		prompt += "Si usó 'for' o 'while', aumenta la dificultad poniendo 1 o 2 obstáculos. "
		prompt += "Si el código es muy largo sin bucles, pon un nivel donde un bucle sea útil. "
		
	prompt += "Debes responder ÚNICAMENTE con un JSON válido usando este esquema exacto:\n"
	prompt += '{"target": {"x": int, "z": int}, "obstacles": [{"x": int, "z": int}], "message": "Mensaje corto motivacional"}'
	
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
		ai_error.emit("No se pudo contactar a Gemini (Error local).")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var err_str = body.get_string_from_utf8()
		ai_error.emit("Error de API Gemini (Código " + str(response_code) + ")")
		print("AI Error: ", err_str)
		return
		
	var response_string = body.get_string_from_utf8()
	var json = JSON.new()
	var err = json.parse(response_string)
	
	if err != OK:
		ai_error.emit("Gemini devolvió un JSON inválido.")
		return
		
	var root = json.data
	if root.has("candidates") and root["candidates"].size() > 0:
		var content_text = root["candidates"][0]["content"]["parts"][0]["text"]
		
		# Limpiar formato si Gemini devuelve markdown block ```json ... ```
		content_text = content_text.strip_edges()
		if content_text.begins_with("```json"):
			content_text = content_text.substr(7)
		if content_text.ends_with("```"):
			content_text = content_text.substr(0, content_text.length() - 3)
			
		var inner_json = JSON.new()
		var parse_err = inner_json.parse(content_text.strip_edges())
		if parse_err == OK:
			_apply_level_data(inner_json.data)
		else:
			ai_error.emit("Gemini no devolvió la estructura JSON requerida.")
	else:
		ai_error.emit("Respuesta de Gemini vacía.")

func _apply_level_data(data: Dictionary) -> void:
	clear_current_level()
	
	if data.has("target"):
		current_target_pos = Vector3i(int(data["target"]["x"]), 0, int(data["target"]["z"]))
		if target_item_id != -1:
			grid_map.set_cell_item(current_target_pos, target_item_id)
			print("Meta generada en: ", current_target_pos)
			
	if data.has("obstacles") and typeof(data["obstacles"]) == TYPE_ARRAY:
		for obs in data["obstacles"]:
			var obs_pos = Vector3i(int(obs["x"]), 0, int(obs["z"]))
			# No poner obstáculos encima del tractor o de la meta
			if obs_pos != current_target_pos: # Podría validarse más
				current_obstacles.append(obs_pos)
				if obstacle_item_id != -1:
					grid_map.set_cell_item(obs_pos, obstacle_item_id)
					
	var msg = data.get("message", "¡Nuevo nivel generado!")
	level_loaded.emit("🤖 IA: " + msg)

func clear_current_level() -> void:
	if grid_map:
		# Borrar meta
		if target_item_id != -1 and grid_map.get_cell_item(current_target_pos) == target_item_id:
			grid_map.set_cell_item(current_target_pos, GridMap.INVALID_CELL_ITEM)
		
		# Borrar obstáculos
		if obstacle_item_id != -1:
			for obs_pos in current_obstacles:
				if grid_map.get_cell_item(obs_pos) == obstacle_item_id:
					grid_map.set_cell_item(obs_pos, GridMap.INVALID_CELL_ITEM)
	
	current_obstacles.clear()
