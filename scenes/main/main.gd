extends Node3D

const FarmHUDScript = preload("res://scenes/ui/hud/farm_hud.gd")
const LevelValidatorScript = preload("res://scripts/game/level_validator.gd")

@onready var tractor: CharacterBody3D = $Actors/Tractor

# --- Viewport2Din3D de cada panel (asignar en el Inspector) ---
@export var viewport_actions: Node3D
@export var viewport_code: Node3D
@export var viewport_variables: Node3D
@export var viewport_shop: Node3D

@export_group("IA Adaptativa (Gemini)")
@export var gemini_api_key: String = ""
@export var gemini_model_name: String = "gemini-3.5-flash"
@export var ai_meta_nombre: String = "crops_wheat"
@export var ai_obstaculo_nombre: String = "rock"

# Referencias a las instancias 2D dentro de cada viewport
var panel_actions = null
var panel_code = null
var panel_variables = null
var panel_shop = null
var is_running: bool = false
var ai_manager: Node
var farm_hud: FarmHUD = null
var desktop_interaction: Node = null

var attempts_on_current_level: int = 0
var hint_used_on_current_level: bool = false
var _awaiting_next_level: bool = false
var _last_won_code: String = ""

func _ready() -> void:
	var panels = {
		"actions": viewport_actions,
		"code": viewport_code,
		"variables": viewport_variables,
		"shop": viewport_shop,
	}

	var max_attempts: int = 2 if DisplayServer.get_name() == "headless" else 60
	var attempts: int = 0
	while attempts < max_attempts:
		var all_ready: bool = true
		for key in panels:
			var vp = panels[key]
			if vp and vp.has_method("get_scene_instance") and vp.get_scene_instance() == null:
				all_ready = false
				break
		if all_ready:
			break
		await get_tree().process_frame
		attempts += 1

	for key in panels:
		var vp = panels[key]
		if not vp or not vp.has_method("get_scene_instance"):
			if key != "shop":
				print("Advertencia: Viewport para '", key, "' no asignado. Arrastralo en el Inspector de Main.")
			continue
		var instance = vp.get_scene_instance()
		if not instance:
			print("No se pudo obtener la instancia del panel '", key, "'")
			continue
		match key:
			"actions": panel_actions = instance
			"code": panel_code = instance
			"variables": panel_variables = instance
			"shop": panel_shop = instance

	# --- HUD de Granja ---
	farm_hud = FarmHUDScript.new()
	add_child(farm_hud)
	farm_hud.next_level_requested.connect(_on_next_level_requested)

	desktop_interaction = get_node_or_null("Actors/PlayerXR_Desktop/DesktopInteraction")
	if desktop_interaction and desktop_interaction.has_signal("remote_run_requested") and not desktop_interaction.remote_run_requested.is_connected(_on_remote_run_requested):
		desktop_interaction.remote_run_requested.connect(_on_remote_run_requested)
	
	# --- Conectar señales entre paneles ---
	
	# Panel de Acciones → Canvas de Bloques (panel_code)
	if panel_actions and panel_code:
		panel_actions.block_requested.connect(panel_code.add_block)
		print("Conexion: Panel de Acciones a Canvas")
	
	# Panel de Variables → Canvas de Bloques (panel_code)
	if panel_variables and panel_code:
		panel_variables.block_requested.connect(panel_code.add_block)
		print("Canvas de Bloques")
	
	# Condición del panel de variables → panel de acciones
	if panel_variables and panel_actions:
		panel_variables.condition_changed.connect(panel_actions.set_condition)
		print("Conexion: Variables a Acciones")
	
	# Ejecución, pistas y errores
	if panel_code:
		panel_code.code_execution_requested.connect(_on_code_execution_requested)
		panel_code.clear_requested.connect(_on_clear_requested)
		if panel_code.has_signal("hint_requested"):
			panel_code.hint_requested.connect(_on_hint_requested)
		panel_code.mostrar_mensaje("Tractor conectado. Añade bloques desde el panel de acciones.")
		print("Conexion: Panel de Codigo")

	if is_instance_valid(tractor):
		if not tractor.error_ocurrido.is_connected(_on_tractor_error):
			tractor.error_ocurrido.connect(_on_tractor_error)
		if tractor.has_signal("cell_planted"):
			tractor.cell_planted.connect(_on_tractor_cell_planted)

	# --- Inicializar IA / Generador local ---
	ai_manager = preload("res://scenes/main/ai_level_manager.gd").new()
	add_child(ai_manager)
	
	if panel_code:
		ai_manager.level_loaded.connect(panel_code.mostrar_exito)
		ai_manager.ai_error.connect(panel_code.mostrar_error)
	if ai_manager.has_signal("level_configured"):
		ai_manager.level_configured.connect(_on_level_configured)
		
	# Pequeño retraso para asegurar que el grid está listo
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(tractor) and is_instance_valid(ai_manager):
		ai_manager.init_ai(gemini_api_key, gemini_model_name, ai_meta_nombre, ai_obstaculo_nombre, tractor.grid_map)
		tractor.obstacle_item_id = ai_manager.obstacle_item_id
		_request_new_level("")

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _request_new_level(user_code: String = "") -> void:
	attempts_on_current_level = 0
	hint_used_on_current_level = false
	_awaiting_next_level = false

	var gs := _get_game_state()
	if gs and gs.has_method("on_level_started"):
		gs.on_level_started()

	if panel_code and panel_code.has_method("update_hint_button"):
		panel_code.update_hint_button(false)

	if is_instance_valid(tractor):
		tractor.reset_state()

	if is_instance_valid(ai_manager) and is_instance_valid(tractor):
		ai_manager.request_next_level(tractor.initial_grid_pos, user_code)

