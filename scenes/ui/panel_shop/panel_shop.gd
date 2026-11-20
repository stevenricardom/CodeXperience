extends Control
## Kiosco de la Tienda de la Granja (960x540 dentro de Viewport2Din3D).

const StationTheme = preload("res://scenes/ui/theme/station_theme.gd")
const ECONOMY_SCRIPT_PATH := "res://scripts/game/economy.gd"

const BLOCK_ORDER: Array[String] = ["interactuar", "for_loop", "variables", "while_loop", "if_else"]
const BUILDING_ORDER: Array[String] = ["fences", "well", "chicken_coop", "silo", "windmill", "barn"]

var lbl_coins: Label
var lbl_restoration: Label
var lbl_feedback: Label
var restoration_bar: ProgressBar
var blocks_list: VBoxContainer
var buildings_list: VBoxContainer

var _block_cards: Dictionary = {}
var _building_cards: Dictionary = {}
var _bar_tween: Tween

func _ready() -> void:
	theme = StationTheme.get_theme()
	_build_ui()
	_populate_cards()

	var gs := get_node_or_null("/root/GameState")
	if gs:
		if gs.has_signal("coins_changed") and not gs.coins_changed.is_connected(_on_coins_changed):
			gs.coins_changed.connect(_on_coins_changed)
		if gs.has_signal("blocks_updated") and not gs.blocks_updated.is_connected(refresh_shop):
			gs.blocks_updated.connect(refresh_shop)
		if gs.has_signal("building_purchased") and not gs.building_purchased.is_connected(_on_building_purchased):
			gs.building_purchased.connect(_on_building_purchased)
		if gs.has_signal("restoration_changed") and not gs.restoration_changed.is_connected(_on_restoration_changed):
			gs.restoration_changed.connect(_on_restoration_changed)

	refresh_shop()

func _get_economy() -> Variant:
	if ResourceLoader.exists(ECONOMY_SCRIPT_PATH):
		return load(ECONOMY_SCRIPT_PATH)
	return null

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = StationTheme.BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# === Encabezado ===
	var header_card := PanelContainer.new()
	header_card.add_theme_stylebox_override("panel", _make_card_style(StationTheme.SURFACE, StationTheme.BORDER_STRONG))
	root_vbox.add_child(header_card)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 16)
	header_card.add_child(header_hbox)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	header_hbox.add_child(title_box)

	var lbl_title := Label.new()
	lbl_title.text = "Tienda de la Granja"
	lbl_title.theme_type_variation = &"StationTitle"
	title_box.add_child(lbl_title)

	lbl_feedback = Label.new()
	lbl_feedback.text = "Desbloquea bloques de código y construye edificios con bonos pasivos."
	lbl_feedback.theme_type_variation = &"StationHelp"
	lbl_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(lbl_feedback)

	var stats_box := VBoxContainer.new()
	stats_box.custom_minimum_size = Vector2(360, 0)
	stats_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_box.add_theme_constant_override("separation", 8)
	header_hbox.add_child(stats_box)

	var stats_top := HBoxContainer.new()
	stats_top.add_theme_constant_override("separation", 10)
	stats_box.add_child(stats_top)

	var coin_badge := PanelContainer.new()
	coin_badge.add_theme_stylebox_override("panel", _make_card_style(Color(0.22, 0.165, 0.075), StationTheme.AMBER, 8, 12, 5))
	stats_top.add_child(coin_badge)

	lbl_coins = Label.new()
	lbl_coins.text = "0 monedas"
	lbl_coins.add_theme_font_size_override("font_size", 17)
	lbl_coins.add_theme_color_override("font_color", StationTheme.AMBER)
	coin_badge.add_child(lbl_coins)

	lbl_restoration = Label.new()
	lbl_restoration.text = "Granja Restaurada: 0 %"
	lbl_restoration.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_restoration.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_restoration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_restoration.add_theme_font_size_override("font_size", 16)
	lbl_restoration.add_theme_color_override("font_color", StationTheme.MINT)
	stats_top.add_child(lbl_restoration)

	restoration_bar = ProgressBar.new()
	restoration_bar.min_value = 0.0
	restoration_bar.max_value = 100.0
	restoration_bar.value = 0.0
	restoration_bar.show_percentage = false
	restoration_bar.custom_minimum_size = Vector2(0, 16)
	restoration_bar.add_theme_stylebox_override("background", _make_card_style(StationTheme.INPUT_BG, StationTheme.BORDER, 8, 0, 0))
	restoration_bar.add_theme_stylebox_override("fill", _make_card_style(StationTheme.MINT, StationTheme.MINT, 8, 0, 0))
	stats_box.add_child(restoration_bar)

	# === Dos Columnas Scrollables ===
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	root_vbox.add_child(columns)

	blocks_list = _build_column(columns, "Bloques de Programación", StationTheme.SKY)
	buildings_list = _build_column(columns, "Edificios de la Granja", StationTheme.AMBER)

