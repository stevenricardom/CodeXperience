extends PanelContainer
## Bloque simple arrastrable (Avanzar, Girar, Interactuar, variables, etc.)

var block_type: String = ""
var block_params: Dictionary = {}
var label_node: Label

func setup(type: String, params: Dictionary = {}) -> void:
	block_type = type
	block_params = params
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	
	custom_minimum_size = Vector2(0, 48)
	
	var style = StyleBoxFlat.new()
	style.bg_color = BlockDefinition.get_color(block_type)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)
	
	label_node = Label.new()
	label_node.text = BlockDefinition.get_label(block_type, block_params)
	label_node.add_theme_font_size_override("font_size", 18)
	label_node.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label_node)
	
	var btn_del = Button.new()
	btn_del.text = "✕"
	btn_del.custom_minimum_size = Vector2(36, 36)
	btn_del.add_theme_font_size_override("font_size", 16)
	btn_del.pressed.connect(_remove_self)
	hbox.add_child(btn_del)

func _remove_self() -> void:
	var old_parent = get_parent()
	if old_parent:
		old_parent.remove_child(self)
		if old_parent.has_method("_ensure_placeholder"):
			old_parent.call_deferred("_ensure_placeholder")
		if old_parent.has_signal("blocks_changed"):
			old_parent.blocks_changed.emit()
	queue_free()

func generate_code(indent: int = 0) -> String:
	var tabs = "\t".repeat(indent)
	return tabs + BlockDefinition.generate_code_line(block_type, block_params)

# --- Drag & Drop ---
func _get_drag_data(_at_position: Vector2):
	# Dim the block during drag
	modulate.a = 0.3
	
	# Create drag preview
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
	lbl.text = label_node.text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	preview.add_child(lbl)
	set_drag_preview(preview)
	
	return {"block": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# Restore visibility if drag was cancelled
		modulate.a = 1.0
