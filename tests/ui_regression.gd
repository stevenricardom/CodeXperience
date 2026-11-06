extends SceneTree
## Regresión visual/UI de la estación de programación.
##
## Ejecutar: Godot --headless --path . --script res://tests/ui_regression.gd
##
## Cubre: tema compartido y estados, legibilidad de controles, ausencia de
## desbordes a 1280x720 y 1920x1080, y los flujos de lógica que no deben
## romperse con el rediseño (paleta -> código, variables -> código y limpieza,
## constructor de condiciones y generación de bloques FOR/WHILE/IF/ELSE).

const WATCHDOG_MS := 10000

const SCENE_ACTIONS := "res://scenes/ui/panel_actions/panel_actions.tscn"
const SCENE_CODE := "res://scenes/ui/panel_code/panel_code.tscn"
const SCENE_VARIABLES := "res://scenes/ui/panel_variables/panel_variables.tscn"
const SCENE_CAMERA := "res://scenes/ui/panel_camera/panel_camera.tscn"
const SCENE_MENU := "res://scenes/ui/main_menu/main_menu.tscn"

const PANEL_SCENES := [SCENE_ACTIONS, SCENE_CODE, SCENE_VARIABLES, SCENE_CAMERA]

var passed := 0
var failed := 0
var _viewports: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(20.0).timeout.connect(func():
		push_error("UI regression watchdog expired")
		quit(1))
	var tests := [
		"test_shared_theme_states",
		"test_theme_is_consistent_between_panels",
		"test_actions_palette_legibility",
		"test_variables_legibility",
		"test_code_panel_legibility",
		"test_headers_and_short_help",
		"test_no_horizontal_overflow",
		"test_actions_to_code",
		"test_variables_to_code_and_clear",
		"test_condition_builder",
		"test_container_builders_generate_code",
		"test_menu_desktop_only",
	]
	for test_name in tests:
		await _run_guarded(test_name)
	_cleanup()
	print("UI regression: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

# ============================================
# EJECUCIÓN CON WATCHDOG
# ============================================
## Ejecuta un test. Cada test devuelve bool; si aborta (error en tiempo de
## ejecución) nunca emite su resultado y el watchdog lo marca como fallido.
func _run_guarded(test_name: String) -> void:
	if await call(test_name) != true:
		check(false, test_name + " reportó fallo")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func _cleanup() -> void:
	for vp in _viewports:
		if is_instance_valid(vp):
			vp.queue_free()
	_viewports.clear()

# ============================================
# HELPERS DE ESCENA
# ============================================
func _make_viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	_viewports.append(vp)
	return vp

func _instantiate(scene_path: String, vp: SubViewport) -> Control:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return null
	var node: Control = packed.instantiate()
	vp.add_child(node)
	return node

func _buttons(node: Node) -> Array:
	var result: Array = []
	_collect_buttons(node, result)
	return result

func _collect_buttons(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is Button:
			result.append(child)
		_collect_buttons(child, result)

func _labels(node: Node) -> Array:
	var result: Array = []
	_collect_labels(node, result)
	return result

func _collect_labels(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is Label:
			result.append(child)
		_collect_labels(child, result)

## Tamaño de fuente efectivo (tiene en cuenta theme_override_font_sizes).
func _font_size(control: Control, name: String = "font_size") -> int:
	if control.has_theme_font_size_override(name):
		return control.get_theme_font_size(name)
	return control.get_theme_font_size(name)

func _find_button(node: Node, matcher: Callable) -> Button:
	for btn in _buttons(node):
		if matcher.call(btn.text):
			return btn
	return null

func _press(btn: Button) -> bool:
	if btn == null:
		return false
	btn.pressed.emit()
	return true

func _text_has(node: Node, needle: String) -> bool:
	for lbl in _labels(node):
		if lbl.text.to_lower().contains(needle.to_lower()):
			return true
	return false

# ============================================
# 1) TEMA COMPARTIDO Y ESTADOS
# ============================================
func test_shared_theme_states() -> bool:
	await process_frame
	for scene_path in PANEL_SCENES:
		var vp := _make_viewport(Vector2i(1280, 720))
		var panel := _instantiate(scene_path, vp)
		await process_frame
		check(panel != null, scene_path + " se puede instanciar")
		if panel == null:
			continue
		var th: Theme = panel.theme
		check(th != null, scene_path + " usa un tema compartido")
		if th == null:
			continue
		var normal: StyleBox = th.get_stylebox("normal", "Button")
		var hover: StyleBox = th.get_stylebox("hover", "Button")
		var pressed: StyleBox = th.get_stylebox("pressed", "Button")
		var focus: StyleBox = th.get_stylebox("focus", "Button")
		var disabled: StyleBox = th.get_stylebox("disabled", "Button")
		check(normal != null and hover != null and pressed != null and focus != null and disabled != null,
			scene_path + " define estados normal/hover/pressed/focus/disabled")
		if normal == null or hover == null or pressed == null or focus == null:
			continue
		var n_flat := normal as StyleBoxFlat
		var h_flat := hover as StyleBoxFlat
		var p_flat := pressed as StyleBoxFlat
		var f_flat := focus as StyleBoxFlat
		check(n_flat.bg_color != h_flat.bg_color, scene_path + " hover cambia el color del botón")
		check(n_flat.bg_color != p_flat.bg_color, scene_path + " pressed cambia el color del botón")
		check(f_flat.border_color != n_flat.border_color, scene_path + " focus se distingue por el borde")
		check(th.default_font_size >= 16, scene_path + " tipografía base legible (>= 16 px)")
	return true

# ============================================
# 2) COHERENCIA DEL TEMA ENTRE PANELES
# ============================================
func test_theme_is_consistent_between_panels() -> bool:
	await process_frame
	var reference_color := Color(0, 0, 0, 0)
	var reference_font := -1
	var first := true
	for scene_path in PANEL_SCENES:
		var vp := _make_viewport(Vector2i(1280, 720))
		var panel := _instantiate(scene_path, vp)
		await process_frame
		if panel == null or panel.theme == null:
			check(false, scene_path + " tiene tema para comparar")
			continue
		var flat := panel.theme.get_stylebox("normal", "Button") as StyleBoxFlat
		if flat == null:
			check(false, scene_path + " el botón normal es un StyleBoxFlat")
			continue
		if first:
			reference_color = flat.bg_color
			reference_font = panel.theme.default_font_size
			first = false
			continue
		check(flat.bg_color == reference_color, scene_path + " comparte la paleta de tarjetas")
		check(panel.theme.default_font_size == reference_font, scene_path + " comparte la tipografía base")
	return true

# ============================================
# 3) LEGIBILIDAD DE LA PALETA DE ACCIONES
# ============================================
func test_actions_palette_legibility() -> bool:
	await process_frame
	var vp := _make_viewport(Vector2i(1280, 720))
	var panel := _instantiate(SCENE_ACTIONS, vp)
	await process_frame
	if panel == null:
		check(false, "panel de acciones instanciable")
		return true
	var buttons := _buttons(panel)
	check(buttons.size() >= 8, "la paleta expone al menos 8 botones (hay %d)" % buttons.size())
	for btn in buttons:
		var min_h: float = maxf(btn.custom_minimum_size.y, btn.get_combined_minimum_size().y)
		check(min_h >= 44, "botón '%s' tiene altura accesible (%.0f px)" % [btn.text, min_h])
		check(_font_size(btn) >= 16, "botón '%s' tiene fuente >= 16 px (%d)" % [btn.text, _font_size(btn)])
	var variations: Array = []
	for btn in buttons:
		variations.append(btn.theme_type_variation)
	check(variations.has("StationPrimary"), "la paleta usa el botón primario del tema")
	check(variations.has("StationAccent"), "la paleta usa el botón de acento del tema")
	return true

# ============================================
# 4) LEGIBILIDAD DEL TALLER DE VARIABLES
# ============================================
func test_variables_legibility() -> bool:
	await process_frame
	var vp := _make_viewport(Vector2i(1280, 720))
	var panel := _instantiate(SCENE_VARIABLES, vp)
	await process_frame
	if panel == null:
		check(false, "panel de variables instanciable")
		return true
	var buttons := _buttons(panel)
	check(buttons.size() >= 13, "el taller expone todos sus spinners y el botón crear (hay %d)" % buttons.size())
	for btn in buttons:
		var min_h: float = maxf(btn.custom_minimum_size.y, btn.get_combined_minimum_size().y)
		check(min_h >= 44, "botón '%s' tiene altura accesible (%.0f px)" % [btn.text, min_h])
		check(_font_size(btn) >= 16, "botón '%s' tiene fuente >= 16 px (%d)" % [btn.text, _font_size(btn)])
	for lbl in _labels(panel):
		check(_font_size(lbl) >= 16, "etiqueta '%s' tiene fuente >= 16 px (%d)" % [lbl.text, _font_size(lbl)])
	return true

# ============================================
# 5) LEGIBILIDAD DEL PANEL DE CÓDIGO
# ============================================
func test_code_panel_legibility() -> bool:
	await process_frame
	var vp := _make_viewport(Vector2i(1280, 720))
	var panel := _instantiate(SCENE_CODE, vp)
	await process_frame
	if panel == null:
		check(false, "panel de código instanciable")
		return true
	var buttons := _buttons(panel)
	check(buttons.size() >= 3, "el panel de código expone ejecutar / borrar / limpiar (hay %d)" % buttons.size())
	for btn in buttons:
		var min_h: float = maxf(btn.custom_minimum_size.y, btn.get_combined_minimum_size().y)
		check(min_h >= 44, "botón '%s' tiene altura accesible (%.0f px)" % [btn.text, min_h])
		check(_font_size(btn) >= 16, "botón '%s' tiene fuente >= 16 px (%d)" % [btn.text, _font_size(btn)])
	var terminal := panel.get_node_or_null("MarginContainer/VBoxContainer/Terminal")
	check(terminal != null, "el terminal conserva su NodePath")
	if terminal != null:
		check(_font_size(terminal, "normal_font_size") >= 16, "el terminal usa una fuente legible")
	return true

# ============================================
# 6) ENCABEZADOS Y AYUDA BREVE
# ============================================
func test_headers_and_short_help() -> bool:
	await process_frame
	for scene_path in PANEL_SCENES:
		var vp := _make_viewport(Vector2i(1280, 720))
		var panel := _instantiate(scene_path, vp)
		await process_frame
		if panel == null:
			check(false, scene_path + " instanciable")
			continue
		var has_title := false
		var has_help := false
		for lbl in _labels(panel):
			if lbl.theme_type_variation == "StationTitle":
				has_title = true
			if lbl.theme_type_variation == "StationHelp" and lbl.text.strip_edges() != "":
				has_help = true
		check(has_title, scene_path + " tiene encabezado principal")
		check(has_help, scene_path + " tiene ayuda breve")
	return true

# ============================================
# 7) SIN DESBORDES A 1280x720 NI 1920x1080
# ============================================
func test_no_horizontal_overflow() -> bool:
	await process_frame
	for scene_path in PANEL_SCENES:
		for size in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			var vp := _make_viewport(size)
			var panel := _instantiate(scene_path, vp)
			await process_frame
			if panel == null:
				check(false, scene_path + " instanciable en %s" % size)
				continue
			check(panel.get_combined_minimum_size().x <= float(size.x),
				"%s no necesita más ancho que %s (%.0f px)" % [scene_path, size, panel.get_combined_minimum_size().x])
			var overflow: Array = []
			for btn in _buttons(panel):
				if not btn.is_visible_in_tree():
					continue
				var rect: Rect2 = btn.get_global_rect()
				if rect.position.x < -1.0 or rect.end.x > float(size.x) + 1.0:
					overflow.append(btn.text)
			check(overflow.is_empty(), "%s a %s no desborda controles (%s)" % [scene_path, size, str(overflow)])
	return true

# ============================================
# 8) PALETA -> CÓDIGO
# ============================================
func test_actions_to_code() -> bool:
	await process_frame
	var vp := _make_viewport(Vector2i(1280, 720))
	var actions := _instantiate(SCENE_ACTIONS, vp)
	var code_panel := _instantiate(SCENE_CODE, vp)
	await process_frame
	if actions == null or code_panel == null:
		check(false, "paneles de acciones y código instanciables")
		return true
	actions.block_requested.connect(code_panel.add_block)
	var btn := _find_button(actions, func(t: String) -> bool: return t.ends_with("Avanzar()"))
	check(_press(btn), "existe el botón de acción Avanzar()")
	await process_frame
	await process_frame
	check(code_panel.canvas.get_block_count() == 1, "la paleta añadió un bloque al lienzo (%d)" % code_panel.canvas.get_block_count())
	check(code_panel.canvas.generate_code().strip_edges() == "avanzar()",
		"el bloque genera el código correcto ('%s')" % code_panel.canvas.generate_code().strip_edges())
	var btn2 := _find_button(actions, func(t: String) -> bool: return t.ends_with("Girar Derecha()"))
	_press(btn2)
	await process_frame
	await process_frame
	check(code_panel.canvas.get_block_count() == 2, "la segunda acción también llega al lienzo")
	var generated: String = code_panel.canvas.generate_code()
	check(generated.contains("avanzar()") and generated.contains("girar_derecha()"),
		"el lienzo conserva el orden de las acciones")
	return true

# ============================================
# 9) VARIABLES -> CÓDIGO Y LIMPIEZA
# ============================================
func test_variables_to_code_and_clear() -> bool:
	await process_frame
	var vp := _make_viewport(Vector2i(1280, 720))
	var variables := _instantiate(SCENE_VARIABLES, vp)
	var code_panel := _instantiate(SCENE_CODE, vp)
	await process_frame
	if variables == null or code_panel == null:
		check(false, "paneles de variables y código instanciables")
		return true
	variables.block_requested.connect(code_panel.add_block)
	var cleared := {"value": false}
	variables.variables_cleared.connect(func(): cleared["value"] = true)
	var btn := _find_button(variables, func(t: String) -> bool: return t.contains("Crear Variable"))
	check(_press(btn), "existe el botón Crear Variable")
	await process_frame
	await process_frame
	check(code_panel.canvas.get_block_count() == 1, "la variable creada llega al lienzo (%d)" % code_panel.canvas.get_block_count())
	check(code_panel.canvas.generate_code().strip_edges() == "var pasos = 0",
		"la variable genera su declaración ('%s')" % code_panel.canvas.generate_code().strip_edges())
	# Limpiar desde el panel de código
	var clear_requested := {"value": false}
	code_panel.clear_requested.connect(func():
		clear_requested["value"] = true
		code_panel.clear()
		variables.clear_all())
	var btn_clear := _find_button(code_panel, func(t: String) -> bool: return t.contains("Limpiar"))
	check(_press(btn_clear), "existe el botón Limpiar todo")
	await process_frame
	check(clear_requested["value"], "limpiar emite clear_requested")
	check(code_panel.canvas.get_block_count() == 0, "limpiar vacía el lienzo")
	# Limpiar desde el panel de variables
	variables.clear_all()
	await process_frame
	check(cleared["value"], "clear_all emite variables_cleared")
	check(variables.created_vars.is_empty(), "clear_all borra las variables creadas")
	return true

# ============================================
# 10) CONSTRUCTOR DE CONDICIONES
# ============================================
func test_condition_builder() -> bool:
	await process_frame
	var vp := _make_viewport(Vector2i(1280, 720))
	var variables := _instantiate(SCENE_VARIABLES, vp)
	var actions := _instantiate(SCENE_ACTIONS, vp)
	await process_frame
	if variables == null or actions == null:
		check(false, "paneles de variables y acciones instanciables")
		return true
	var conditions: Array = []
	variables.condition_changed.connect(func(c: String): conditions.append(c))
	_press(_find_button(variables, func(t: String) -> bool: return t.contains("Crear Variable")))
	await process_frame
	check(conditions.size() >= 1, "crear una variable actualiza la condición")
	if conditions.is_empty():
		return true
	var condition: String = conditions[conditions.size() - 1]
	check(condition.contains("pasos") and condition.contains("5"),
		"la condición usa la variable y el valor por defecto ('%s')" % condition)
	actions.set_condition(condition)
	_press(_find_button(actions, func(t: String) -> bool: return t.contains("WHILE")))
	await process_frame
	check(actions.lbl_builder_header.text == "while " + condition + ":",
		"el constructor WHILE usa la condición actual ('%s')" % actions.lbl_builder_header.text)
	_press(_find_button(actions, func(t: String) -> bool: return t.contains("Cancelar")))
	await process_frame
	_press(_find_button(actions, func(t: String) -> bool: return t.contains("IF") and not t.contains("WHILE")))
	await process_frame
	check(actions.lbl_builder_header.text == "if " + condition + ":",
		"el constructor IF usa la condición actual ('%s')" % actions.lbl_builder_header.text)
	return true

# ============================================
# 11) GENERACIÓN DE BLOQUES FOR / WHILE / IF / ELSE
# ============================================
func test_container_builders_generate_code() -> bool:
	await process_frame
	var vp := _make_viewport(Vector2i(1280, 720))
	var actions := _instantiate(SCENE_ACTIONS, vp)
	var code_panel := _instantiate(SCENE_CODE, vp)
	await process_frame
	if actions == null or code_panel == null:
		check(false, "paneles de acciones y código instanciables")
		return true
	actions.block_requested.connect(code_panel.add_block)
	# FOR con una orden interna
	_press(_find_button(actions, func(t: String) -> bool: return t.contains("FOR")))
	await process_frame
	_press(_find_button(actions, func(t: String) -> bool: return t.ends_with("Avanzar") and not t.ends_with("Avanzar()")))
	await process_frame
	_press(_find_button(actions, func(t: String) -> bool: return t.contains("Confirmar")))
	await process_frame
	await process_frame
	var code: String = code_panel.canvas.generate_code()
	check(code.contains("for i in range(3):"), "el bucle FOR genera su cabecera ('%s')" % code)
	check(code.contains("avanzar()"), "el bucle FOR contiene la orden interna")
	# ELSE simple
	_press(_find_button(actions, func(t: String) -> bool: return t.contains("ELSE")))
	await process_frame
	await process_frame
	code = code_panel.canvas.generate_code()
	check(code.contains("else:"), "el bloque ELSE se inserta en el lienzo ('%s')" % code)
	# WHILE
	actions.set_condition("pasos < 5")
	_press(_find_button(actions, func(t: String) -> bool: return t.contains("WHILE")))
	await process_frame
	_press(_find_button(actions, func(t: String) -> bool: return t.contains("Confirmar")))
	await process_frame
	await process_frame
	code = code_panel.canvas.generate_code()
	check(code.contains("while pasos < 5:"), "el bucle WHILE genera su cabecera ('%s')" % code)
	return true

# ============================================
# 12) MENÚ SOLO ESCRITORIO CON AYUDA DE CONTROLES
# ============================================
func test_menu_desktop_only() -> bool:
	await process_frame
	var vp := _make_viewport(Vector2i(1280, 720))
	var menu := _instantiate(SCENE_MENU, vp)
	await process_frame
	if menu == null:
		check(false, "menú instanciable")
		return true
	var btn_desktop := menu.get_node_or_null("VBoxContainer/BtnDesktop")
	check(btn_desktop != null, "el menú conserva el botón de escritorio")
	var vr_buttons: Array = []
	for btn in _buttons(menu):
		if btn.text.to_upper().contains("VR") or btn.text.to_lower().contains("realidad virtual"):
			vr_buttons.append(btn.text)
	check(vr_buttons.is_empty(), "el menú no ofrece visor de realidad virtual (%s)" % str(vr_buttons))
	check(_text_has(menu, "WASD"), "el menú explica el movimiento con WASD")
	check(_text_has(menu, "Escape"), "el menú explica cómo salir con Escape")
	check(_text_has(menu, "E"), "el.menu explica la tecla E para programar")
	return true
