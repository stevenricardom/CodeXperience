class_name LevelResultPopup
extends Control
## Modal animado de resultado del nivel (3 estrellas y desglose de monedas).

const StationTheme = preload("res://scenes/ui/theme/station_theme.gd")

signal next_level_confirmed()

var _built: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _anim_tween: Tween

var _card: PanelContainer
var _star_labels: Array[Label] = []
var _lbl_c1: Label
var _lbl_c2: Label
var _lbl_c3: Label
var _breakdown_labels: Dictionary = {}
var _btn_next: Button


func _init() -> void:
	visible = false


func _ready() -> void:
	theme = StationTheme.get_theme()
	_ensure_ui()


func show_result(
	award_data: Dictionary,
	blocks_used: int,
	par_blocks: int,
	attempts: int,
	hint_used: bool
) -> void:
	_ensure_ui()

	if not visible:
		_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true

	var stars: int = clampi(int(award_data.get("stars", 1)), 0, 3)
	var base_coins: int = int(award_data.get("base_coins", 0))
	var coop_bonus: int = int(award_data.get("coop_bonus", 0))
	var silo_bonus: int = int(award_data.get("silo_bonus", 0))
	var windmill_bonus: int = int(award_data.get("windmill_bonus", 0))
	var objective_bonus: int = int(award_data.get("objective_bonus", 0))
	var total_coins: int = int(award_data.get(
		"total_coins_earned",
		base_coins + coop_bonus + silo_bonus + windmill_bonus + objective_bonus
	))

	_apply_checklist(stars, blocks_used, par_blocks, attempts, hint_used)
	_set_breakdown_value("base", base_coins, true)
	_set_breakdown_value("coop", coop_bonus, coop_bonus > 0)
	_set_breakdown_value("silo", silo_bonus, silo_bonus > 0)
	_set_breakdown_value("windmill", windmill_bonus, windmill_bonus > 0)
	_set_breakdown_value("objective", objective_bonus, objective_bonus > 0)
	_set_breakdown_value("total", total_coins, true, true)

	_play_open_and_stars_animation(stars)

	if is_inside_tree():
		_btn_next.grab_focus()


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	theme = StationTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(540, 0)
	_card.add_theme_stylebox_override(
		"panel",
		_make_box(StationTheme.SURFACE, StationTheme.BORDER_STRONG, 2, 16, 24, 22)
	)
	center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_card.add_child(vbox)

	var title := Label.new()
	title.text = "¡Nivel Completado!"
	title.theme_type_variation = "StationTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 20)
	vbox.add_child(stars_row)

	_star_labels.clear()
	for i in range(3):
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(68, 68)
		stars_row.add_child(holder)

		var star_lbl := Label.new()
		star_lbl.text = "★"
		star_lbl.size = Vector2(68, 68)
		star_lbl.pivot_offset = Vector2(34, 34)
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star_lbl.add_theme_font_size_override("font_size", 46)
		holder.add_child(star_lbl)
		_star_labels.append(star_lbl)

	var checklist_panel := PanelContainer.new()
	checklist_panel.add_theme_stylebox_override(
		"panel",
		_make_box(StationTheme.INPUT_BG, StationTheme.BORDER, 1, 10, 14, 10)
	)
	vbox.add_child(checklist_panel)

	var checklist_vbox := VBoxContainer.new()
	checklist_vbox.add_theme_constant_override("separation", 6)
	checklist_panel.add_child(checklist_vbox)

	_lbl_c1 = Label.new()
	_lbl_c2 = Label.new()
	_lbl_c3 = Label.new()
	for lbl in [_lbl_c1, _lbl_c2, _lbl_c3]:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		checklist_vbox.add_child(lbl)

	var breakdown_panel := PanelContainer.new()
	breakdown_panel.add_theme_stylebox_override(
		"panel",
		_make_box(StationTheme.INPUT_BG, StationTheme.BORDER, 1, 10, 14, 12)
	)
	vbox.add_child(breakdown_panel)

	var breakdown_vbox := VBoxContainer.new()
	breakdown_vbox.add_theme_constant_override("separation", 6)
	breakdown_panel.add_child(breakdown_vbox)

	var breakdown_title := Label.new()
	breakdown_title.text = "Recompensa del Nivel"
	breakdown_title.theme_type_variation = "StationSection"
	breakdown_title.add_theme_color_override("font_color", StationTheme.AMBER)
	breakdown_vbox.add_child(breakdown_title)

	_add_breakdown_row(breakdown_vbox, "base", "Base")
	_add_breakdown_row(breakdown_vbox, "coop", "Gallinero")
	_add_breakdown_row(breakdown_vbox, "silo", "Silo (+10 %)")
	_add_breakdown_row(breakdown_vbox, "windmill", "Molino (+50 % Sembrar)")
	_add_breakdown_row(breakdown_vbox, "objective", "Objetivo del Granjero")

	var sep := HSeparator.new()
	breakdown_vbox.add_child(sep)
	_add_breakdown_row(breakdown_vbox, "total", "Total ganado", true)

	_btn_next = Button.new()
	_btn_next.text = "Siguiente Nivel"
	_btn_next.theme_type_variation = "StationPrimary"
	_btn_next.custom_minimum_size = Vector2(0, 48)
	_btn_next.focus_mode = Control.FOCUS_ALL
	_btn_next.pressed.connect(_on_next_pressed)
	vbox.add_child(_btn_next)