func _on_next_level_requested() -> void:
	_awaiting_next_level = false
	_request_new_level(_last_won_code)

func _on_level_configured(_level_data: Dictionary) -> void:
	_refresh_mission_displays()
	if panel_code and panel_code.has_method("update_hint_button"):
		panel_code.update_hint_button(hint_used_on_current_level)

func _on_tractor_cell_planted(_grid_pos: Vector3i) -> void:
	_refresh_mission_displays()

func _count_required_planted() -> int:
	if not is_instance_valid(ai_manager) or not is_instance_valid(tractor):
		return 0
	var count: int = 0
	for cell in ai_manager.current_plant_cells:
		if cell in tractor.planted_cells:
			count += 1
	return count

func _format_mission_banner(mission: String, planted_count: int, total_plant: int) -> String:
	if mission == "plant":
		return "Sembrar %d/%d + Meta" % [planted_count, total_plant]
	return "Llegar a la meta"

func _refresh_mission_displays() -> void:
	if not is_instance_valid(ai_manager):
		return
	var mission: String = ai_manager.current_mission
	var total_plant: int = ai_manager.current_plant_cells.size()
	var planted: int = _count_required_planted()
	var par_blocks: int = ai_manager.current_par_blocks

	if is_instance_valid(farm_hud):
		farm_hud.update_mission_status(mission, planted, total_plant, par_blocks)
	if panel_code and panel_code.has_method("update_mission_banner"):
		panel_code.update_mission_banner(_format_mission_banner(mission, planted, total_plant), par_blocks)

func _on_hint_requested() -> void:
	if not is_instance_valid(ai_manager) or not panel_code:
		return
	if hint_used_on_current_level:
		if panel_code.has_method("mostrar_pista"):
			panel_code.mostrar_pista(ai_manager.current_hint)
		return

	var gs := _get_game_state()
	if gs and gs.has_method("try_purchase_hint"):
		var res: Dictionary = gs.try_purchase_hint()
		if not bool(res.get("ok", false)):
			var cost: int = int(res.get("cost", 5))
			panel_code.mostrar_error("Necesitas %d monedas para pedir una pista." % cost)
			return

	hint_used_on_current_level = true
	if panel_code.has_method("mostrar_pista"):
		panel_code.mostrar_pista(ai_manager.current_hint)

func _on_tractor_error(msg: String) -> void:
	if panel_code:
		panel_code.mostrar_error(msg)
	_notify_remote("error", "Tractor: " + msg, 3.5)

func _notify_remote(status: String, message: String, duration: float = 3.0) -> void:
	if is_instance_valid(desktop_interaction) and desktop_interaction.has_method("notify_remote_status"):
		desktop_interaction.notify_remote_status(status, message, duration)

func _on_remote_run_requested() -> void:
	if _awaiting_next_level:
		return
	if is_running:
		_notify_remote("busy", "Control remoto: El tractor ya está en movimiento.", 2.2)
		return
	if panel_code == null or panel_code.get("canvas") == null or panel_code.canvas.get_block_count() == 0:
		if panel_code:
			panel_code.mostrar_error("No hay bloques. Añade bloques desde el panel de acciones.")
		_notify_remote("error", "Control remoto: Sin bloques programados. Programa en el palco con [E].", 3.2)
		return
	var count: int = panel_code.canvas.get_block_count()
	_notify_remote("ok", "Control remoto: Ejecutando código (%d bloques)..." % count, 2.5)
	panel_code.execute()

# ============================================
# EJECUCIÓN
# ============================================
func _on_clear_requested() -> void:
	if panel_code:
		panel_code.clear()
	if panel_variables:
		panel_variables.clear_all()
	if is_instance_valid(tractor):
		tractor.stop()
	is_running = false