func _build_column(parent: Control, heading: String, accent_color: Color) -> VBoxContainer:
	var col_panel := PanelContainer.new()
	col_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_panel.add_theme_stylebox_override("panel", _make_card_style(StationTheme.SURFACE, StationTheme.BORDER, 12, 12, 10))
	parent.add_child(col_panel)

	var col_vbox := VBoxContainer.new()
	col_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_vbox.add_theme_constant_override("separation", 8)
	col_panel.add_child(col_vbox)

	var lbl_col := Label.new()
	lbl_col.text = heading
	lbl_col.theme_type_variation = &"StationSection"
	lbl_col.add_theme_color_override("font_color", accent_color)
	col_vbox.add_child(lbl_col)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list

func _populate_cards() -> void:
	var eco: Variant = _get_economy()
	if eco == null:
		return

	var block_info_dict: Dictionary = eco.BLOCK_INFO
	var block_prices: Dictionary = eco.BLOCK_PRICES
	for block_id in BLOCK_ORDER:
		if not block_info_dict.has(block_id):
			continue
		var info: Dictionary = block_info_dict[block_id]
		var price: int = int(info.get("price", block_prices.get(block_id, 0)))
		var icon_str: String = str(info.get("icon", "")).strip_edges()
		var name_str: String = str(info.get("name", block_id)).strip_edges()
		var title: String = name_str if icon_str.is_empty() else "%s %s" % [icon_str, name_str]
		var desc: String = str(info.get("desc", ""))
		var entry := _create_item_card(
			blocks_list,
			title,
			desc,
			StationTheme.TEXT_MUTED,
			StationTheme.SKY,
			price,
			_on_buy_block_pressed.bind(block_id)
		)
		entry["name"] = name_str
		_block_cards[block_id] = entry

	var building_info_dict: Dictionary = eco.BUILDING_INFO
	var building_prices: Dictionary = eco.BUILDING_PRICES
	for building_id in BUILDING_ORDER:
		if not building_info_dict.has(building_id):
			continue
		var info: Dictionary = building_info_dict[building_id]
		var price: int = int(info.get("price", building_prices.get(building_id, 0)))
		var icon_str: String = str(info.get("icon", "")).strip_edges()
		var name_str: String = str(info.get("name", building_id)).strip_edges()
		var title: String = name_str if icon_str.is_empty() else "%s %s" % [icon_str, name_str]
		var bonus: String = str(info.get("bonus", ""))
		var entry := _create_item_card(
			buildings_list,
			title,
			bonus,
			StationTheme.MINT,
			StationTheme.AMBER,
			price,
			_on_buy_building_pressed.bind(building_id)
		)
		entry["name"] = name_str
		_building_cards[building_id] = entry

func _create_item_card(parent: Control, title: String, subtitle_text: String, subtitle_color: Color, accent_color: Color, price: int, on_buy: Callable) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", StationTheme.make_accent_card(StationTheme.CARD, accent_color, 5, 10, 12, 9))
	parent.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 2)
	hbox.add_child(text_col)

	var lbl_name := Label.new()
	lbl_name.text = title
	lbl_name.add_theme_font_size_override("font_size", 16)
	lbl_name.add_theme_color_override("font_color", StationTheme.TEXT)
	lbl_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(lbl_name)

	var lbl_sub := Label.new()
	lbl_sub.text = subtitle_text
	lbl_sub.add_theme_font_size_override("font_size", 13)
	lbl_sub.add_theme_color_override("font_color", subtitle_color)
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(lbl_sub)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 44)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 15)
	btn.text = "Comprar · %d" % price
	btn.pressed.connect(on_buy)
	hbox.add_child(btn)

	return {
		"card": card,
		"button": btn,
		"price": price,
		"accent": accent_color,
	}

