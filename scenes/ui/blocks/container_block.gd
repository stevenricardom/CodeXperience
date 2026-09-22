extends VBoxContainer
## Bloque contenedor en forma de "C" (for, while, if, elif, else).
## Tiene un header coloreado, un cuerpo (DropZone) para bloques hijos, y un footer.

const DropZoneScript = preload("res://scenes/ui/blocks/drop_zone.gd")

var block_type: String = ""
var block_params: Dictionary = {}
var header: PanelContainer
var body: VBoxContainer  # DropZone
var footer: PanelContainer
var label_node: Label
var lbl_param: Label

func setup(type: String, params: Dictionary = {}) -> void:
	block_type = type
	block_params = params
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	
	add_theme_constant_override("separation", 0)
	var color: Color = BlockDefinition.get_color(block_type)
	
	# ============ HEADER ============
	header = PanelContainer.new()
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = color
	h_style.corner_radius_top_left = 8
	h_style.corner_radius_top_right = 8
	h_style.content_margin_left = 14
	h_style.content_margin_right = 8
	h_style.content_margin_top = 6
	h_style.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", h_style)
	header.custom_minimum_size.y = 48
	add_child(header)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	header.add_child(hbox)
	
	label_node = Label.new()
	label_node.add_theme_font_size_override("font_size", 18)
	label_node.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	hbox.add_child(label_node)
	
	# Controles inline según tipo de bloque
	match block_type:
		"for_loop":
			label_node.text = "for i in range("
			var count: int = block_params.get("count", 3)
			
			var btn_minus = Button.new()
			btn_minus.text = "−"
			btn_minus.custom_minimum_size = Vector2(40, 36)
			btn_minus.add_theme_font_size_override("font_size", 20)
			btn_minus.pressed.connect(func(): _change_count(-1))
			hbox.add_child(btn_minus)
			
			lbl_param = Label.new()
			lbl_param.text = str(count)
			lbl_param.add_theme_font_size_override("font_size", 22)
			lbl_param.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
			lbl_param.custom_minimum_size.x = 30
			lbl_param.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hbox.add_child(lbl_param)
			
			var btn_plus = Button.new()
			btn_plus.text = "+"
			btn_plus.custom_minimum_size = Vector2(40, 36)
			btn_plus.add_theme_font_size_override("font_size", 20)
			btn_plus.pressed.connect(func(): _change_count(1))
			hbox.add_child(btn_plus)
			
			var lbl_close = Label.new()
			lbl_close.text = "):"
			lbl_close.add_theme_font_size_override("font_size", 18)
			lbl_close.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
			hbox.add_child(lbl_close)
		
		"while_loop":
			label_node.text = "while " + str(block_params.get("condition", "true")) + ":"
		"if_block":
			label_node.text = "if " + str(block_params.get("condition", "true")) + ":"
		"elif_block":
			label_node.text = "elif " + str(block_params.get("condition", "true")) + ":"
		"else_block":
			label_node.text = "else:"
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	var btn_del = Button.new()
	btn_del.text = "✕"
	btn_del.custom_minimum_size = Vector2(36, 36)
	btn_del.add_theme_font_size_override("font_size", 16)
	btn_del.pressed.connect(_remove_self)
	hbox.add_child(btn_del)
	
	# Hacer el header arrastrable (arrastra el contenedor entero)
	header.set_drag_forwarding(
		func(_at_position): return _get_container_drag_data(),
		func(_at_position, _data): return false,
		func(_at_position, _data): pass
	)
	
	# ============ BODY (C shape) ============
	var body_wrapper = HBoxContainer.new()
	body_wrapper.add_theme_constant_override("separation", 0)
	add_child(body_wrapper)
	
	# Barra lateral izquierda (parte de la C)
	var side_bar = ColorRect.new()
	side_bar.color = color
	side_bar.custom_minimum_size.x = 10
	body_wrapper.add_child(side_bar)
	
	# Contenedor interior con margen
	var body_margin = MarginContainer.new()
	body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 6)
	body_margin.add_theme_constant_override("margin_right", 4)
	body_margin.add_theme_constant_override("margin_top", 6)
	body_margin.add_theme_constant_override("margin_bottom", 6)
	body_wrapper.add_child(body_margin)
	
	var body_bg = PanelContainer.new()
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.6)
	b_style.corner_radius_top_left = 4
	b_style.corner_radius_top_right = 4
	b_style.corner_radius_bottom_left = 4
	b_style.corner_radius_bottom_right = 4
	b_style.content_margin_left = 6
	b_style.content_margin_right = 6
	b_style.content_margin_top = 6
	b_style.content_margin_bottom = 6
	body_bg.add_theme_stylebox_override("panel", b_style)
	body_bg.custom_minimum_size.y = 50
	body_margin.add_child(body_bg)
	
	# DropZone para bloques hijos
	body = VBoxContainer.new()
	body.set_script(DropZoneScript)
	body.add_theme_constant_override("separation", 4)
	body_bg.add_child(body)
	
	# ============ FOOTER ============
	footer = PanelContainer.new()
	var f_style = StyleBoxFlat.new()
	f_style.bg_color = color
	f_style.corner_radius_bottom_left = 8
	f_style.corner_radius_bottom_right = 8
	f_style.content_margin_top = 5
	f_style.content_margin_bottom = 5
	f_style.content_margin_left = 14
	footer.add_theme_stylebox_override("panel", f_style)
	footer.custom_minimum_size.y = 14
	add_child(footer)

func _change_count(delta: int) -> void:
	var current: int = block_params.get("count", 3)
	block_params["count"] = max(1, current + delta)
	if lbl_param:
		lbl_param.text = str(block_params["count"])

func update_condition(cond: String) -> void:
	block_params["condition"] = cond
	if label_node:
		match block_type:
			"while_loop": label_node.text = "while " + cond + ":"
			"if_block": label_node.text = "if " + cond + ":"
			"elif_block": label_node.text = "elif " + cond + ":"

func _remove_self() -> void:
	var old_parent = get_parent()
	if old_parent:
		old_parent.remove_child(self)
		if old_parent.has_method("_ensure_placeholder"):
			old_parent.call_deferred("_ensure_placeholder")
		if old_parent.has_signal("blocks_changed"):
			old_parent.blocks_changed.emit()
	queue_free()

func get_body() -> VBoxContainer:
	return body

func generate_code(indent: int = 0) -> String:
	var tabs: String = "\t".repeat(indent)
	var header_code: String = BlockDefinition.generate_code_line(block_type, block_params)
	var code: String = tabs + header_code + "\n"
	
	var has_children: bool = false
	if body:
		for child in body.get_children():
			if child.is_in_group("block_placeholder"):
				continue
			if child.has_method("generate_code"):
				code += child.generate_code(indent + 1) + "\n"
				has_children = true
	
	if not has_children:
		code += tabs + "\tpass\n"
	
	return code.strip_edges(false, true)

# --- Drag (desde el header) ---
func _get_container_drag_data():
	modulate.a = 0.3
	
	var preview = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = BlockDefinition.get_color(block_type)
	style.bg_color.a = 0.8
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	preview.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = label_node.text if label_node else block_type
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	preview.add_child(lbl)
	set_drag_preview(preview)
	
	return {"block": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
