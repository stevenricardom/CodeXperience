extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBoxContainer/BtnVR.pressed.connect(_on_btn_vr_pressed)
	$VBoxContainer/BtnDesktop.pressed.connect(_on_btn_desktop_pressed)

func _on_btn_vr_pressed() -> void:
	$VBoxContainer/BtnVR.text = "Cargando..."
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main/mainXR.tscn")

func _on_btn_desktop_pressed() -> void:
	$VBoxContainer/BtnDesktop.text = "Cargando..."
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
