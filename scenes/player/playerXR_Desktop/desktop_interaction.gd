extends Node
## Único propietario del ratón/teclado del simulador desktop, sin iniciar OpenXR.

signal programming_changed(active: bool)

@export_range(1.0, 8.0, 0.1) var interaction_distance := 4.5
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity := 0.0022

var active_panel: Node3D
var hovered_panel: Node3D
var pointer_pressed := false
var _looking := true
var _session_open := false
var _buttons := 0
var _last_cursor := Vector2.ZERO
var _surface: SubViewport
var _hint: Label
var _reticle: Label
var _simulator: Node

@onready var camera: Camera3D = get_parent().get_node("XRCamera3D")

func _ready() -> void:
	_simulator = get_node_or_null("/root/XrSimulator")
	if _simulator:
		# Keep its simulated trackers, but not its old Q/E/mouse controls.
		_simulator.set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_hud()

func is_programming() -> bool:
	return is_instance_valid(active_panel)

func is_exploring() -> bool:
	return _looking and not is_programming()

func enter_programming(panel: Node3D) -> bool:
	if not is_instance_valid(panel) or not panel.is_visible_in_tree():
		return false
	if camera.global_position.distance_to(panel.global_position) > interaction_distance:
		return false
	var surface := panel.get_node_or_null("Viewport") as SubViewport
	if surface == null:
		return false
	exit_programming(false)
	active_panel = panel
	_session_open = true
	_surface = surface
	_looking = false
	_last_cursor = Vector2(surface.size) * 0.5
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	programming_changed.emit(true)
	_update_hint()
	return true

func exit_programming(capture_mouse: bool = true) -> void:
	if is_instance_valid(_surface):
		# End native drag before releasing, so leaving is cancel, not a drop.
		_surface.gui_cancel_drag()
		for index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			var bit: int = 1 << (index - 1)
			if _buttons & bit:
				_buttons &= ~bit
				var release := InputEventMouseButton.new()
				release.button_index = index
				release.position = _last_cursor
				release.button_mask = _buttons
				_surface.push_input(release, true)
		_surface.gui_release_focus()
	pointer_pressed = false
	_buttons = 0
	active_panel = null
	_session_open = false
	_surface = null
	_looking = capture_mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture_mouse else Input.MOUSE_MODE_VISIBLE
	programming_changed.emit(false)
	_update_hint()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_echo() and (event.is_action("desktop_interact") or event.is_action("desktop_cancel")) and not _is_typing():
		return
	if event.is_action_pressed("desktop_cancel"):
		exit_programming(is_programming() or not _looking)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("desktop_interact") and not _is_typing():
		if is_programming():
			exit_programming()
		elif is_instance_valid(hovered_panel):
			enter_programming(hovered_panel)
		get_viewport().set_input_as_handled()
		return
	if is_programming():
		if event is InputEventMouse:
			_route_pointer(event)
		elif event is InputEventKey:
			_surface.push_input(event, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_exploring():
		camera.rotation.y -= event.relative.x * mouse_sensitivity
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(-80), deg_to_rad(80))
		camera.rotation.z = 0.0
	elif event is InputEventMouseButton and event.pressed and not _looking:
		_looking = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _is_typing() -> bool:
	if not is_instance_valid(_surface):
		return false
	var focus := _surface.gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func _route_pointer(event: InputEventMouse) -> void:
	var plane := Plane(active_panel.global_basis.z.normalized(), active_panel.global_position)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
	if hit == null:
		return
	var local: Vector3 = active_panel.to_local(hit)
	var dimensions: Vector2 = active_panel.screen_size
	var position := Vector2(local.x / dimensions.x + 0.5, 0.5 - local.y / dimensions.y) * Vector2(_surface.size)
	var routed := event.duplicate() as InputEventMouse
	routed.position = position
	routed.global_position = position
	if routed is InputEventMouseMotion:
		routed.relative = position - _last_cursor
	elif routed is InputEventMouseButton:
		if routed.pressed and not Rect2(Vector2.ZERO, Vector2(_surface.size)).has_point(position):
			return
		if routed.button_index <= MOUSE_BUTTON_MIDDLE:
			var bit: int = 1 << (routed.button_index - 1)
			_buttons = (_buttons | bit) if routed.pressed else (_buttons & ~bit)
		pointer_pressed = bool(_buttons & MOUSE_BUTTON_MASK_LEFT)
	routed.button_mask = _buttons
	_last_cursor = position
	_surface.push_input(routed, true)

func _physics_process(_delta: float) -> void:
	if _session_open and not is_programming():
		exit_programming()
	if is_programming():
		if not active_panel.is_visible_in_tree():
			exit_programming()
		return
	# Ray hits world geometry too: panels cannot be selected through a wall.
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * interaction_distance, 1 | 16 | 128)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var target: Node3D
	if not hit.is_empty():
		var collider := hit.collider as Node
		if collider and collider.get_parent().is_in_group("desktop_panels"):
			target = collider.get_parent()
	if target != hovered_panel:
		hovered_panel = target
		_update_hint()

func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		exit_programming(false)

func _exit_tree() -> void:
	exit_programming(false)
	# Menu must not inherit a captured cursor or the simulator's old input.

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DesktopHUD"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_reticle = Label.new()
	_reticle.text = "+"
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reticle.position -= Vector2(7, 18)
	_reticle.add_theme_font_size_override("font_size", 28)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_reticle)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -76
	_hint.offset_bottom = -20
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.06))
	_hint.add_theme_constant_override("shadow_outline_size", 8)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)
	_update_hint()

func _update_hint() -> void:
	if not is_instance_valid(_hint):
		return
	_reticle.visible = not is_programming()
	if is_programming():
		_hint.text = "PROGRAMANDO  ·  Clic: seleccionar / arrastrar  ·  Rueda: desplazar  ·  E / Esc: volver"
	elif is_instance_valid(hovered_panel):
		_hint.text = "[ E ]  Programar  ·  " + str(hovered_panel.get_meta("display_name", "Panel"))
	else:
		_hint.text = "WASD  Moverse     ·     Ratón  Mirar     ·     Acércate a un panel y pulsa E"
