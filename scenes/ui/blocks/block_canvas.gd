extends ScrollContainer
## Canvas principal donde se apilan y organizan los bloques.
## Contiene un DropZone como zona de drop principal.

const CodeBlockScript = preload("res://scenes/ui/blocks/code_block.gd")
const ContainerBlockScript = preload("res://scenes/ui/blocks/container_block.gd")
const DropZoneScript = preload("res://scenes/ui/blocks/drop_zone.gd")

signal code_changed()

var drop_zone: VBoxContainer

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Fondo oscuro
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.08, 1)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", bg_style)
	
	# Crear la DropZone principal
	drop_zone = VBoxContainer.new()
	drop_zone.set_script(DropZoneScript)
	drop_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drop_zone.add_theme_constant_override("separation", 6)
	
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(drop_zone)
	add_child(margin)
	
	drop_zone.blocks_changed.connect(func(): code_changed.emit())

func add_block(type: String, params: Dictionary = {}) -> void:
	var block: Control
	
	if BlockDefinition.is_container(type):
		block = VBoxContainer.new()
		block.set_script(ContainerBlockScript)
		block.setup(type, params)
		
		# Si los params incluyen hijos pre-armados, agregarlos dentro del contenedor
		var children_data: Array = params.get("children", [])
		if not children_data.is_empty():
			var body_zone = block.get_body()
			if body_zone:
				# Limpiar placeholder
				for c in body_zone.get_children():
					if c.is_in_group("block_placeholder"):
						body_zone.remove_child(c)
						c.queue_free()
				# Agregar hijos
				for child_data in children_data:
					var child_type: String = child_data.get("type", "")
					var child_params: Dictionary = child_data.get("params", {})
					var child_block: Control
					if BlockDefinition.is_container(child_type):
						child_block = VBoxContainer.new()
						child_block.set_script(ContainerBlockScript)
						child_block.setup(child_type, child_params)
					else:
						child_block = PanelContainer.new()
						child_block.set_script(CodeBlockScript)
						child_block.setup(child_type, child_params)
					body_zone.add_child(child_block)
	else:
		block = PanelContainer.new()
		block.set_script(CodeBlockScript)
		block.setup(type, params)
	
	drop_zone.add_block_node(block)
	
	# Auto-scroll al final
	await get_tree().process_frame
	scroll_vertical = int(drop_zone.size.y)

func remove_last_block() -> void:
	drop_zone.remove_last_block()

func clear_all() -> void:
	drop_zone.clear_all()

func generate_code() -> String:
	var code: String = ""
	var blocks = drop_zone.get_block_children()
	
	for block in blocks:
		if block.has_method("generate_code"):
			code += block.generate_code(0) + "\n"
	
	return code.strip_edges(false, true)

func get_block_count() -> int:
	return drop_zone.get_block_children().size()
