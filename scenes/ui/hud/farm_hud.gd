class_name FarmHUD
extends CanvasLayer
## HUD de escritorio: monedas animadas, estrellas, misión actual, restauración 0-100%,
## objetivo del granjero con toast de celebración y popups de resultado / victoria.

const StationTheme = preload("res://scenes/ui/theme/station_theme.gd")
const EconomyCatalog = preload("res://scripts/game/economy.gd")
const LevelResultPopupScript = preload("res://scenes/ui/hud/level_result_popup.gd")
const VictoryCertificatePopupScript = preload("res://scenes/ui/hud/victory_certificate_popup.gd")

signal next_level_requested()

var _built: bool = false
var _displayed_coins: int = 0
var _mission: String = "reach"
var _planted_count: int = 0
var _total_plant: int = 0
var _par_blocks: int = 1
var _has_mission_data: bool = false

var _coins_tween: Tween
var _coins_pop_tween: Tween
var _restoration_tween: Tween
var _toast_tween: Tween
var _toast_queue: Array[Dictionary] = []
var _toast_playing: bool = false

var _modal_locked: bool = false
var _locked_interaction: Node = null
var _locked_movement: Node = null
var _saved_interaction_input: bool = true
var _saved_interaction_physics: bool = true
var _saved_movement_enabled: bool = true

var _hud_root: Control
var _coins_holder: Control
var _lbl_coins: Label
var _lbl_stars: Label
var _lbl_mission: Label
var _lbl_par: Label
var _lbl_restoration: Label
var _bar_restoration: ProgressBar
var _fill_style: StyleBoxFlat
var _lbl_obj_header: Label
var _lbl_obj_reward: Label
var _lbl_obj_title: Label
var _lbl_obj_desc: Label
var _toast_panel: PanelContainer
var _lbl_toast: Label

var _result_popup: LevelResultPopup
var _certificate_popup: VictoryCertificatePopup


func _init() -> void:
	layer = 5


func _ready() -> void:
	_ensure_ui()
	_connect_game_state()
	_sync_from_game_state()
	_apply_mission_ui()


func _exit_tree() -> void:
	_release_desktop_lock()


func update_mission_status(
	mission: String,
	planted_count: int,
	total_plant: int,
	par_blocks: int
) -> void:
	_mission = mission
	_planted_count = planted_count
	_total_plant = total_plant
	_par_blocks = par_blocks
	_has_mission_data = true
	_apply_mission_ui()


func show_level_result(
	award_data: Dictionary,
	blocks_used: int,
	par_blocks: int,
	attempts: int,
	hint_used: bool
) -> void:
	_ensure_ui()
	var gs: Node = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if gs:
		_update_stars_label(int(gs.get("total_stars")))
	_result_popup.show_result(award_data, blocks_used, par_blocks, attempts, hint_used)


func show_victory_certificate() -> void:
	_ensure_ui()
	_certificate_popup.show_certificate()


func _ensure_ui() -> void:
	if _built:
		return
	_built = true

	_hud_root = Control.new()
	_hud_root.theme = StationTheme.get_theme()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	var top_margin := MarginContainer.new()
	top_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_top", 12)
	top_margin.add_theme_constant_override("margin_right", 16)
	top_margin.add_theme_constant_override("margin_bottom", 0)
	_hud_root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_constant_override("separation", 12)
	top_margin.add_child(top_bar)

	_build_left_section(top_bar)
	_build_center_section(top_bar)
	_build_right_section(top_bar)

	_result_popup = LevelResultPopupScript.new()
	_result_popup.next_level_confirmed.connect(_on_result_next_level_confirmed)
	_result_popup.visibility_changed.connect(_on_modal_visibility_changed)
	add_child(_result_popup)

	_certificate_popup = VictoryCertificatePopupScript.new()
	_certificate_popup.visibility_changed.connect(_on_modal_visibility_changed)
	add_child(_certificate_popup)


