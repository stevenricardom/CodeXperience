extends Control
## Panel de Variables: Taller slot-machine + Variables creadas + Constructor de Condición

signal add_code_line(line: String)
signal block_requested(type: String, params: Dictionary)
signal condition_changed(condition: String)
signal variables_cleared()

@onready var lbl_var_name: Label = $MarginContainer/ScrollContainer/VBoxContainer/RowName/Value
@onready var lbl_var_type: Label = $MarginContainer/ScrollContainer/VBoxContainer/RowType/Value
@onready var lbl_var_value: Label = $MarginContainer/ScrollContainer/VBoxContainer/RowValue/Value
@onready var created_vars_container: VBoxContainer = $MarginContainer/ScrollContainer/VBoxContainer/CreatedVars
@onready var btn_create: Button = $MarginContainer/ScrollContainer/VBoxContainer/BtnCreate

@onready var lbl_cond_preview: Label = $MarginContainer/ScrollContainer/VBoxContainer/CondPreview
@onready var lbl_cond_var: Label = $MarginContainer/ScrollContainer/VBoxContainer/RowCondVar/Value
@onready var lbl_cond_op: Label = $MarginContainer/ScrollContainer/VBoxContainer/RowCondOp/Value
@onready var lbl_cond_val: Label = $MarginContainer/ScrollContainer/VBoxContainer/RowCondVal/Value

# Botones de spinners (Variables)
@onready var btn_var_name_left = $MarginContainer/ScrollContainer/VBoxContainer/RowName/BtnLeft
@onready var btn_var_name_right = $MarginContainer/ScrollContainer/VBoxContainer/RowName/BtnRight
@onready var btn_var_type_left = $MarginContainer/ScrollContainer/VBoxContainer/RowType/BtnLeft
@onready var btn_var_type_right = $MarginContainer/ScrollContainer/VBoxContainer/RowType/BtnRight
@onready var btn_var_val_left = $MarginContainer/ScrollContainer/VBoxContainer/RowValue/BtnLeft
@onready var btn_var_val_right = $MarginContainer/ScrollContainer/VBoxContainer/RowValue/BtnRight

# Botones de spinners (Condición)
@onready var btn_cond_var_left = $MarginContainer/ScrollContainer/VBoxContainer/RowCondVar/BtnLeft
@onready var btn_cond_var_right = $MarginContainer/ScrollContainer/VBoxContainer/RowCondVar/BtnRight
@onready var btn_cond_op_left = $MarginContainer/ScrollContainer/VBoxContainer/RowCondOp/BtnLeft
@onready var btn_cond_op_right = $MarginContainer/ScrollContainer/VBoxContainer/RowCondOp/BtnRight
@onready var btn_cond_val_left = $MarginContainer/ScrollContainer/VBoxContainer/RowCondVal/BtnLeft
@onready var btn_cond_val_right = $MarginContainer/ScrollContainer/VBoxContainer/RowCondVal/BtnRight

var var_names = ["pasos", "vueltas", "total", "distancia", "terminado", "activo", "contador", "turno"]
var var_name_index: int = 0
var var_types = ["Número", "Booleano", "Texto"]
var var_type_index: int = 0
var var_value_int: int = 0
var var_value_bool: bool = true
var var_value_string: String = "hola"
var created_vars: Dictionary = {}

var cond_var_index: int = 0
var operators = ["<", ">", "==", "!=", "<=", ">="]
var cond_op_index: int = 0
var cond_value: int = 5

func _ready() -> void:
	# Conectar señales de los botones manualmente
	btn_var_name_left.pressed.connect(_var_name_left)
	btn_var_name_right.pressed.connect(_var_name_right)
	btn_var_type_left.pressed.connect(_var_type_left)
	btn_var_type_right.pressed.connect(_var_type_right)
	btn_var_val_left.pressed.connect(_var_value_minus)
	btn_var_val_right.pressed.connect(_var_value_plus)
	btn_create.pressed.connect(_create_variable)
	
	btn_cond_var_left.pressed.connect(_cond_var_left)
	btn_cond_var_right.pressed.connect(_cond_var_right)
	btn_cond_op_left.pressed.connect(_cond_op_left)
	btn_cond_op_right.pressed.connect(_cond_op_right)
	btn_cond_val_left.pressed.connect(_cond_val_minus)
	btn_cond_val_right.pressed.connect(_cond_val_plus)

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
	_update_val_display()

func _var_type_right() -> void:
	var_type_index = (var_type_index + 1) % var_types.size()
	lbl_var_type.text = var_types[var_type_index]
	_update_val_display()

func _var_value_minus() -> void:
	match var_type_index:
		0: var_value_int -= 1
		1: var_value_bool = not var_value_bool
	_update_val_display()

func _var_value_plus() -> void:
	match var_type_index:
		0: var_value_int += 1
		1: var_value_bool = not var_value_bool
		2:
			var opts = ["hola", "mundo", "si", "no", "listo", "error"]
			var idx = opts.find(var_value_string)
			var_value_string = opts[(idx + 1) % opts.size()]
	_update_val_display()

func _update_val_display() -> void:
	match var_type_index:
		0: lbl_var_value.text = str(var_value_int)
		1: lbl_var_value.text = str(var_value_bool).to_lower()
		2: lbl_var_value.text = "\"" + var_value_string + "\""

func _create_variable() -> void:
	var vname = var_names[var_name_index]
	if vname in created_vars:
		return
	
	var value_str = ""
	match var_type_index:
		0: value_str = str(var_value_int)
		1: value_str = str(var_value_bool).to_lower()
		2: value_str = "\"" + var_value_string + "\""
	
	created_vars[vname] = {"type": var_types[var_type_index], "value": value_str}
	block_requested.emit("var_decl", {"name": vname, "value": value_str})
	_refresh_vars_ui()
	_update_condition_preview()

func _refresh_vars_ui() -> void:
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
		
		var btn = Button.new()
		btn.text = "📌 " + vname + " = " + info.value
		btn.custom_minimum_size.y = 40
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 15)
		var captured_name = vname
		btn.pressed.connect(func(): block_requested.emit("var_ref", {"name": captured_name}))
		hbox.add_child(btn)
		
		if info.type == "Número":
			var btn_inc = Button.new()
			btn_inc.text = "+1"
			btn_inc.custom_minimum_size.y = 40
			btn_inc.custom_minimum_size.x = 45
			btn_inc.add_theme_font_size_override("font_size", 18)
			btn_inc.pressed.connect(func(): block_requested.emit("var_inc", {"name": captured_name}))
			hbox.add_child(btn_inc)
		
		created_vars_container.add_child(hbox)

func clear_all() -> void:
	created_vars.clear()
	cond_var_index = 0
	_refresh_vars_ui()
	_update_condition_preview()
	variables_cleared.emit()

# ============================================
# CONSTRUCTOR DE CONDICIÓN
# ============================================
func _get_condition() -> String:
	if created_vars.is_empty():
		return "true"
	var keys = created_vars.keys()
	var vname = keys[cond_var_index % keys.size()]
	return vname + " " + operators[cond_op_index] + " " + str(cond_value)

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
	var cond = _get_condition()
	if created_vars.is_empty():
		lbl_cond_preview.text = "⚠ Crea una variable primero"
		lbl_cond_var.text = "---"
	else:
		var keys = created_vars.keys()
		lbl_cond_var.text = keys[cond_var_index % keys.size()]
		lbl_cond_preview.text = cond
	lbl_cond_op.text = operators[cond_op_index]
	lbl_cond_val.text = str(cond_value)
	condition_changed.emit(cond)
