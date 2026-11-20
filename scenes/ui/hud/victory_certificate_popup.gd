class_name VictoryCertificatePopup
extends Control
## Modal de Certificado de Restauración al 100 % y paso a Modo Libre.

const StationTheme = preload("res://scenes/ui/theme/station_theme.gd")
const EconomyCatalog = preload("res://scripts/game/economy.gd")

signal closed()

var _built: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _anim_tween: Tween

var _card: PanelContainer
var _lbl_levels: Label
var _lbl_stars: Label
var _lbl_coins: Label
var _lbl_blocks: Label
var _lbl_buildings: Label
var _btn_continue: Button


func _init() -> void:
	visible = false


func _ready() -> void:
	theme = StationTheme.get_theme()
	_ensure_ui()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_continue_pressed()


func show_certificate(stats: Dictionary = {}) -> void:
	_ensure_ui()

	if not visible:
		_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true

	var gs: Node = get_node_or_null("/root/GameState") if is_inside_tree() else null
	var levels_done: int = int(stats.get("levels_completed", gs.get("levels_completed") if gs else 0))
	var total_stars: int = int(stats.get("total_stars", gs.get("total_stars") if gs else 0))
	var coins: int = int(stats.get("coins", gs.get("coins") if gs else 0))

	_lbl_levels.text = "Niveles completados: %d" % levels_done
	_lbl_stars.text = "Estrellas totales: %d" % total_stars
	_lbl_coins.text = "Monedas actuales: %d" % coins

	var block_names: PackedStringArray = ["Avanzar", "Girar Derecha", "Girar Izquierda"]
	for block_id in EconomyCatalog.BLOCK_INFO:
		var info: Dictionary = EconomyCatalog.BLOCK_INFO[block_id]
		var block_icon := str(info.get("icon", "")).strip_edges()
		var block_name := str(info.get("name", block_id)).strip_edges()
		block_names.append(block_name if block_icon.is_empty() else "%s %s" % [block_icon, block_name])
	var total_blocks: int = EconomyCatalog.INITIAL_UNLOCKED_BLOCKS.size() + EconomyCatalog.BLOCK_PRICES.size()
	var unlocked_arr: Variant = gs.get("unlocked_blocks") if gs else null
	var unlocked_count: int = (unlocked_arr as Array).size() if unlocked_arr is Array else total_blocks
	_lbl_blocks.text = "Bloques desbloqueados (%d/%d): %s" % [
		unlocked_count,
		total_blocks,
		", ".join(block_names),
	]

	var building_names: PackedStringArray = []
	for building_id in EconomyCatalog.BUILDING_INFO:
		var b_info: Dictionary = EconomyCatalog.BUILDING_INFO[building_id]
		var b_icon := str(b_info.get("icon", "")).strip_edges()
		var b_name := str(b_info.get("name", building_id)).strip_edges()
		building_names.append(b_name if b_icon.is_empty() else "%s %s" % [b_icon, b_name])
	var total_buildings: int = EconomyCatalog.BUILDING_PRICES.size()
	var built_arr: Variant = gs.get("purchased_buildings") if gs else null
	var built_count: int = (built_arr as Array).size() if built_arr is Array else total_buildings
	_lbl_buildings.text = "Edificios construidos (%d/%d): %s" % [
		built_count,
		total_buildings,
		", ".join(building_names),
	]

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	if is_inside_tree():
		_card.modulate.a = 0.0
		_anim_tween = create_tween()
		_anim_tween.tween_property(_card, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
		_btn_continue.grab_focus()
	else:
		_card.modulate.a = 1.0


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	theme = StationTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(640, 0)
	_card.add_theme_stylebox_override(
		"panel",
		_make_box(StationTheme.SURFACE, StationTheme.AMBER, 2, 16, 28, 24)
	)
	center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_card.add_child(vbox)

	var title := Label.new()
	title.text = "Certificado de Restauración: Granja CodeXperience 100 %"
	title.theme_type_variation = "StationTitle"
	title.add_theme_color_override("font_color", StationTheme.AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "¡Enhorabuena! Has restaurado toda la granja y dominado todos los bloques de programación."
	subtitle.theme_type_variation = "StationHelp"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override(
		"panel",
		_make_box(StationTheme.INPUT_BG, StationTheme.BORDER_STRONG, 1, 12, 16, 14)
	)
	vbox.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 8)
	stats_panel.add_child(stats_vbox)

	_lbl_levels = Label.new()
	_lbl_stars = Label.new()
	_lbl_coins = Label.new()
	_lbl_blocks = Label.new()
	_lbl_buildings = Label.new()
	_lbl_levels.add_theme_color_override("font_color", StationTheme.MINT)
	_lbl_stars.add_theme_color_override("font_color", Color(0.99, 0.87, 0.45))
	_lbl_coins.add_theme_color_override("font_color", StationTheme.AMBER)
	_lbl_blocks.add_theme_color_override("font_color", StationTheme.SKY)
	_lbl_buildings.add_theme_color_override("font_color", StationTheme.TEXT)
	for lbl in [_lbl_levels, _lbl_stars, _lbl_coins, _lbl_blocks, _lbl_buildings]:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_vbox.add_child(lbl)

	var free_play_note := Label.new()
	free_play_note.text = "Modo Libre desbloqueado: continúa resolviendo retos del tractor con todo tu arsenal."
	free_play_note.add_theme_color_override("font_color", StationTheme.MINT)
	free_play_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	free_play_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(free_play_note)

	_btn_continue = Button.new()
	_btn_continue.text = "Seguir en Modo Libre"
	_btn_continue.theme_type_variation = "StationPrimary"
	_btn_continue.custom_minimum_size = Vector2(0, 48)
	_btn_continue.focus_mode = Control.FOCUS_ALL
	_btn_continue.pressed.connect(_on_continue_pressed)
	vbox.add_child(_btn_continue)


func _on_continue_pressed() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	Input.mouse_mode = _previous_mouse_mode
	visible = false
	closed.emit()


static func _make_box(
	bg: Color,
	border: Color,
	border_w: int,
	radius: int,
	pad_h: int,
	pad_v: int
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb
