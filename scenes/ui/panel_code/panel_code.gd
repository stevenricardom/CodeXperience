extends Control
## Panel de Código: Canvas de bloques + Terminal de mensajes

const BlockCanvasScript = preload("res://scenes/ui/blocks/block_canvas.gd")
const StationTheme = preload("res://scenes/ui/theme/station_theme.gd")

signal code_execution_requested(code: String)
signal clear_requested()
signal execution_stopped()
signal hint_requested()

@onready var subtitle: Label = $MarginContainer/VBoxContainer/Subtitle
@onready var canvas_placeholder: Control = $MarginContainer/VBoxContainer/CanvasPlaceholder
@onready var terminal: RichTextLabel = $MarginContainer/VBoxContainer/Terminal
@onready var btn_execute: Button = $MarginContainer/VBoxContainer/Toolbar/BtnExecute
@onready var btn_delete_block: Button = $MarginContainer/VBoxContainer/Toolbar/BtnDeleteBlock
@onready var btn_clear: Button = $MarginContainer/VBoxContainer/Toolbar/BtnClear
@onready var btn_hint: Button = $MarginContainer/VBoxContainer/Toolbar/BtnHint

var canvas: ScrollContainer  # BlockCanvas
var _hint_already_used: bool = false
var _terminal_base_style: StyleBoxFlat

func _ready() -> void:
	# Tema compartido de la estación.
	theme = StationTheme.get_theme()

	subtitle.add_theme_stylebox_override(
		"normal",
		StationTheme.make_accent_card(StationTheme.SURFACE.lerp(StationTheme.SKY, 0.12), StationTheme.SKY, 5, 10, 14, 8)
	)
	subtitle.add_theme_color_override("font_color", StationTheme.TEXT)

	_terminal_base_style = StationTheme.make_accent_card(StationTheme.INPUT_BG, StationTheme.MINT, 5, 10, 12, 10)
	terminal.add_theme_stylebox_override("normal", _terminal_base_style)

	btn_execute.pressed.connect(execute)
	btn_delete_block.pressed.connect(_delete_last_block)
	btn_clear.pressed.connect(_on_clear_pressed)
	btn_hint.pressed.connect(func(): hint_requested.emit())
	
	# Marco colorido alrededor del BlockCanvas en el placeholder
	var canvas_frame := PanelContainer.new()
	canvas_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_frame.add_theme_stylebox_override(
		"panel",
		StationTheme.make_accent_card(StationTheme.SURFACE.lerp(StationTheme.MINT, 0.08), StationTheme.MINT_DEEP, 5, 10, 6, 6)
	)
	canvas_placeholder.add_child(canvas_frame)

	canvas = ScrollContainer.new()
	canvas.set_script(BlockCanvasScript)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.add_child(canvas)

	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_signal("building_purchased") and not gs.building_purchased.is_connected(_on_building_purchased):
		gs.building_purchased.connect(_on_building_purchased)
	update_hint_button(false)

func _on_building_purchased(_building_id: String) -> void:
	update_hint_button(_hint_already_used)

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

# --- Terminal y Misión ---
func update_hint_button(hint_already_used: bool = false) -> void:
	_hint_already_used = hint_already_used
	if not is_instance_valid(btn_hint):
		return
	if hint_already_used:
		btn_hint.text = "Ver Pista"
		return
	var gs := get_node_or_null("/root/GameState")
	var cost: int = 5
	if gs and gs.has_method("get_hint_cost"):
		cost = int(gs.get_hint_cost())
	if cost <= 0:
		btn_hint.text = "Pista (Gratis)"
	else:
		btn_hint.text = "Pista (%d monedas)" % cost

func update_mission_banner(mission_text: String, par_blocks: int) -> void:
	if not is_instance_valid(subtitle):
		return
	var clean_mission: String = mission_text.strip_edges()
	var safe_par: int = maxi(1, par_blocks)
	if clean_mission.is_empty():
		subtitle.text = "Par óptimo: ≤ %d bloques" % safe_par
	else:
		subtitle.text = "%s  ·  Par óptimo: ≤ %d bloques" % [clean_mission, safe_par]
	subtitle.add_theme_color_override("font_color", StationTheme.MINT)

func mostrar_pista(hint_text: String) -> void:
	update_hint_button(true)
	var text_to_show: String = hint_text.strip_edges()
	if text_to_show.is_empty():
		text_to_show = "Planifica tu ruta paso a paso hacia la meta."
	var amber_hex: String = StationTheme.AMBER.to_html(false)
	var text_hex: String = StationTheme.TEXT.to_html(false)
	terminal.text = "[b][color=#" + amber_hex + "]PISTA:[/color][/b] [color=#" + text_hex + "]" + text_to_show + "[/color]"

	var hint_style := StationTheme.make_accent_card(Color(0.145, 0.120, 0.068), StationTheme.AMBER, 5, 10, 12, 10)
	terminal.add_theme_stylebox_override("normal", hint_style)

	if is_inside_tree():
		terminal.pivot_offset = terminal.size * 0.5
		var tw := create_tween()
		tw.tween_property(terminal, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(terminal, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func mostrar_error(msg: String) -> void:
	terminal.add_theme_stylebox_override("normal", StationTheme.make_accent_card(StationTheme.INPUT_BG.lerp(StationTheme.ROSE, 0.08), StationTheme.ROSE, 5, 10, 12, 10))
	terminal.text = "[color=" + StationTheme.ROSE.to_html(false) + "]Error:[/color] " + msg

func mostrar_exito(msg: String) -> void:
	terminal.add_theme_stylebox_override("normal", _terminal_base_style)
	terminal.text = "[color=" + StationTheme.MINT.to_html(false) + "]Éxito:[/color] " + msg

func mostrar_mensaje(msg: String) -> void:
	terminal.add_theme_stylebox_override("normal", _terminal_base_style)
	terminal.text = "[color=" + StationTheme.TEXT_MUTED.to_html(false) + "]" + msg + "[/color]"