func _build_left_section(top_bar: HBoxContainer) -> void:
	var left_box := HBoxContainer.new()
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.size_flags_stretch_ratio = 1.2
	left_box.add_theme_constant_override("separation", 10)
	top_bar.add_child(left_box)

	var stats_card := _make_card_panel(StationTheme.AMBER)
	stats_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left_box.add_child(stats_card)

	var stats_row := HBoxContainer.new()
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_theme_constant_override("separation", 16)
	stats_card.add_child(stats_row)

	_coins_holder = Control.new()
	_coins_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coins_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_row.add_child(_coins_holder)

	_lbl_coins = Label.new()
	_lbl_coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_coins.add_theme_font_size_override("font_size", 20)
	_lbl_coins.add_theme_color_override("font_color", StationTheme.AMBER)
	_coins_holder.add_child(_lbl_coins)
	_set_displayed_coins(0)

	_lbl_stars = Label.new()
	_lbl_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lbl_stars.text = "★ 0"
	_lbl_stars.add_theme_font_size_override("font_size", 20)
	_lbl_stars.add_theme_color_override("font_color", Color(0.99, 0.87, 0.45))
	stats_row.add_child(_lbl_stars)

	var mission_card := _make_card_panel(StationTheme.SKY)
	mission_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left_box.add_child(mission_card)

	var mission_vbox := VBoxContainer.new()
	mission_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_vbox.add_theme_constant_override("separation", 2)
	mission_card.add_child(mission_vbox)

	_lbl_mission = Label.new()
	_lbl_mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_mission.text = "Misión: Llegar a la calabaza"
	_lbl_mission.add_theme_font_size_override("font_size", 16)
	_lbl_mission.add_theme_color_override("font_color", StationTheme.SKY)
	mission_vbox.add_child(_lbl_mission)

	_lbl_par = Label.new()
	_lbl_par.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_par.text = "Par: ≤ 1 bloques"
	_lbl_par.theme_type_variation = "StationHelp"
	_lbl_par.add_theme_font_size_override("font_size", 14)
	mission_vbox.add_child(_lbl_par)


func _build_center_section(top_bar: HBoxContainer) -> void:
	var center_card := _make_card_panel(StationTheme.MINT)
	center_card.custom_minimum_size = Vector2(285, 0)
	center_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_bar.add_child(center_card)

	var center_vbox := VBoxContainer.new()
	center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_vbox.add_theme_constant_override("separation", 6)
	center_card.add_child(center_vbox)

	_lbl_restoration = Label.new()
	_lbl_restoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_restoration.text = "Granja Restaurada: 0 %"
	_lbl_restoration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_restoration.add_theme_font_size_override("font_size", 16)
	center_vbox.add_child(_lbl_restoration)

	_bar_restoration = ProgressBar.new()
	_bar_restoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_restoration.min_value = 0.0
	_bar_restoration.max_value = 100.0
	_bar_restoration.value = 0.0
	_bar_restoration.show_percentage = false
	_bar_restoration.custom_minimum_size = Vector2(240, 14)

	var bg_style := _make_box(StationTheme.INPUT_BG, StationTheme.BORDER, 1, 7, 0, 0)
	_fill_style = _make_box(StationTheme.MINT, Color.TRANSPARENT, 0, 7, 0, 0)
	_bar_restoration.add_theme_stylebox_override("background", bg_style)
	_bar_restoration.add_theme_stylebox_override("fill", _fill_style)
	center_vbox.add_child(_bar_restoration)


func _build_right_section(top_bar: HBoxContainer) -> void:
	var right_vbox := VBoxContainer.new()
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.25
	right_vbox.add_theme_constant_override("separation", 8)
	top_bar.add_child(right_vbox)

	var obj_card := _make_card_panel(StationTheme.MINT)
	right_vbox.add_child(obj_card)

	var obj_vbox := VBoxContainer.new()
	obj_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_vbox.add_theme_constant_override("separation", 2)
	obj_card.add_child(obj_vbox)

	var obj_top := HBoxContainer.new()
	obj_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_vbox.add_child(obj_top)

	_lbl_obj_header = Label.new()
	_lbl_obj_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_obj_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_obj_header.add_theme_font_size_override("font_size", 14)
	_lbl_obj_header.add_theme_color_override("font_color", StationTheme.MINT)
	obj_top.add_child(_lbl_obj_header)

	_lbl_obj_reward = Label.new()
	_lbl_obj_reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_obj_reward.add_theme_font_size_override("font_size", 15)
	_lbl_obj_reward.add_theme_color_override("font_color", StationTheme.AMBER)
	obj_top.add_child(_lbl_obj_reward)

	_lbl_obj_title = Label.new()
	_lbl_obj_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_obj_title.add_theme_font_size_override("font_size", 16)
	obj_vbox.add_child(_lbl_obj_title)

	_lbl_obj_desc = Label.new()
	_lbl_obj_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_obj_desc.theme_type_variation = "StationHelp"
	_lbl_obj_desc.add_theme_font_size_override("font_size", 14)
	_lbl_obj_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_vbox.add_child(_lbl_obj_desc)

	_toast_panel = PanelContainer.new()
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_panel.modulate.a = 0.0
	_toast_panel.add_theme_stylebox_override(
		"panel",
		_make_box(Color(0.145, 0.122, 0.067, 0.94), StationTheme.AMBER, 2, 10, 14, 10)
	)
	right_vbox.add_child(_toast_panel)

	_lbl_toast = Label.new()
	_lbl_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_toast.add_theme_font_size_override("font_size", 15)
	_lbl_toast.add_theme_color_override("font_color", StationTheme.AMBER)
	_lbl_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_panel.add_child(_lbl_toast)


