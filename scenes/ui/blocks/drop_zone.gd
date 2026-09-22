extends VBoxContainer
## Zona que acepta drops de bloques. Usada por BlockCanvas y ContainerBlock.

signal blocks_changed()

var placeholder_label: Label = null

func _ready() -> void:
	_ensure_placeholder()

func _ensure_placeholder() -> void:
	# Contar hijos reales (no placeholders)
	var real_children: int = 0
	for c in get_children():
		if not c.is_in_group("block_placeholder"):
			real_children += 1
	
	if real_children == 0:
		if placeholder_label == null or not is_instance_valid(placeholder_label):
			placeholder_label = Label.new()
			placeholder_label.text = "  Arrastra bloques aquí  "
			placeholder_label.add_theme_font_size_override("font_size", 14)
			placeholder_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
			placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder_label.custom_minimum_size.y = 40
			placeholder_label.add_to_group("block_placeholder")
			add_child(placeholder_label)
	else:
		_remove_placeholder()

func _remove_placeholder() -> void:
	if placeholder_label and is_instance_valid(placeholder_label):
		placeholder_label.queue_free()
		placeholder_label = null
	# Also clean any other placeholders
	for c in get_children():
		if c.is_in_group("block_placeholder"):
			c.queue_free()

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not data is Dictionary: return false
	if not data.has("block"): return false
	# Don't allow dropping a container inside itself
	var block = data["block"]
	if block == self or _is_ancestor_of_block(block): return false
	return true

func _is_ancestor_of_block(block: Node) -> bool:
	var p = self
	while p:
		if p == block: return true
		p = p.get_parent()
	return false

func _drop_data(at_position: Vector2, data) -> void:
	var block = data["block"]
	
	# Remove from previous parent
	var old_parent = block.get_parent()
	if old_parent:
		old_parent.remove_child(block)
		# Notify old parent if it's a drop zone
		if old_parent.has_method("_ensure_placeholder"):
			old_parent.call_deferred("_ensure_placeholder")
	
	# Find insertion index based on y position
	var insert_idx: int = _get_insert_index(at_position)
	
	_remove_placeholder()
	add_child(block)
	move_child(block, insert_idx)
	
	# Restore block visibility (it was dimmed during drag)
	block.modulate.a = 1.0
	
	blocks_changed.emit()

func _get_insert_index(at_position: Vector2) -> int:
	var idx: int = 0
	for i in range(get_child_count()):
		var child = get_child(i)
		if child.is_in_group("block_placeholder"): continue
		var child_center_y = child.position.y + child.size.y * 0.5
		if at_position.y > child_center_y:
			idx = i + 1
		else:
			break
	return idx

func add_block_node(block: Control) -> void:
	_remove_placeholder()
	add_child(block)
	blocks_changed.emit()

func get_block_children() -> Array:
	var blocks: Array = []
	for c in get_children():
		if c.is_in_group("block_placeholder"): continue
		if c.has_method("generate_code"):
			blocks.append(c)
	return blocks

func remove_last_block() -> void:
	var blocks = get_block_children()
	if blocks.size() > 0:
		var last = blocks[blocks.size() - 1]
		remove_child(last)
		last.queue_free()
		_ensure_placeholder()
		blocks_changed.emit()

func clear_all() -> void:
	for c in get_children():
		c.queue_free()
	placeholder_label = null
	call_deferred("_ensure_placeholder")
	blocks_changed.emit()