func _on_code_execution_requested(code_text: String) -> void:
	if is_running or _awaiting_next_level:
		return
	if not tractor:
		if panel_code:
			panel_code.mostrar_error("No se encontró el nodo del tractor.")
		return

	is_running = true
	attempts_on_current_level += 1
	tractor.reset_state()  # Reiniciar a la posición inicial y limpiar siembras previas
	tractor.stop_requested = false
	if is_instance_valid(ai_manager) and ai_manager.has_method("reset_level_tiles"):
		ai_manager.reset_level_tiles()
	_refresh_mission_displays()
	
	var has_control_flow: bool = false
	for keyword in ["for ", "while ", "if ", "elif ", "else:", "var "]:
		if keyword in code_text:
			has_control_flow = true
			break
			
	if not has_control_flow:
		await _execute_simple_lines(code_text)
	else:
		await _execute_dynamic_code(code_text)
		
	# Al terminar de ejecutar (ya sea por éxito o por error), esperar 1.5s
	if is_instance_valid(tractor):
		await get_tree().create_timer(1.5).timeout
		
		var won: bool = false
		var award: Dictionary = {}
		var blocks_used: int = 0

		# Solo comprobar victoria si no hubo un choque/error a mitad de camino
		if not tractor.stop_requested and is_instance_valid(ai_manager) and LevelValidatorScript.is_in_bounds(ai_manager.current_target_pos):
			var at_target: bool = (tractor.current_grid_pos == ai_manager.current_target_pos)
			var mission: String = ai_manager.current_mission

			var fail_msg: String = ""
			if mission == "plant":
				var planted_all: bool = tractor.has_planted_all(ai_manager.current_plant_cells)
				if at_target and planted_all:
					won = true
				elif at_target:
					fail_msg = "Llegaste a la meta, pero faltaron casillas por sembrar con Interactuar()."
				else:
					fail_msg = "No llegaste a la meta. Vuelve a intentarlo."
			else:
				if at_target:
					won = true
				else:
					fail_msg = "No llegaste a la meta. Vuelve a intentarlo."

			if not won and not fail_msg.is_empty():
				if panel_code:
					panel_code.mostrar_error(fail_msg)
				_notify_remote("error", fail_msg, 3.5)

		if won:
			blocks_used = LevelValidatorScript.count_code_blocks(code_text)
			_last_won_code = code_text
			var gs := _get_game_state()
			if gs and gs.has_method("award_level"):
				award = gs.award_level(
					ai_manager.current_mission,
					blocks_used,
					ai_manager.current_par_blocks,
					attempts_on_current_level,
					hint_used_on_current_level
				)
			if panel_code:
				panel_code.mostrar_exito("¡Misión cumplida! +%d monedas" % int(award.get("total_coins_earned", 0)))
			tractor.reset_state()
			if is_instance_valid(farm_hud):
				_awaiting_next_level = true
				farm_hud.show_level_result(
					award,
					blocks_used,
					ai_manager.current_par_blocks,
					attempts_on_current_level,
					hint_used_on_current_level
				)
			else:
				_request_new_level(code_text)
		else:
			tractor.reset_state()
			if is_instance_valid(ai_manager) and ai_manager.has_method("reset_level_tiles"):
				ai_manager.reset_level_tiles()
			_refresh_mission_displays()
			
	is_running = false

func _execute_simple_lines(code_text: String) -> void:
	var lines = code_text.split("\n")
	
	for raw_line in lines:
		var line = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#") or line == "pass":
			continue
			
		if tractor.stop_requested:
			if panel_code:
				panel_code.mostrar_error("Ejecución detenida.")
			return

		match line:
			"avanzar()":
				await tractor.avanzar()
			"girar_derecha()":
				await tractor.girar_derecha()
			"girar_izquierda()":
				await tractor.girar_izquierda()
			"interactuar()":
				await tractor.interactuar()
			_:
				if panel_code:
					panel_code.mostrar_error("Comando no reconocido '" + line + "'")
				return
		
		if tractor.stop_requested:
			return
				
	if panel_code and not tractor.stop_requested:
		panel_code.mostrar_exito("¡Ruta completada con éxito!")

func _execute_dynamic_code(code_text: String) -> void:
	var transformed = code_text
	
	transformed = transformed.replace("avanzar()", "await tractor.avanzar(); if tractor.stop_requested: return")
	transformed = transformed.replace("girar_derecha()", "await tractor.girar_derecha(); if tractor.stop_requested: return")
	transformed = transformed.replace("girar_izquierda()", "await tractor.girar_izquierda(); if tractor.stop_requested: return")
	transformed = transformed.replace("interactuar()", "await tractor.interactuar(); if tractor.stop_requested: return")
	
	var indented_code = ""
	for line in transformed.split("\n"):
		indented_code += "\t" + line + "\n"
		
		var stripped = line.strip_edges()
		if stripped.begins_with("while ") or stripped.begins_with("for "):
			var tabs = ""
			for i in range(line.length()):
				if line[i] == "\t": tabs += "\t"
				else: break
				
			indented_code += "\t" + tabs + "\t" + "await tractor.get_tree().process_frame\n"
			indented_code += "\t" + tabs + "\t" + "if tractor.stop_requested: return\n"
		
	var wrapper_source = """extends RefCounted

func run_program(tractor) -> void:
%s
""" % indented_code

	var script = GDScript.new()
	script.source_code = wrapper_source
	var err = script.reload()
	
	if err != OK:
		if panel_code:
			panel_code.mostrar_error("Error de sintaxis. Revisa los bloques.")
		return
		
	var runner = script.new()
	await runner.run_program(tractor)
	
	if panel_code and not tractor.stop_requested:
		panel_code.mostrar_exito("¡Programa completado con éxito!")
