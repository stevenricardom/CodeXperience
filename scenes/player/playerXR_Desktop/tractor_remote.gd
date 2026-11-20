class_name TractorRemote
extends Node3D
## Control remoto 3D en la mano derecha del jugador para ejecutar el código del tractor.

const STANDBY_COLOR := Color(0.12, 0.88, 0.42)

var _built: bool = false
var _run_button: MeshInstance3D = null
var _status_led_mat: StandardMaterial3D = null
var _antenna_tip_mat: StandardMaterial3D = null
var _signal_pulse: MeshInstance3D = null
var _signal_pulse_mat: StandardMaterial3D = null
var _press_tween: Tween = null
var _pulse_tween: Tween = null

func _ready() -> void:
	if position == Vector3.ZERO:
		position = Vector3(-0.014, -0.018, -0.062)
		rotation = Vector3(0.18, -0.08, deg_to_rad(108.0))
	_build_geometry()

func _build_geometry() -> void:
	if _built:
		return
	_built = true

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.11, 0.15, 0.22)
	body_mat.roughness = 0.75

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.046, 0.018, 0.072)
	body.mesh = body_mesh
	body.material_override = body_mat
	add_child(body)

	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.20, 0.27, 0.38)
	top_mat.roughness = 0.65

	var top_plate := MeshInstance3D.new()
	top_plate.name = "TopPlate"
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(0.038, 0.003, 0.062)
	top_plate.mesh = top_mesh
	top_plate.position = Vector3(0.0, 0.010, 0.0)
	top_plate.material_override = top_mat
	add_child(top_plate)

	var button_mat := StandardMaterial3D.new()
	button_mat.albedo_color = Color(0.18, 0.86, 0.46)
	button_mat.emission_enabled = true
	button_mat.emission = Color(0.10, 0.65, 0.32)
	button_mat.emission_energy_multiplier = 0.7

	_run_button = MeshInstance3D.new()
	_run_button.name = "RunButton"
	var button_mesh := CylinderMesh.new()
	button_mesh.top_radius = 0.012
	button_mesh.bottom_radius = 0.013
	button_mesh.height = 0.009
	_run_button.mesh = button_mesh
	_run_button.position = Vector3(0.0, 0.014, 0.005)
	_run_button.material_override = button_mat
	add_child(_run_button)

	var button_label := Label3D.new()
	button_label.name = "ButtonLabel"
	button_label.position = Vector3(0.0, 0.0195, 0.005)
	button_label.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	button_label.text = "RUN"
	button_label.font_size = 16
	button_label.pixel_size = 0.00045
	button_label.outline_size = 4
	button_label.outline_modulate = Color(0.03, 0.05, 0.08, 1.0)
	button_label.modulate = Color(0.95, 1.0, 0.96, 1.0)
	add_child(button_label)

	var ok_color := STANDBY_COLOR
	_status_led_mat = StandardMaterial3D.new()
	_status_led_mat.albedo_color = ok_color
	_status_led_mat.emission_enabled = true
	_status_led_mat.emission = ok_color
	_status_led_mat.emission_energy_multiplier = 1.2

	var status_led := MeshInstance3D.new()
	status_led.name = "StatusLed"
	var led_mesh := SphereMesh.new()
	led_mesh.radius = 0.0035
	led_mesh.height = 0.007
	status_led.mesh = led_mesh
	status_led.position = Vector3(0.0, 0.0125, -0.020)
	status_led.material_override = _status_led_mat
	add_child(status_led)

	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.32, 0.36, 0.44)
	stem_mat.metallic = 0.5
	stem_mat.roughness = 0.4

	var antenna_stem := MeshInstance3D.new()
	antenna_stem.name = "AntennaStem"
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.0018
	stem_mesh.bottom_radius = 0.0026
	stem_mesh.height = 0.036
	antenna_stem.mesh = stem_mesh
	antenna_stem.position = Vector3(0.011, 0.004, -0.052)
	antenna_stem.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	antenna_stem.material_override = stem_mat
	add_child(antenna_stem)

	_antenna_tip_mat = StandardMaterial3D.new()
	_antenna_tip_mat.albedo_color = ok_color
	_antenna_tip_mat.emission_enabled = true
	_antenna_tip_mat.emission = ok_color
	_antenna_tip_mat.emission_energy_multiplier = 1.2

	var antenna_tip := MeshInstance3D.new()
	antenna_tip.name = "AntennaTip"
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.0042
	tip_mesh.height = 0.0084
	antenna_tip.mesh = tip_mesh
	antenna_tip.position = Vector3(0.011, 0.004, -0.072)
	antenna_tip.material_override = _antenna_tip_mat
	add_child(antenna_tip)

	_signal_pulse_mat = StandardMaterial3D.new()
	_signal_pulse_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_signal_pulse_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_signal_pulse_mat.albedo_color = Color(ok_color.r, ok_color.g, ok_color.b, 0.75)
	_signal_pulse_mat.emission_enabled = true
	_signal_pulse_mat.emission = ok_color
	_signal_pulse_mat.emission_energy_multiplier = 1.4

	_signal_pulse = MeshInstance3D.new()
	_signal_pulse.name = "SignalPulse"
	var pulse_mesh := CylinderMesh.new()
	pulse_mesh.top_radius = 0.012
	pulse_mesh.bottom_radius = 0.012
	pulse_mesh.height = 0.002
	_signal_pulse.mesh = pulse_mesh
	_signal_pulse.position = Vector3(0.011, 0.004, -0.072)
	_signal_pulse.visible = false
	_signal_pulse.material_override = _signal_pulse_mat
	add_child(_signal_pulse)

func play_press_animation(status: String = "ok") -> void:
	_build_geometry()
	var col := _status_color(status)
	_status_led_mat.albedo_color = col
	_status_led_mat.emission = col
	_antenna_tip_mat.albedo_color = col
	_antenna_tip_mat.emission = col
	_signal_pulse_mat.albedo_color = Color(col.r, col.g, col.b, 0.75)
	_signal_pulse_mat.emission = col

	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_run_button.position.y = 0.014
	if not is_inside_tree():
		_signal_pulse.visible = false
		return

	_press_tween = create_tween()
	_press_tween.tween_property(_run_button, "position:y", 0.0095, 0.07)
	_press_tween.tween_property(_run_button, "position:y", 0.014, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_press_tween.tween_interval(0.45)
	_press_tween.tween_callback(func() -> void:
		if _status_led_mat != null:
			_status_led_mat.albedo_color = STANDBY_COLOR
			_status_led_mat.emission = STANDBY_COLOR
		if _antenna_tip_mat != null:
			_antenna_tip_mat.albedo_color = STANDBY_COLOR
			_antenna_tip_mat.emission = STANDBY_COLOR
	)

	_signal_pulse.visible = true
	_signal_pulse.scale = Vector3.ONE * 0.4
	_pulse_tween = create_tween()
	_pulse_tween.set_parallel(true)
	_pulse_tween.tween_property(_signal_pulse, "scale", Vector3.ONE * 3.2, 0.30)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_signal_pulse_mat, "albedo_color:a", 0.0, 0.30)
	_pulse_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_signal_pulse):
			_signal_pulse.visible = false
	)

func _status_color(status: String) -> Color:
	match status:
		"busy":
			return Color(0.95, 0.65, 0.10)
		"error":
			return Color(0.90, 0.16, 0.20)
		_:
			return STANDBY_COLOR
