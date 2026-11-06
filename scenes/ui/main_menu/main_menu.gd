extends Control

const StationTheme = preload("res://scenes/ui/theme/station_theme.gd")

func _ready() -> void:
	theme = StationTheme.get_theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBoxContainer/BtnDesktop.pressed.connect(_on_btn_desktop_pressed)
	$VBoxContainer/BtnDesktop.grab_focus()

func _on_btn_desktop_pressed() -> void:
	$VBoxContainer/BtnDesktop.text = "Cargando..."
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