func refresh_shop() -> void:
	var gs := get_node_or_null("/root/GameState")
	var coins: int = 0 if gs == null else int(gs.coins)
	var pct: int = 0 if gs == null else int(gs.get_restoration_percent())

	if is_instance_valid(lbl_coins):
		lbl_coins.text = "%d monedas" % coins
	if is_instance_valid(lbl_restoration):
		lbl_restoration.text = "Granja Restaurada: %d %%" % pct
	if is_instance_valid(restoration_bar):
		if is_inside_tree():
			if is_instance_valid(_bar_tween):
				_bar_tween.kill()
			_bar_tween = create_tween()
			_bar_tween.tween_property(restoration_bar, "value", float(pct), 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			restoration_bar.value = float(pct)

	for block_id in _block_cards:
		var entry: Dictionary = _block_cards[block_id]
		var owned: bool = false if gs == null else gs.is_block_unlocked(block_id)
		_update_card_state(entry, owned, coins, "Desbloqueado", &"StationPrimary")

	for building_id in _building_cards:
		var entry: Dictionary = _building_cards[building_id]
		var owned: bool = false if gs == null else gs.is_building_purchased(building_id)
		_update_card_state(entry, owned, coins, "Construido", &"StationAccent")

func _update_card_state(entry: Dictionary, owned: bool, coins: int, owned_label: String, buy_variation: StringName) -> void:
	var card: PanelContainer = entry["card"]
	var btn: Button = entry["button"]
	var price: int = int(entry["price"])
	var accent: Color = entry.get("accent", StationTheme.BORDER_STRONG)

	if owned:
		btn.text = owned_label
		btn.disabled = true
		btn.theme_type_variation = &"StationGhost"
		card.add_theme_stylebox_override("panel", StationTheme.make_accent_card(StationTheme.SURFACE.lerp(StationTheme.MINT, 0.14), StationTheme.MINT, 5, 10, 12, 9))
	elif coins >= price:
		btn.text = "Comprar · %d" % price
		btn.disabled = false
		btn.theme_type_variation = buy_variation
		card.add_theme_stylebox_override("panel", StationTheme.make_accent_card(StationTheme.CARD.lerp(accent, 0.08), accent, 5, 10, 12, 9))
	else:
		btn.text = "Bloqueado · %d" % price
		btn.disabled = true
		btn.theme_type_variation = &"StationGhost"
		card.add_theme_stylebox_override("panel", StationTheme.make_accent_card(StationTheme.CARD, accent.darkened(0.35), 5, 10, 12, 9))

func _on_buy_block_pressed(block_id: String) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var entry: Dictionary = _block_cards.get(block_id, {})
	if gs.buy_block(block_id):
		_play_purchase_bounce(entry.get("card"))
		_set_feedback("¡Bloque '%s' desbloqueado!" % str(entry.get("name", block_id)), StationTheme.MINT)
	else:
		_set_feedback("No tienes suficientes monedas para este bloque.", StationTheme.ROSE)

func _on_buy_building_pressed(building_id: String) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var entry: Dictionary = _building_cards.get(building_id, {})
	if gs.buy_building(building_id):
		_play_purchase_bounce(entry.get("card"))
		_set_feedback("¡'%s' construido en tu granja!" % str(entry.get("name", building_id)), StationTheme.AMBER)
	else:
		_set_feedback("No tienes suficientes monedas para este edificio.", StationTheme.ROSE)

func _play_purchase_bounce(card: Variant) -> void:
	if not is_instance_valid(card) or not (card is Control) or not is_inside_tree():
		return
	var ctrl := card as Control
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := create_tween()
	tw.tween_property(ctrl, "scale", Vector2(0.92, 0.92), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2(1.06, 1.06), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_feedback(msg: String, color: Color) -> void:
	if not is_instance_valid(lbl_feedback):
		return
	lbl_feedback.text = msg
	lbl_feedback.add_theme_color_override("font_color", color)

func _on_coins_changed(_new_coins: int, _delta: int) -> void:
	refresh_shop()

func _on_building_purchased(_building_id: String) -> void:
	refresh_shop()

func _on_restoration_changed(_percent: int) -> void:
	refresh_shop()

func _make_card_style(bg: Color, border: Color, radius: int = 12, pad_h: int = 14, pad_v: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s