func _connect_game_state() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if gs.has_signal("coins_changed") and not gs.is_connected("coins_changed", _on_coins_changed):
		gs.connect("coins_changed", _on_coins_changed)
	if gs.has_signal("restoration_changed") and not gs.is_connected("restoration_changed", _on_restoration_changed):
		gs.connect("restoration_changed", _on_restoration_changed)
	if gs.has_signal("objective_updated") and not gs.is_connected("objective_updated", _on_objective_updated):
		gs.connect("objective_updated", _on_objective_updated)
	if gs.has_signal("objective_completed") and not gs.is_connected("objective_completed", _on_objective_completed):
		gs.connect("objective_completed", _on_objective_completed)
	if gs.has_signal("victory_100_reached") and not gs.is_connected("victory_100_reached", _on_victory_100_reached):
		gs.connect("victory_100_reached", _on_victory_100_reached)


func _sync_from_game_state() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		_set_displayed_coins(0)
		_update_stars_label(0)
		_set_restoration_display(0, false)
		var first_obj: Dictionary = EconomyCatalog.OBJECTIVES[0] if not EconomyCatalog.OBJECTIVES.is_empty() else {}
		_update_objective_card(first_obj, 0)
		return

	_set_displayed_coins(int(gs.get("coins")))
	_update_stars_label(int(gs.get("total_stars")))
	var pct: int = int(gs.call("get_restoration_percent")) if gs.has_method("get_restoration_percent") else 0
	_set_restoration_display(pct, false)
	var cur_obj: Dictionary = gs.call("get_current_objective") if gs.has_method("get_current_objective") else {}
	_update_objective_card(cur_obj, int(gs.get("current_objective_index")))


func _apply_mission_ui() -> void:
	if not is_instance_valid(_lbl_mission) or not is_instance_valid(_lbl_par):
		return
	if not _has_mission_data:
		return
	if _mission == "plant":
		_lbl_mission.text = "Misión: Sembrar %d/%d + Meta" % [_planted_count, _total_plant]
		var all_planted: bool = _total_plant > 0 and _planted_count >= _total_plant
		_lbl_mission.add_theme_color_override(
			"font_color",
			StationTheme.MINT if all_planted else StationTheme.SKY
		)
	else:
		_lbl_mission.text = "Misión: Llegar a la calabaza"
		_lbl_mission.add_theme_color_override("font_color", StationTheme.SKY)
	_lbl_par.text = "Par: ≤ %d bloques" % _par_blocks


func _set_displayed_coins(value: int) -> void:
	_displayed_coins = value
	if not is_instance_valid(_lbl_coins):
		return
	_lbl_coins.text = "Monedas: %d" % value
	var min_sz: Vector2 = _lbl_coins.get_combined_minimum_size()
	if is_instance_valid(_coins_holder):
		_coins_holder.custom_minimum_size = min_sz
	_lbl_coins.size = min_sz
	_lbl_coins.pivot_offset = min_sz * 0.5


func _update_stars_label(stars: int) -> void:
	if is_instance_valid(_lbl_stars):
		_lbl_stars.text = "★ %d" % stars


func _set_restoration_display(percent: int, animate: bool) -> void:
	if is_instance_valid(_lbl_restoration):
		_lbl_restoration.text = "Granja Restaurada: %d %%" % percent
		_lbl_restoration.add_theme_color_override(
			"font_color",
			StationTheme.MINT if percent >= 100 else StationTheme.TEXT
		)
	if is_instance_valid(_fill_style):
		var t: float = clampf(float(percent) / 100.0, 0.0, 1.0)
		_fill_style.bg_color = StationTheme.AMBER.lerp(StationTheme.MINT, t)
	if not is_instance_valid(_bar_restoration):
		return
	if _restoration_tween and _restoration_tween.is_valid():
		_restoration_tween.kill()
	if animate and is_inside_tree():
		_restoration_tween = create_tween()
		_restoration_tween.tween_property(_bar_restoration, "value", float(percent), 0.45) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_bar_restoration.value = float(percent)


func _update_objective_card(objective: Dictionary, obj_index: int) -> void:
	if not is_instance_valid(_lbl_obj_header):
		return
	var total_objs: int = EconomyCatalog.OBJECTIVES.size()
	if objective.is_empty():
		_lbl_obj_header.text = "Objetivo del Granjero (%d/%d)" % [total_objs, total_objs]
		_lbl_obj_reward.text = "✓ 100 %"
		_lbl_obj_title.text = "¡Todos completados!"
		_lbl_obj_desc.text = "Has cumplido todas las metas del granjero."
		return

	var current_num: int = mini(obj_index + 1, total_objs)
	_lbl_obj_header.text = "Objetivo del Granjero (%d/%d)" % [current_num, total_objs]
	_lbl_obj_reward.text = "+%d monedas" % int(objective.get("reward", 0))
	_lbl_obj_title.text = str(objective.get("title", ""))
	_lbl_obj_desc.text = str(objective.get("desc", ""))


