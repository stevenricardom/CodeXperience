extends Node3D

@onready var tractor: CharacterBody3D = $Actors/Tractor

# --- Viewport2Din3D de cada panel (asignar en el Inspector) ---
@export var viewport_actions: Node3D
@export var viewport_code: Node3D
@export var viewport_variables: Node3D

@export_group("IA Adaptativa (Gemini)")
@export var gemini_api_key: String = ""
@export var gemini_model_name: String = "gemini-3.5-flash"
@export var ai_meta_nombre: String = "crops_wheat"
@export var ai_obstaculo_nombre: String = "rock"

# Referencias a las instancias 2D dentro de cada viewport
var panel_actions = null
var panel_code = null
var panel_variables = null
var is_running: bool = false
var ai_manager: Node

func _ready() -> void:
	var panels = {
		"actions": viewport_actions,
		"code": viewport_code,
		"variables": viewport_variables,
	}
	
	for key in panels:
		var vp = panels[key]
		if not vp or not vp.has_method("get_scene_instance"):
			print("Advertencia: Viewport para '", key, "' no asignado. Arrastralo en el Inspector de Main.")
			continue
		
		var attempts = 0
		while vp.get_scene_instance() == null and attempts < 60:
			await get_tree().process_frame
			attempts += 1
		
		var instance = vp.get_scene_instance()
		if not instance:
			print("No se pudo obtener la instancia del panel '", key, "'")
			continue
		
		match key:
			"actions": panel_actions = instance
			"code": panel_code = instance
			"variables": panel_variables = instance
	
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
	
	# Ejecución y errores
	if panel_code:
		panel_code.code_execution_requested.connect(_on_code_execution_requested)
		panel_code.clear_requested.connect(_on_clear_requested)
		panel_code.mostrar_mensaje("Tractor conectado. Añade bloques desde el panel de acciones.")
		print("Conexion: Panel de Codigo")
		
		if not tractor.error_ocurrido.is_connected(panel_code.mostrar_error):
			tractor.error_ocurrido.connect(panel_code.mostrar_error)

	# --- Inicializar IA ---
	ai_manager = preload("res://scenes/main/ai_level_manager.gd").new()
	add_child(ai_manager)
	
	if panel_code:
		ai_manager.level_loaded.connect(panel_code.mostrar_exito)
		ai_manager.ai_error.connect(panel_code.mostrar_error)
		
	# Pequeño retraso para asegurar que el grid está listo
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(tractor) and is_instance_valid(ai_manager):
		ai_manager.init_ai(gemini_api_key, gemini_model_name, ai_meta_nombre, ai_obstaculo_nombre, tractor.grid_map)
		tractor.obstacle_item_id = ai_manager.obstacle_item_id
		
		# Solo pedir el nivel si hay API key
		if not gemini_api_key.is_empty():
			ai_manager.request_next_level(tractor.initial_grid_pos, "")

# ============================================
# EJECUCIÓN
# ============================================
func _on_clear_requested() -> void:
	if panel_code:
		panel_code.clear()
	if panel_variables:
		panel_variables.clear_all()
	tractor.stop()
	is_running = false

func _on_code_execution_requested(code_text: String) -> void:
	if is_running:
		return
	if not tractor:
		if panel_code:
			panel_code.mostrar_error("No se encontró el nodo del tractor.")
		return

	is_running = true
	tractor.reset_state()  # Reiniciar a la posición inicial antes de ejecutar
	tractor.stop_requested = false
	
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
	if tractor:
		await get_tree().create_timer(1.5).timeout
		
		# Solo comprobar victoria si no hubo un choque/error a mitad de camino
		if not tractor.stop_requested:
			if is_instance_valid(ai_manager) and ai_manager.current_target_pos != Vector3i.ZERO:
				if tractor.current_grid_pos == ai_manager.current_target_pos:
					if panel_code:
						panel_code.mostrar_exito("Mision Cumplida! Solicitando siguiente nivel...")
					ai_manager.request_next_level(tractor.initial_grid_pos, code_text)
				else:
					if panel_code:
						panel_code.mostrar_error("No llegaste a la meta. Vuelve a intentarlo.")
					
		# Reiniciar siempre a la posición inicial
		tractor.reset_state()
			
	is_running = false

func _execute_simple_lines(code_text: String) -> void:
	var lines = code_text.split("\n")
	
	for raw_line in lines:
		var line = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
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
