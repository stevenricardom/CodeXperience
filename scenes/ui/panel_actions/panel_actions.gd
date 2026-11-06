extends Control
## Panel de Acciones: Paleta de bloques y Constructor de Bucles.

const StationTheme = preload("res://scenes/ui/theme/station_theme.gd")

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

const COL_TRACTOR = Color(0.957, 0.769, 0.420)
const COL_LOOP = Color(0.435, 0.890, 0.690)
const COL_FLOW = Color(0.541, 0.749, 0.965)
const COL_EDIT = Color(0.635, 0.694, 0.769)
const COL_CONFIRM = Color(0.435, 0.890, 0.690)
const COL_CANCEL = Color(0.945, 0.522, 0.510)

func _ready() -> void:
	# Tema compartido: los hijos (incluidos los creados en _build_ui) heredan el estilo.
	theme = StationTheme.get_theme()
	_build_ui()

func set_condition(cond: String) -> void:
	current_condition = cond

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = StationTheme.BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	# === VBOX MAIN (Modo Paleta Normal) ===
	vbox_main = VBoxContainer.new()
	vbox_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_main.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox_main)

	# --- Encabezado ---
	var header_body = _add_card(vbox_main, "🧩 Paleta de Bloques", StationTheme.MINT)
	header_body.get_child(0).theme_type_variation = "StationTitle"
	var header_help = Label.new()
	header_help.text = "Cada botón envía una orden al lienzo de código del tractor."
	header_help.theme_type_variation = "StationHelp"
	header_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_body.add_child(header_help)

	# --- Tractor ---
	var tractor_body = _add_card(vbox_main, "🚜 Acciones del tractor", COL_TRACTOR,
		"Mandos que el tractor entiende directamente.")
	for data in [["▶ Avanzar()", "avanzar"], ["↻ Girar Derecha()", "girar_derecha"],
			["↺ Girar Izquierda()", "girar_izquierda"], ["✋ Interactuar()", "interactuar"]]:
		var btn = _btn(data[0], 50, "StationPrimary")
		var block_type = data[1]
		btn.pressed.connect(func(): block_requested.emit(block_type, {}))
		tractor_body.add_child(btn)

	# --- Bucles ---
	var loop_body = _add_card(vbox_main, "🔁 Bucles", COL_LOOP,
		"Repite una orden varias veces. FOR usa el contador; WHILE usa una condición.")
	var repeat_row = _spinner("−", "3", "+", _repeat_minus, _repeat_plus)
	lbl_repeat_count = repeat_row.get_child(1)
	loop_body.add_child(repeat_row)

	var btn_for = _btn("Armar Bucle FOR", 50, "StationAccent")
	btn_for.pressed.connect(func(): _open_builder("for_loop"))
	loop_body.add_child(btn_for)

	var btn_while = _btn("Armar Bucle WHILE", 50, "StationAccent")
	btn_while.pressed.connect(func(): _open_builder("while_loop"))
	loop_body.add_child(btn_while)

	# --- Condicionales ---
	var cond_body = _add_card(vbox_main, "❓ Condicionales", COL_FLOW,
		"IF y WHILE toman la condición del panel de variables.")
	var btn_if = _btn("Armar IF", 48, "StationGhost")
	btn_if.pressed.connect(func(): _open_builder("if_block"))
	cond_body.add_child(btn_if)

	var btn_else = _btn("Bloque ELSE simple", 48, "StationGhost")
	btn_else.pressed.connect(func(): block_requested.emit("else_block", {}))
	cond_body.add_child(btn_else)

	# --- Ayuda breve ---
	var help_body = _add_card(vbox_main, "💡 Consejo", StationTheme.AMBER)
	var help_lbl = Label.new()
	help_lbl.text = "1) Arma el bloque (FOR, WHILE o IF). 2) Añade las órdenes internas. 3) Confirma: el bloque aparece en el lienzo de código."
	help_lbl.theme_type_variation = "StationHelp"
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_body.add_child(help_lbl)

	# === VBOX BUILDER (Modo Constructor) ===
	vbox_builder = VBoxContainer.new()
	vbox_builder.visible = false
	vbox_builder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_builder.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox_builder)

	var builder_head_body = _add_card(vbox_builder, "🧱 Constructor de Contenedor", COL_LOOP)
	lbl_builder_header = Label.new()
	lbl_builder_header.add_theme_font_size_override("font_size", 20)
	lbl_builder_header.add_theme_color_override("font_color", COL_LOOP)
	lbl_builder_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	builder_head_body.add_child(lbl_builder_header)

	# Consola de vista previa
	var preview_body = _add_card(vbox_builder, "Vista previa del bloque", StationTheme.TEXT_MUTED)
	preview_container = VBoxContainer.new()
	preview_container.add_theme_constant_override("separation", 6)
	preview_body.add_child(preview_container)

	var internal_body = _add_card(vbox_builder, "Agregar Acciones Internas", COL_EDIT,
		"Órdenes que se ejecutarán dentro del bloque.")
	var grid_b = GridContainer.new()
	grid_b.columns = 2
	grid_b.add_theme_constant_override("h_separation", 8)
	grid_b.add_theme_constant_override("v_separation", 8)
	internal_body.add_child(grid_b)

	for data in [["▶ Avanzar", "avanzar", "Avanzar()"], ["↻ Girar Derecha", "girar_derecha", "Girar Derecha()"],
			["↺ Girar Izquierda", "girar_izquierda", "Girar Izquierda()"], ["✋ Interactuar", "interactuar", "Interactuar()"]]:
		var bb = _btn(data[0], 48, "StationGhost")
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var block_t = data[1]
		var label_t = data[2]
		bb.pressed.connect(func(): _add_to_builder(block_t, label_t))
		grid_b.add_child(bb)

	var btn_undo = _btn("⟲ Deshacer último", 48, "StationGhost")
	btn_undo.pressed.connect(_undo_last_builder)
	vbox_builder.add_child(btn_undo)

	var h_conf = HBoxContainer.new()
	h_conf.add_theme_constant_override("separation", 10)
	vbox_builder.add_child(h_conf)

	var btn_cancel = _btn("Cancelar", 50, "StationDanger")
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.pressed.connect(_cancel_builder)
	h_conf.add_child(btn_cancel)

	var btn_conf = _btn("✔ Confirmar e Insertar", 50, "StationPrimary")
	btn_conf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	if builder_children.is_empty():
		var empty = Label.new()
		empty.text = "(sin órdenes internas todavía)"
		empty.theme_type_variation = "StationHelp"
		preview_container.add_child(empty)
		return

	for child_data in builder_children:
		var lbl = Label.new()
		lbl.text = "  ↳ " + child_data["label"]
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", StationTheme.TEXT)
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
## Crea una tarjeta con borde suave y devuelve su cuerpo (VBoxContainer).
func _add_card(parent: Control, title: String, color: Color, help_text: String = "") -> VBoxContainer:
	var card := PanelContainer.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	card.add_child(body)
	parent.add_child(card)

	var lbl = Label.new()
	lbl.text = title
	lbl.theme_type_variation = "StationSection"
	lbl.add_theme_color_override("font_color", color)
	body.add_child(lbl)

	if help_text != "":
		var help = Label.new()
		help.text = help_text
		help.theme_type_variation = "StationHelp"
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(help)

	return body

func _btn(text: String, h: int = 48, variation: String = "") -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = max(h, StationTheme.MIN_TOUCH_HEIGHT)
	b.add_theme_font_size_override("font_size", 18)
	if variation != "":
		b.theme_type_variation = variation
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b

func _spinner(lt: String, ct: String, rt: String, lf: Callable, rf: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var bl = Button.new()
	bl.text = lt
	bl.custom_minimum_size = Vector2(52, 48)
	bl.add_theme_font_size_override("font_size", 20)
	bl.theme_type_variation = "StationGhost"
	bl.pressed.connect(lf)
	row.add_child(bl)
	var lbl = Label.new()
	lbl.text = ct
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.theme_type_variation = "StationValue"
	row.add_child(lbl)
	var br = Button.new()
	br.text = rt
	br.custom_minimum_size = Vector2(52, 48)
	br.add_theme_font_size_override("font_size", 20)
	br.theme_type_variation = "StationGhost"
	br.pressed.connect(rf)
	row.add_child(br)
	return row
