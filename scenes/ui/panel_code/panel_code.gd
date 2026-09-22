extends Control
## Panel de Código: Canvas de bloques + Terminal de mensajes

const BlockCanvasScript = preload("res://scenes/ui/blocks/block_canvas.gd")

signal code_execution_requested(code: String)
signal clear_requested()
signal execution_stopped()

@onready var canvas_placeholder: Control = $MarginContainer/VBoxContainer/CanvasPlaceholder
@onready var terminal: RichTextLabel = $MarginContainer/VBoxContainer/Terminal
@onready var btn_execute: Button = $MarginContainer/VBoxContainer/Toolbar/BtnExecute
@onready var btn_delete_block: Button = $MarginContainer/VBoxContainer/Toolbar/BtnDeleteBlock
@onready var btn_clear: Button = $MarginContainer/VBoxContainer/Toolbar/BtnClear

var canvas: ScrollContainer  # BlockCanvas

func _ready() -> void:
	btn_execute.pressed.connect(execute)
	btn_delete_block.pressed.connect(_delete_last_block)
	btn_clear.pressed.connect(_on_clear_pressed)
	
	# Instanciar el BlockCanvas en el placeholder
	canvas = ScrollContainer.new()
	canvas.set_script(BlockCanvasScript)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Reemplazar el placeholder por el canvas
	canvas_placeholder.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _on_clear_pressed() -> void:
	clear_requested.emit()

# --- API para recibir bloques desde otros paneles ---
func add_block(type: String, params: Dictionary = {}) -> void:
	if canvas:
		canvas.add_block(type, params)

# Mantener compatibilidad: si alguien envía una línea de texto, ignorarla
func add_line(_text: String) -> void:
	pass

func execute() -> void:
	if not canvas:
		mostrar_error("Canvas no inicializado.")
		return
	
	if canvas.get_block_count() == 0:
		mostrar_error("No hay bloques. Añade bloques desde el panel de acciones.")
		return
	
	var code: String = canvas.generate_code()
	mostrar_exito("Ejecutando...\n" + code)
	code_execution_requested.emit(code)

func clear() -> void:
	if canvas:
		canvas.clear_all()
	mostrar_mensaje("Bloques limpiados.")
	execution_stopped.emit()

func _delete_last_block() -> void:
	if canvas:
		canvas.remove_last_block()

# --- Terminal ---
func mostrar_error(msg: String) -> void:
	terminal.text = "[color=red]Error:[/color] " + msg

func mostrar_exito(msg: String) -> void:
	terminal.text = "[color=green]Exito:[/color] " + msg

func mostrar_mensaje(msg: String) -> void:
	terminal.text = "[color=gray]" + msg + "[/color]"
