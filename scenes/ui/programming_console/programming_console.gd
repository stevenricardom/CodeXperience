extends Control

signal code_execution_requested(codigo_texto: String)
signal execution_stopped()

# ============================================
# REFERENCIAS UI (se asignan en _ready)
# ============================================
var code_edit: CodeEdit
var terminal: RichTextLabel

# --- Repeat block ---
var lbl_repeat_count: Label
var repeat_count: int = 3

# --- Variable Workshop ---
var lbl_var_name: Label
var lbl_var_type: Label
var lbl_var_value: Label
var created_vars_container: VBoxContainer

var var_names = ["pasos", "vueltas", "total", "distancia", "terminado", "activo", "contador", "turno"]
var var_name_index: int = 0
var var_types = ["Número", "Booleano", "Texto"]
var var_type_index: int = 0
var var_value_int: int = 0
var var_value_bool: bool = true
var var_value_string: String = "hola"
var created_vars: Dictionary = {} # name -> {type, value, gdtype}

# --- Condition Builder ---
var lbl_cond_var: Label
var lbl_cond_op: Label
var lbl_cond_val: Label
var lbl_cond_preview: Label
var cond_var_index: int = 0
var operators = ["<", ">", "==", "!=", "<=", ">="]
var cond_op_index: int = 0
var cond_value: int = 5

# --- Code state ---
var indent_level: int = 0

# ============================================
# COLORES DEL TEMA
# ============================================
const COL_BG = Color(0.08, 0.08, 0.1, 1)
const COL_PANEL = Color(0.13, 0.13, 0.16, 1)
const COL_TRACTOR = Color(0.98, 0.82, 0.28, 1)
const COL_LOOP = Color(0.4, 0.7, 1, 1)
const COL_FLOW = Color(0.85, 0.55, 0.95, 1)
const COL_VAR = Color(0.53, 0.91, 0.53, 1)
const COL_COND = Color(1, 0.6, 0.4, 1)
const COL_EDIT = Color(0.7, 0.7, 0.7, 1)
const COL_BTN_BG = Color(0.18, 0.18, 0.22, 1)
const COL_SPINNER_BG = Color(0.15, 0.15, 0.2, 1)

func _ready() -> void:
	_build_ui()

# ============================================
# CONSTRUCCIÓN PROGRAMÁTICA DE LA UI
# ============================================
func _build_ui() -> void:
	# Fondo
	var bg = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Margen principal
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	# Layout principal de 4 columnas
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	
	# === COLUMNA 1: Acciones + Repeticiones ===
	var left_panel = _build_left_panel()
	left_panel.custom_minimum_size.x = 310
	hbox.add_child(left_panel)
	
	# Separador visual
	hbox.add_child(_make_vsep())
	
	# === COLUMNA 2: Código + Terminal ===
	var center_panel = _build_center_panel()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_stretch_ratio = 1.8
	hbox.add_child(center_panel)
	
	# Separador visual
	hbox.add_child(_make_vsep())
	
	# === COLUMNA 3: Taller de Variables ===
	var right_panel = _build_right_panel()
	right_panel.custom_minimum_size.x = 320
	hbox.add_child(right_panel)
	
	# Separador visual
	hbox.add_child(_make_vsep())
	
	# === COLUMNA 4: Cámara ===
	var camera_panel = _build_camera_panel()
	camera_panel.custom_minimum_size.x = 280
	hbox.add_child(camera_panel)
	
	terminal.bbcode_enabled = true
	mostrar_mensaje("Esperando comandos...")

func _make_vsep() -> VSeparator:
	var sep = VSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	return sep