func _on_coins_changed(new_coins: int, delta: int) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs:
		_update_stars_label(int(gs.get("total_stars")))

	if not is_inside_tree():
		_set_displayed_coins(new_coins)
		return

	if _coins_tween and _coins_tween.is_valid():
		_coins_tween.kill()
	_coins_tween = create_tween()
	_coins_tween.tween_method(_set_displayed_coins, _displayed_coins, new_coins, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if delta != 0 and is_instance_valid(_lbl_coins):
		if _coins_pop_tween and _coins_pop_tween.is_valid():
			_coins_pop_tween.kill()
		_lbl_coins.pivot_offset = _lbl_coins.size * 0.5
		_lbl_coins.scale = Vector2(1.24, 1.24)
		var flash_color := Color(1.0, 0.96, 0.72) if delta > 0 else StationTheme.ROSE
		_lbl_coins.add_theme_color_override("font_color", flash_color)
		_coins_pop_tween = create_tween()
		_coins_pop_tween.set_parallel(true)
		_coins_pop_tween.tween_property(_lbl_coins, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_coins_pop_tween.tween_method(
			func(c: Color) -> void:
				if is_instance_valid(_lbl_coins):
					_lbl_coins.add_theme_color_override("font_color", c),
			flash_color,
			StationTheme.AMBER,
			0.35
		)


func _on_restoration_changed(percent: int) -> void:
	_set_restoration_display(percent, true)


func _on_objective_updated(objective: Dictionary) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	var idx: int = int(gs.get("current_objective_index")) if gs else 0
	_update_objective_card(objective, idx)


func _on_objective_completed(objective: Dictionary) -> void:
	_toast_queue.append(objective.duplicate())
	if not _toast_playing:
		_play_next_toast()


func _play_next_toast() -> void:
	if _toast_queue.is_empty() or not is_instance_valid(_toast_panel) or not is_inside_tree():
		_toast_playing = false
		if is_instance_valid(_toast_panel):
			_toast_panel.visible = false
		return

	_toast_playing = true
	var obj: Dictionary = _toast_queue.pop_front()
	var title: String = str(obj.get("title", "Objetivo"))
	var reward: int = int(obj.get("reward", 0))
	_lbl_toast.text = "¡Objetivo cumplido!\n%s (+%d monedas)" % [title, reward]
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(_play_next_toast)


func _on_victory_100_reached() -> void:
	show_victory_certificate()


func _on_result_next_level_confirmed() -> void:
	next_level_requested.emit()


func _on_modal_visibility_changed() -> void:
	if not is_inside_tree():
		return
	var any_open: bool = (
		(is_instance_valid(_result_popup) and _result_popup.visible)
		or (is_instance_valid(_certificate_popup) and _certificate_popup.visible)
	)
	if any_open:
		if not _modal_locked:
			_acquire_desktop_lock()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_release_desktop_lock()


func _acquire_desktop_lock() -> void:
	_modal_locked = true
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	_locked_interaction = tree.root.find_child("DesktopInteraction", true, false)
	if is_instance_valid(_locked_interaction):
		_saved_interaction_input = _locked_interaction.is_processing_input()
		_saved_interaction_physics = _locked_interaction.is_physics_processing()
		_locked_interaction.set_process_input(false)
		_locked_interaction.set_physics_process(false)
		var player_origin := _locked_interaction.get_parent()
		if is_instance_valid(player_origin):
			_locked_movement = player_origin.get_node_or_null("XRToolsDesktopMovementDirect")
			if is_instance_valid(_locked_movement):
				_saved_movement_enabled = bool(_locked_movement.get("enabled"))
				_locked_movement.set("enabled", false)


func _release_desktop_lock() -> void:
	if not _modal_locked:
		return
	_modal_locked = false
	if is_instance_valid(_locked_interaction):
		_locked_interaction.set_process_input(_saved_interaction_input)
		_locked_interaction.set_physics_process(_saved_interaction_physics)
	if is_instance_valid(_locked_movement):
		_locked_movement.set("enabled", _saved_movement_enabled)
	_locked_interaction = null
	_locked_movement = null


func _make_card_panel(accent: Color = StationTheme.BORDER) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _make_box(Color(0.082, 0.114, 0.173, 0.90), accent, 1, 10, 14, 8)
	sb.border_width_left = 4
	panel.add_theme_stylebox_override("panel", sb)
	return panel


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
