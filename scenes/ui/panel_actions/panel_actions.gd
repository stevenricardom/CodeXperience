extends Control
## Panel de Acciones: Paleta de bloques y Constructor de Bucles.

signal block_requested(type: String, params: Dictionary)

var repeat_count: int = 3
var current_condition: String = "true"
var lbl_repeat_count: Label

var vbox_main: VBoxContainer
var vbox_builder: VBoxContainer
var preview_container: VBoxContainer
var lbl_builder_header: Label
var scroll: ScrollContainer

var builder_type: String = ""
var builder_children: Array = []

const COL_TRACTOR = Color(0.98, 0.82, 0.28, 1)
const COL_LOOP = Color(0.3, 0.6, 1.0, 1)
const COL_FLOW = Color(0.75, 0.45, 0.9, 1)
const COL_EDIT = Color(0.7, 0.7, 0.7, 1)
const COL_CONFIRM = Color(0.3, 0.8, 0.4, 1)
const COL_CANCEL = Color(0.9, 0.3, 0.3, 1)

func _ready() -> void:
	_build_ui()

func set_condition(cond: String) -> void:
	current_condition = cond

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 15)
	add_child(margin)
	
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	
	# === VBOX MAIN (Modo Paleta Normal) ===
	vbox_main = VBoxContainer.new()
	vbox_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_main.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox_main)
	
	vbox_main.add_child(_section("Paleta de Bloques", Color.WHITE, 24))
	
	# --- Tractor ---
	vbox_main.add_child(_section("🚜 Tractor", COL_TRACTOR))
	for data in [["Avanzar()", "avanzar"], ["Girar Derecha()", "girar_derecha"], ["Girar Izquierda()", "girar_izquierda"], ["Interactuar()", "interactuar"]]:
		var btn = _btn(data[0], 50)
		var block_type = data[1]
		btn.pressed.connect(func(): block_requested.emit(block_type, {}))
		vbox_main.add_child(btn)
	
	# --- Bucles ---
	vbox_main.add_child(_section("🔁 Bucles", COL_LOOP))
	
	var repeat_row = _spinner("−", "3", "+", _repeat_minus, _repeat_plus)
	lbl_repeat_count = repeat_row.get_child(1)
	vbox_main.add_child(repeat_row)
	
	var btn_for = _btn("Armar Bucle FOR", 50)
	btn_for.add_theme_color_override("font_color", COL_LOOP)
	btn_for.pressed.connect(func(): _open_builder("for_loop"))
	vbox_main.add_child(btn_for)
	
	var btn_while = _btn("Armar Bucle WHILE", 50)
	btn_while.add_theme_color_override("font_color", COL_FLOW)
	btn_while.pressed.connect(func(): _open_builder("while_loop"))
	vbox_main.add_child(btn_while)
	
	# --- Condicionales ---
	vbox_main.add_child(_section("❓ Condicionales", COL_FLOW))
	
	var btn_if = _btn("Armar IF", 46)
	btn_if.add_theme_color_override("font_color", COL_FLOW)
	btn_if.pressed.connect(func(): _open_builder("if_block"))
	vbox_main.add_child(btn_if)
	
	var btn_else = _btn("Bloque ELSE simple", 46)
	btn_else.add_theme_color_override("font_color", COL_FLOW)
	btn_else.pressed.connect(func(): block_requested.emit("else_block", {}))
	vbox_main.add_child(btn_else)

	# === VBOX BUILDER (Modo Constructor) ===
	vbox_builder = VBoxContainer.new()
	vbox_builder.visible = false
	vbox_builder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_builder.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox_builder)
	
	vbox_builder.add_child(_section("Constructor de Contenedor", COL_LOOP, 24))
	
	# Consola de vista previa
	var p_bg = ColorRect.new()
	p_bg.color = Color(0.12, 0.12, 0.18, 1)
	p_bg.custom_minimum_size.y = 150
	var p_scroll = ScrollContainer.new()
	p_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p_margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]: p_margin.add_theme_constant_override("margin_" + side, 10)
	p_scroll.add_child(p_margin)
	
	var vbox_preview_layout = VBoxContainer.new()
	p_margin.add_child(vbox_preview_layout)
	
	lbl_builder_header = Label.new()
	lbl_builder_header.add_theme_font_size_override("font_size", 18)
	lbl_builder_header.add_theme_color_override("font_color", COL_LOOP)
	vbox_preview_layout.add_child(lbl_builder_header)
	
	preview_container = VBoxContainer.new()
	vbox_preview_layout.add_child(preview_container)
	
	p_bg.add_child(p_scroll)
	vbox_builder.add_child(p_bg)
	
	vbox_builder.add_child(_section("Agregar Acciones Internas:", COL_EDIT, 18))
	
	var grid_b = GridContainer.new()
	grid_b.columns = 2
	grid_b.add_theme_constant_override("h_separation", 8)
	grid_b.add_theme_constant_override("v_separation", 8)
	vbox_builder.add_child(grid_b)
	
	for data in [["Avanzar", "avanzar", "Avanzar()"], ["Girar Der", "girar_derecha", "Girar Derecha()"], ["Girar Izq", "girar_izquierda", "Girar Izquierda()"], ["Interactuar", "interactuar", "Interactuar()"]]:
		var bb = _btn(data[0], 40)
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var block_t = data[1]
		var label_t = data[2]
		bb.pressed.connect(func(): _add_to_builder(block_t, label_t))
		grid_b.add_child(bb)
	
	var btn_undo = _btn("⟲ Deshacer último", 40)
	btn_undo.pressed.connect(_undo_last_builder)
	vbox_builder.add_child(btn_undo)
	
	var h_conf = HBoxContainer.new()
	h_conf.add_theme_constant_override("separation", 10)
	vbox_builder.add_child(h_conf)
	
	var btn_cancel = _btn("Cancelar", 50)
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.add_theme_color_override("font_color", COL_CANCEL)
	btn_cancel.pressed.connect(_cancel_builder)
	h_conf.add_child(btn_cancel)
	
	var btn_conf = _btn("✔ Confirmar e Insertar", 50)
	btn_conf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_conf.add_theme_color_override("font_color", COL_CONFIRM)
	btn_conf.pressed.connect(_confirm_builder)
	h_conf.add_child(btn_conf)