# ============================================
# COLUMNA 1: ACCIONES + REPETICIONES
# ============================================
func _build_left_panel() -> VBoxContainer:
	var panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	
	# Scroll para todo el panel
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)
	
	# --- Funciones del Tractor ---
	vbox.add_child(_make_section_label("🚜 Tractor", COL_TRACTOR))
	
	var actions = [
		["Avanzar()", "_cmd_avanzar"],
		["Girar Derecha()", "_cmd_girar_der"],
		["Girar Izquierda()", "_cmd_girar_izq"],
		["Interactuar()", "_cmd_interactuar"],
	]
	for a in actions:
		var btn = _make_button(a[0], 38)
		btn.pressed.connect(Callable(self, a[1]))
		vbox.add_child(btn)
	
	# --- Repeticiones inteligentes ---
	vbox.add_child(_make_section_label("🔁 Repetir N veces", COL_LOOP))
	
	# Control de repeticiones [−] 3 [+]
	var repeat_row = _make_spinner_row("−", "3", "+", "_repeat_minus", "_repeat_plus")
	lbl_repeat_count = repeat_row.get_child(1)
	vbox.add_child(repeat_row)
	
	var repeat_actions = [
		["↺ Repetir Avanzar()", "_repeat_avanzar"],
		["↺ Repetir Girar Der.()", "_repeat_girar_der"],
		["↺ Repetir Girar Izq.()", "_repeat_girar_izq"],
	]
	for a in repeat_actions:
		var btn = _make_button(a[0], 36)
		btn.pressed.connect(Callable(self, a[1]))
		vbox.add_child(btn)
	
	# --- Control de Flujo ---
	vbox.add_child(_make_section_label("🔀 Condiciones", COL_FLOW))
	
	var flow_actions = [
		["Si [condición]", "_cmd_if"],
		["Elif [condición]", "_cmd_elif"],
		["Sino (else)", "_cmd_else"],
		["Mientras [condición]", "_cmd_while"],
		["return", "_cmd_return"],
	]
	for a in flow_actions:
		var btn = _make_button(a[0], 36)
		btn.pressed.connect(Callable(self, a[1]))
		vbox.add_child(btn)
	
	# --- Edición ---
	vbox.add_child(_make_section_label("✏️ Edición", COL_EDIT))
	
	var edit_grid = GridContainer.new()
	edit_grid.columns = 2
	edit_grid.add_theme_constant_override("h_separation", 6)
	edit_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(edit_grid)
	
	var edit_btns = [
		["→ Indentar", "_edit_indent"],
		["← Desindentar", "_edit_unindent"],
		["↵ Nueva línea", "_edit_newline"],
		["🗑 Borrar línea", "_edit_delete"],
	]
	for a in edit_btns:
		var btn = _make_button(a[0], 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(Callable(self, a[1]))
		edit_grid.add_child(btn)
	
	return panel

# ============================================
# COLUMNA 2: CÓDIGO + TERMINAL
# ============================================
func _build_center_panel() -> VBoxContainer:
	var panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	
	# Toolbar
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	panel.add_child(toolbar)
	
	var btn_exec = _make_button("▶ Ejecutar", 44)
	btn_exec.add_theme_color_override("font_color", Color.GREEN)
	btn_exec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_exec.pressed.connect(_on_btn_ejecutar_pressed)
	toolbar.add_child(btn_exec)
	
	var btn_clear = _make_button("✖ Limpiar", 44)
	btn_clear.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	btn_clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_clear.pressed.connect(_on_btn_limpiar_pressed)
	toolbar.add_child(btn_clear)
	
	panel.add_child(_make_section_label("📝 Tu Código:", Color.WHITE))
	
	# CodeEdit (solo lectura)
	code_edit = CodeEdit.new()
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_edit.editable = false
	code_edit.gutters_draw_line_numbers = true
	code_edit.add_theme_font_size_override("font_size", 20)
	panel.add_child(code_edit)
	
	panel.add_child(_make_section_label("💻 Terminal:", Color.WHITE))
	
	# Terminal
	terminal = RichTextLabel.new()
	terminal.custom_minimum_size.y = 100
	terminal.add_theme_font_size_override("normal_font_size", 16)
	terminal.bbcode_enabled = true
	panel.add_child(terminal)
	
	return panel

# ============================================
# COLUMNA 3: TALLER DE VARIABLES + CONDICIÓN
# ============================================
func _build_right_panel() -> VBoxContainer:
	var panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)
	
	# === TALLER DE VARIABLES ===
	vbox.add_child(_make_section_label("🔧 Taller de Variables", COL_VAR))
	
	# Nombre
	vbox.add_child(_make_mini_label("Nombre:"))
	var name_row = _make_spinner_row("◀", var_names[0], "▶", "_var_name_left", "_var_name_right")
	lbl_var_name = name_row.get_child(1)
	vbox.add_child(name_row)
	
	# Tipo
	vbox.add_child(_make_mini_label("Tipo:"))
	var type_row = _make_spinner_row("◀", var_types[0], "▶", "_var_type_left", "_var_type_right")
	lbl_var_type = type_row.get_child(1)
	vbox.add_child(type_row)
	
	# Valor
	vbox.add_child(_make_mini_label("Valor:"))
	var value_row = _make_spinner_row("−", "0", "+", "_var_value_minus", "_var_value_plus")
	lbl_var_value = value_row.get_child(1)
	vbox.add_child(value_row)
	
	# Botón CREAR
	var btn_create = _make_button("✨ CREAR VARIABLE", 48)
	btn_create.add_theme_color_override("font_color", COL_VAR)
	btn_create.pressed.connect(_create_variable)
	vbox.add_child(btn_create)
	
	# Lista de variables creadas
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_section_label("📋 Mis Variables", COL_VAR))
	
	created_vars_container = VBoxContainer.new()
	created_vars_container.add_theme_constant_override("separation", 4)
	vbox.add_child(created_vars_container)
	
	var lbl_empty = Label.new()
	lbl_empty.name = "LblEmpty"
	lbl_empty.text = "(vacío - crea una variable)"
	lbl_empty.add_theme_font_size_override("font_size", 14)
	lbl_empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	lbl_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	created_vars_container.add_child(lbl_empty)
	
	# === CONSTRUCTOR DE CONDICIÓN ===
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_section_label("🎯 Condición Actual", COL_COND))
	
	# Vista previa de la condición
	lbl_cond_preview = Label.new()
	lbl_cond_preview.text = "⚠ Crea una variable primero"
	lbl_cond_preview.add_theme_font_size_override("font_size", 20)
	lbl_cond_preview.add_theme_color_override("font_color", COL_COND)
	lbl_cond_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_cond_preview)
	
	# Variable de la condición
	vbox.add_child(_make_mini_label("Variable:"))
	var cond_var_row = _make_spinner_row("◀", "---", "▶", "_cond_var_left", "_cond_var_right")
	lbl_cond_var = cond_var_row.get_child(1)
	vbox.add_child(cond_var_row)
	
	# Operador
	vbox.add_child(_make_mini_label("Comparar:"))
	var cond_op_row = _make_spinner_row("◀", operators[0], "▶", "_cond_op_left", "_cond_op_right")
	lbl_cond_op = cond_op_row.get_child(1)
	vbox.add_child(cond_op_row)
	
	# Valor de comparación
	vbox.add_child(_make_mini_label("Con valor:"))
	var cond_val_row = _make_spinner_row("−", "5", "+", "_cond_val_minus", "_cond_val_plus")
	lbl_cond_val = cond_val_row.get_child(1)
	vbox.add_child(cond_val_row)
	
	return panel