func _add_breakdown_row(parent: VBoxContainer, key: String, title_text: String, is_total: bool = false) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl_name := Label.new()
	lbl_name.text = title_text
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_total:
		lbl_name.add_theme_font_size_override("font_size", 19)
		lbl_name.add_theme_color_override("font_color", StationTheme.TEXT)
	else:
		lbl_name.add_theme_color_override("font_color", StationTheme.TEXT_MUTED)
	row.add_child(lbl_name)

	var lbl_val := Label.new()
	lbl_val.text = "+0 monedas"
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if is_total:
		lbl_val.add_theme_font_size_override("font_size", 20)
	row.add_child(lbl_val)
	_breakdown_labels[key] = lbl_val


func _set_breakdown_value(key: String, amount: int, highlight: bool, is_total: bool = false) -> void:
	var lbl: Label = _breakdown_labels.get(key)
	if not is_instance_valid(lbl):
		return
	lbl.text = "+%d monedas" % amount
	if is_total:
		lbl.add_theme_color_override("font_color", StationTheme.AMBER)
	elif highlight:
		lbl.add_theme_color_override("font_color", StationTheme.MINT)
	else:
		lbl.add_theme_color_override("font_color", StationTheme.TEXT_FAINT)


func _apply_checklist(
	stars: int,
	blocks_used: int,
	par_blocks: int,
	attempts: int,
	hint_used: bool
) -> void:
	var effective_par: int = maxi(1, par_blocks)
	var c1_ok: bool = stars >= 1
	var c2_ok: bool = blocks_used <= effective_par
	var c3_ok: bool = stars >= 3 and attempts == 1 and not hint_used

	_lbl_c1.text = "%s 1★ Misión cumplida" % ("✓" if c1_ok else "○")
	_lbl_c1.add_theme_color_override("font_color", StationTheme.MINT if c1_ok else StationTheme.TEXT_MUTED)

	_lbl_c2.text = "%s 2★ Eficiencia: %d / %d bloques" % [
		"✓" if c2_ok else "○",
		blocks_used,
		effective_par,
	]
	_lbl_c2.add_theme_color_override("font_color", StationTheme.MINT if c2_ok else StationTheme.TEXT_MUTED)

	_lbl_c3.text = "%s 3★ Primer intento y sin pista" % ("✓" if c3_ok else "○")
	_lbl_c3.add_theme_color_override("font_color", StationTheme.MINT if c3_ok else StationTheme.TEXT_MUTED)


func _play_open_and_stars_animation(stars: int) -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	for i in range(_star_labels.size()):
		var star_lbl: Label = _star_labels[i]
		var earned: bool = i < stars
		star_lbl.text = "★" if earned else "☆"
		star_lbl.add_theme_color_override(
			"font_color",
			StationTheme.AMBER if earned else StationTheme.TEXT_FAINT
		)
		if is_inside_tree():
			star_lbl.scale = Vector2(0.1, 0.1)
			star_lbl.modulate.a = 0.0
		else:
			star_lbl.scale = Vector2.ONE if earned else Vector2(0.85, 0.85)
			star_lbl.modulate.a = 1.0 if earned else 0.45

	if not is_inside_tree():
		_card.modulate.a = 1.0
		return

	_card.modulate.a = 0.0
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.tween_property(_card, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)

	for i in range(_star_labels.size()):
		var star_lbl: Label = _star_labels[i]
		var earned: bool = i < stars
		var delay: float = 0.08 + float(i) * 0.18
		var target_scale := Vector2.ONE if earned else Vector2(0.85, 0.85)
		var target_alpha := 1.0 if earned else 0.45
		_anim_tween.tween_property(star_lbl, "scale", target_scale, 0.28) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_anim_tween.tween_property(star_lbl, "modulate:a", target_alpha, 0.2) \
			.set_delay(delay)


func _on_next_pressed() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	Input.mouse_mode = _previous_mouse_mode
	visible = false
	next_level_confirmed.emit()


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