# --- Spinners ---
func _repeat_minus() -> void:
	repeat_count = max(1, repeat_count - 1)
	lbl_repeat_count.text = str(repeat_count)

func _repeat_plus() -> void:
	repeat_count = min(99, repeat_count + 1)
	lbl_repeat_count.text = str(repeat_count)

# --- Métodos del Builder ---
func _open_builder(type: String) -> void:
	builder_type = type
	builder_children.clear()
	
	match type:
		"for_loop":
			lbl_builder_header.text = "for i in range(" + str(repeat_count) + "):"
			lbl_builder_header.add_theme_color_override("font_color", COL_LOOP)
		"while_loop":
			lbl_builder_header.text = "while " + current_condition + ":"
			lbl_builder_header.add_theme_color_override("font_color", COL_FLOW)
		"if_block":
			lbl_builder_header.text = "if " + current_condition + ":"
			lbl_builder_header.add_theme_color_override("font_color", COL_FLOW)
			
	_refresh_builder_preview()
	
	vbox_main.hide()
	vbox_builder.show()
	scroll.scroll_vertical = 0

func _add_to_builder(type: String, label_text: String) -> void:
	builder_children.append({"type": type, "params": {}, "label": label_text})
	_refresh_builder_preview()

func _undo_last_builder() -> void:
	if builder_children.size() > 0:
		builder_children.pop_back()
		_refresh_builder_preview()

func _refresh_builder_preview() -> void:
	for c in preview_container.get_children():
		preview_container.remove_child(c)
		c.queue_free()
		
	for child_data in builder_children:
		var lbl = Label.new()
		lbl.text = "  ↳ " + child_data["label"]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		preview_container.add_child(lbl)

func _confirm_builder() -> void:
	if builder_type == "":
		return
		
	var params = {}
	if builder_type == "for_loop":
		params["count"] = repeat_count
	elif builder_type == "while_loop" or builder_type == "if_block":
		params["condition"] = current_condition
		
	# Preparar los hijos para el BlockCanvas
	var clean_children = []
	for c in builder_children:
		clean_children.append({"type": c["type"], "params": c["params"]})
		
	params["children"] = clean_children
	
	# Guardar tipo y limpiar para evitar doble disparo de XR
	var type_to_emit = builder_type
	builder_type = ""
	builder_children.clear()
	
	# Emitir la señal al canvas
	block_requested.emit(type_to_emit, params)
	
	vbox_builder.hide()
	vbox_main.show()
	scroll.scroll_vertical = 0

func _cancel_builder() -> void:
	builder_type = ""
	builder_children.clear()
	vbox_builder.hide()
	vbox_main.show()
	scroll.scroll_vertical = 0

# --- Helpers ---
func _section(text: String, color: Color, font_size: int = 20) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _btn(text: String, h: int = 44) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = h
	b.add_theme_font_size_override("font_size", 18)
	return b

func _spinner(lt: String, ct: String, rt: String, lf: Callable, rf: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var bl = Button.new()
	bl.text = lt
	bl.custom_minimum_size = Vector2(50, 44)
	bl.add_theme_font_size_override("font_size", 20)
	bl.pressed.connect(lf)
	row.add_child(bl)
	var lbl = Label.new()
	lbl.text = ct
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 24)
	row.add_child(lbl)
	var br = Button.new()
	br.text = rt
	br.custom_minimum_size = Vector2(50, 44)
	br.add_theme_font_size_override("font_size", 20)
	br.pressed.connect(rf)
	row.add_child(br)
	return row