# ============================================
# COLUMNA 4: CÁMARA
# ============================================
func _build_camera_panel() -> VBoxContainer:
	var panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	
	panel.add_child(_make_section_label("📹 Vista del Campo", Color.WHITE))
	
	var svc = SubViewportContainer.new()
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.stretch = true
	panel.add_child(svc)
	
	var sv = SubViewport.new()
	sv.handle_input_locally = false
	sv.size = Vector2i(400, 300)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)
	
	var cam = Camera3D.new()
	cam.transform = Transform3D(Basis(), Vector3(0, 15, 0))
	cam.look_at(Vector3.ZERO)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 15.0
	sv.add_child(cam)
	
	return panel

# ============================================
# WIDGETS REUTILIZABLES
# ============================================
func _make_section_label(text: String, color: Color = Color.WHITE) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_mini_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	return lbl

func _make_button(text: String, height: int = 40) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size.y = height
	btn.add_theme_font_size_override("font_size", 16)
	return btn

func _make_spinner_row(left_text: String, center_text: String, right_text: String, left_fn: String, right_fn: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	
	var btn_left = Button.new()
	btn_left.text = left_text
	btn_left.custom_minimum_size = Vector2(44, 40)
	btn_left.add_theme_font_size_override("font_size", 18)
	btn_left.pressed.connect(Callable(self, left_fn))
	row.add_child(btn_left)
	
	var lbl = Label.new()
	lbl.text = center_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(lbl)
	
	var btn_right = Button.new()
	btn_right.text = right_text
	btn_right.custom_minimum_size = Vector2(44, 40)
	btn_right.add_theme_font_size_override("font_size", 18)
	btn_right.pressed.connect(Callable(self, right_fn))
	row.add_child(btn_right)
	
	return row

# ============================================
# FUNCIONES DE CÓDIGO
# ============================================
func _get_indent() -> String:
	return "\t".repeat(indent_level)

func _add_line(text: String) -> void:
	code_edit.text += _get_indent() + text + "\n"
	code_edit.scroll_vertical = code_edit.get_line_count()

# --- Comandos del tractor ---
func _cmd_avanzar() -> void:
	_add_line("avanzar()")

func _cmd_girar_der() -> void:
	_add_line("girar_derecha()")

func _cmd_girar_izq() -> void:
	_add_line("girar_izquierda()")

func _cmd_interactuar() -> void:
	_add_line("interactuar()")

# --- Repeticiones inteligentes ---
func _repeat_minus() -> void:
	repeat_count = max(1, repeat_count - 1)
	lbl_repeat_count.text = str(repeat_count)

func _repeat_plus() -> void:
	repeat_count = min(99, repeat_count + 1)
	lbl_repeat_count.text = str(repeat_count)

func _repeat_avanzar() -> void:
	_add_line("for i in range(" + str(repeat_count) + "):")
	indent_level += 1
	_add_line("avanzar()")
	indent_level -= 1

func _repeat_girar_der() -> void:
	_add_line("for i in range(" + str(repeat_count) + "):")
	indent_level += 1
	_add_line("girar_derecha()")
	indent_level -= 1

func _repeat_girar_izq() -> void:
	_add_line("for i in range(" + str(repeat_count) + "):")
	indent_level += 1
	_add_line("girar_izquierda()")
	indent_level -= 1

# --- Control de Flujo ---
func _get_condition_string() -> String:
	if created_vars.is_empty():
		return "true"
	var keys = created_vars.keys()
	var var_name = keys[cond_var_index % keys.size()]
	return var_name + " " + operators[cond_op_index] + " " + str(cond_value)

func _cmd_if() -> void:
	_add_line("if " + _get_condition_string() + ":")
	indent_level += 1

func _cmd_elif() -> void:
	if indent_level > 0:
		indent_level -= 1
	_add_line("elif " + _get_condition_string() + ":")
	indent_level += 1

func _cmd_else() -> void:
	if indent_level > 0:
		indent_level -= 1
	_add_line("else:")
	indent_level += 1

func _cmd_while() -> void:
	_add_line("while " + _get_condition_string() + ":")
	indent_level += 1

func _cmd_return() -> void:
	_add_line("return")

# --- Edición ---
func _edit_indent() -> void:
	indent_level += 1
	mostrar_mensaje("Nivel de indentación: " + str(indent_level))

func _edit_unindent() -> void:
	if indent_level > 0:
		indent_level -= 1
	mostrar_mensaje("Nivel de indentación: " + str(indent_level))

func _edit_newline() -> void:
	code_edit.text += "\n"

func _edit_delete() -> void:
	var lines = code_edit.text.split("\n")
	# Buscar la última línea con contenido
	var idx = lines.size() - 1
	while idx >= 0 and lines[idx].strip_edges().is_empty():
		idx -= 1
	if idx >= 0:
		var removed = lines[idx].strip_edges()
		# Si borramos un bloque que terminaba en ":", reducir indent
		if removed.ends_with(":") and indent_level > 0:
			indent_level -= 1
		lines.remove_at(idx)
		code_edit.text = "\n".join(lines)

# ============================================
# TALLER DE VARIABLES
# ============================================
func _var_name_left() -> void:
	var_name_index = (var_name_index - 1 + var_names.size()) % var_names.size()
	lbl_var_name.text = var_names[var_name_index]

func _var_name_right() -> void:
	var_name_index = (var_name_index + 1) % var_names.size()
	lbl_var_name.text = var_names[var_name_index]

func _var_type_left() -> void:
	var_type_index = (var_type_index - 1 + var_types.size()) % var_types.size()
	lbl_var_type.text = var_types[var_type_index]
	_update_var_value_display()

func _var_type_right() -> void:
	var_type_index = (var_type_index + 1) % var_types.size()
	lbl_var_type.text = var_types[var_type_index]
	_update_var_value_display()

func _var_value_minus() -> void:
	match var_type_index:
		0: # Número
			var_value_int -= 1
		1: # Booleano
			var_value_bool = not var_value_bool
		2: # Texto
			pass
	_update_var_value_display()

func _var_value_plus() -> void:
	match var_type_index:
		0: # Número
			var_value_int += 1
		1: # Booleano
			var_value_bool = not var_value_bool
		2: # Texto
			var options = ["hola", "mundo", "si", "no", "listo", "error"]
			var idx = options.find(var_value_string)
			var_value_string = options[(idx + 1) % options.size()]
	_update_var_value_display()

func _update_var_value_display() -> void:
	match var_type_index:
		0: lbl_var_value.text = str(var_value_int)
		1: lbl_var_value.text = str(var_value_bool).to_lower()
		2: lbl_var_value.text = "\"" + var_value_string + "\""

func _create_variable() -> void:
	var vname = var_names[var_name_index]
	
	# No permitir duplicados
	if vname in created_vars:
		mostrar_error("La variable '" + vname + "' ya existe.")
		return
	
	var value_str = ""
	var gdtype = ""
	match var_type_index:
		0:
			value_str = str(var_value_int)
			gdtype = "int"
		1:
			value_str = str(var_value_bool).to_lower()
			gdtype = "bool"
		2:
			value_str = "\"" + var_value_string + "\""
			gdtype = "string"
	
	created_vars[vname] = {"type": var_types[var_type_index], "value": value_str, "gdtype": gdtype}
	
	# Insertar en el código
	_add_line("var " + vname + " = " + value_str)
	
	# Actualizar la lista visual de variables
	_refresh_created_vars_ui()
	_update_condition_preview()
	
	mostrar_exito("Variable '" + vname + "' creada con valor " + value_str)

func _refresh_created_vars_ui() -> void:
	# Limpiar el contenedor
	for child in created_vars_container.get_children():
		child.queue_free()
	
	if created_vars.is_empty():
		var lbl = Label.new()
		lbl.text = "(vacío)"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		created_vars_container.add_child(lbl)
		return
	
	for vname in created_vars:
		var info = created_vars[vname]
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		
		# Botón para insertar el nombre de la variable en el código
		var btn = Button.new()
		btn.text = "📌 " + vname + " (" + info.type + " = " + info.value + ")"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 36
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_insert_var_name.bind(vname))
		hbox.add_child(btn)
		
		# Botón para modificar el valor (+= 1)
		if info.gdtype == "int":
			var btn_inc = Button.new()
			btn_inc.text = "+1"
			btn_inc.custom_minimum_size = Vector2(40, 36)
			btn_inc.add_theme_font_size_override("font_size", 14)
			btn_inc.pressed.connect(_insert_var_increment.bind(vname))
			hbox.add_child(btn_inc)
		
		created_vars_container.add_child(hbox)

