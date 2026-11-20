extends Control

const StationTheme = preload("res://scenes/ui/theme/station_theme.gd")

@onready var hero_card: PanelContainer = $HeroCard
@onready var vbox: VBoxContainer = $VBoxContainer
@onready var save_progress_box: VBoxContainer = $VBoxContainer/SaveProgressBox
@onready var save_progress_label: Label = $VBoxContainer/SaveProgressBox/SaveProgressLabel
@onready var save_progress_bar: ProgressBar = $VBoxContainer/SaveProgressBox/SaveProgressBar
@onready var btn_continue: Button = $VBoxContainer/BtnContinue
@onready var btn_desktop: Button = $VBoxContainer/BtnDesktop

func _ready() -> void:
	theme = StationTheme.get_theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_style_progress_bar()
	btn_continue.pressed.connect(_on_btn_continue_pressed)
	btn_desktop.pressed.connect(_on_btn_desktop_pressed)
	vbox.resized.connect(_sync_hero_card)

	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("has_save_file") and gs.has_save_file() and gs.load_game():
		var pct: int = int(gs.get_restoration_percent())
		var coins: int = int(gs.coins)
		save_progress_box.visible = true
		save_progress_label.text = "Progreso de restauración: %d %%  ·  Reserva: %d monedas" % [pct, coins]
		save_progress_bar.value = float(pct)
		btn_continue.text = "Continuar Granja (%d %% restaurada · %d monedas)" % [pct, coins]
		btn_continue.visible = true
		btn_continue.theme_type_variation = &"StationPrimary"
		btn_desktop.theme_type_variation = &"StationAccent"
		btn_continue.grab_focus()
	else:
		save_progress_box.visible = false
		btn_continue.visible = false
		btn_desktop.theme_type_variation = &"StationPrimary"
		btn_desktop.grab_focus()

	call_deferred("_sync_hero_card")

func _style_progress_bar() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = StationTheme.INPUT_BG
	track.border_color = StationTheme.BORDER_STRONG
	track.set_border_width_all(1)
	track.set_corner_radius_all(6)
	save_progress_bar.add_theme_stylebox_override("background", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = StationTheme.MINT
	fill.set_corner_radius_all(6)
	save_progress_bar.add_theme_stylebox_override("fill", fill)

func _sync_hero_card() -> void:
	if not is_instance_valid(hero_card) or not is_instance_valid(vbox):
		return
	var pad := Vector2(72.0, 56.0)
	var min_sz := vbox.get_combined_minimum_size()
	var card_sz := Vector2(maxf(vbox.size.x, min_sz.x), maxf(vbox.size.y, min_sz.y)) + pad
	hero_card.offset_left = -card_sz.x * 0.5
	hero_card.offset_right = card_sz.x * 0.5
	hero_card.offset_top = -card_sz.y * 0.5
	hero_card.offset_bottom = card_sz.y * 0.5

func _on_btn_continue_pressed() -> void:
	btn_continue.disabled = true
	btn_desktop.disabled = true
	btn_continue.text = "Cargando..."
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_btn_desktop_pressed() -> void:
	btn_continue.disabled = true
	btn_desktop.disabled = true
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("reset_new_game"):
		gs.reset_new_game(true)
	btn_desktop.text = "Cargando..."
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