func _insert_var_name(vname: String) -> void:
	# Insertar el nombre de la variable en la última línea o como nueva línea
	code_edit.text += vname
	mostrar_mensaje("Variable '" + vname + "' insertada.")

func _insert_var_increment(vname: String) -> void:
	_add_line(vname + " += 1")

# ============================================
# CONSTRUCTOR DE CONDICIÓN
# ============================================
func _cond_var_left() -> void:
	if created_vars.is_empty(): return
	cond_var_index = (cond_var_index - 1 + created_vars.size()) % created_vars.size()
	_update_condition_preview()

func _cond_var_right() -> void:
	if created_vars.is_empty(): return
	cond_var_index = (cond_var_index + 1) % created_vars.size()
	_update_condition_preview()

func _cond_op_left() -> void:
	cond_op_index = (cond_op_index - 1 + operators.size()) % operators.size()
	_update_condition_preview()

func _cond_op_right() -> void:
	cond_op_index = (cond_op_index + 1) % operators.size()
	_update_condition_preview()

func _cond_val_minus() -> void:
	cond_value -= 1
	_update_condition_preview()

func _cond_val_plus() -> void:
	cond_value += 1
	_update_condition_preview()

func _update_condition_preview() -> void:
	if created_vars.is_empty():
		lbl_cond_preview.text = "⚠ Crea una variable primero"
		lbl_cond_var.text = "---"
		lbl_cond_op.text = operators[cond_op_index]
		lbl_cond_val.text = str(cond_value)
		return
	
	var keys = created_vars.keys()
	var idx = cond_var_index % keys.size()
	var vname = keys[idx]
	
	lbl_cond_var.text = vname
	lbl_cond_op.text = operators[cond_op_index]
	lbl_cond_val.text = str(cond_value)
	lbl_cond_preview.text = vname + " " + operators[cond_op_index] + " " + str(cond_value)

# ============================================
# EJECUCIÓN Y LIMPIEZA
# ============================================
func _on_btn_ejecutar_pressed() -> void:
	var code = code_edit.text.strip_edges()
	if code.is_empty():
		mostrar_error("El código está vacío. Añade bloques primero.")
		return
	mostrar_exito("Ejecutando código...")
	code_execution_requested.emit(code)

func _on_btn_limpiar_pressed() -> void:
	code_edit.text = ""
	indent_level = 0
	created_vars.clear()
	cond_var_index = 0
	_refresh_created_vars_ui()
	_update_condition_preview()
	mostrar_mensaje("Código y variables limpiados.")
	execution_stopped.emit()

# --- Terminal ---
func mostrar_error(msg: String) -> void:
	terminal.text = "[color=red]🚫 Error:[/color] " + msg

func mostrar_exito(msg: String) -> void:
	terminal.text = "[color=green]✅ Éxito:[/color] " + msg

func mostrar_mensaje(msg: String) -> void:
	terminal.text = "[color=gray]" + msg + "[/color]"
