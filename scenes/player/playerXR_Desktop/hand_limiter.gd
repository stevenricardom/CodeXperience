extends XRController3D
## Seguimiento de la mano en el ESPACIO LOCAL de la cámara.
##
## Sustituye al antigo control por teclas Q/E: la mano se posiciona sola,
## interpolada de forma exponencial (sin saltos ni overshoot) hacia un objetivo
## calculado en el espacio local de la cámara. No lee ninguna tecla.
##
## Poses: reposo (idle), señalar (point, al programar) y agarrar (grab, con el
## puntero pulsado). La pose solo anima el visual de la mano: ni la cámara ni
## el cuerpo se mueven.

enum HandPose { IDLE = 0, POINT = 1, GRAB = 2 }

## Posición de reposo en espacio local de la cámara (X se espeja en la izquierda).
@export var rest_local: Vector3 = Vector3(0.16, -0.165, -0.30)
## Velocidad de convergencia de la posición (1/s).
@export var follow_speed: float = 6.0
## Velocidad de convergencia de la orientación (1/s).
@export var pose_blend_speed: float = 8.0
## Amplitud del balanceo en reposo.
@export var sway_amount: float = 0.010
## Frecuencia del balanceo en reposo.
@export var sway_speed: float = 0.9
## Distancia a la que se apunta (metros, hacia delante de la cámara).
@export var pointer_depth: float = 0.55
## Cuánto se acerca la mano al centro al señalar.
@export var point_inward: float = 0.030
## Cuánto se acerca la mano al centro al agarrar.
@export var grab_inward: float = 0.055
## Inclinación de reposo de los dedos (negativo = dedos hacia abajo).
@export var rest_pitch: float = -0.12
## Giro de reposo hacia el centro de la vista.
@export var rest_yaw: float = 0.30

var hand_pose: int = HandPose.IDLE
var pointer_normalized: Vector2 = Vector2(0.5, 0.5)
var use_viewport_pointer: bool = true

var _camera: Camera3D
var _interaction: Node
var _visual: Node3D
var _is_left: bool = false
var _rest: Vector3
var _rest_basis: Basis
var _local_position: Vector3
var _local_basis: Basis
var _time: float = 0.0

func _ready() -> void:
	_is_left = tracker == &"left_hand"
	_rest = rest_local
	_rest.x = -absf(_rest.x) if _is_left else absf(_rest.x)
	var yaw: float = -rest_yaw if _is_left else rest_yaw
	_rest_basis = Basis.from_euler(Vector3(rest_pitch, yaw, 0.0))
	_local_position = _rest
	_local_basis = _rest_basis
	_interaction = get_node_or_null("../DesktopInteraction")
	_visual = _find_visual()
	_camera = _find_camera()
	var in_xr: bool = get_viewport() != null and get_viewport().use_xr
	if in_xr:
		# En XR real el pose lo lleva el tracker: la mano no se recoloca.
		set_process(false)
		return
	if _camera:
		global_position = _camera.to_global(_local_position)

func _process(delta: float) -> void:
	# En XR real el pose viene del tracker: no lo sobrescribimos.
	if get_viewport() and get_viewport().use_xr:
		set_process(false)
		return
	tick(delta)

## Paso de simulación aislado (las pruebas pueden invocarlo directamente).
func tick(delta: float) -> void:
	var camera: Camera3D = _camera if is_instance_valid(_camera) else _find_camera()
	if camera == null:
		return
	_time += delta
	_update_pose_state()
	_update_pointer(camera)

	var target_position: Vector3 = _target_position()
	var position_alpha: float = 1.0 - exp(-follow_speed * delta)
	_local_position = _local_position.lerp(target_position, position_alpha)

	var target_basis: Basis = _target_basis(camera)
	var basis_alpha: float = 1.0 - exp(-pose_blend_speed * delta)
	_local_basis = _local_basis.slerp(target_basis, basis_alpha)

	global_position = camera.to_global(_local_position)
	global_basis = camera.global_basis * _local_basis

	if not is_instance_valid(_visual):
		_visual = _find_visual()
	if is_instance_valid(_visual) and _visual.has_method("set_pose"):
		_visual.set_pose(hand_pose_name(), delta)

func _find_camera() -> Camera3D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("XRCamera3D") as Camera3D

func _find_visual() -> Node3D:
	for child in get_children():
		if child.has_method("set_pose"):
			return child as Node3D
	return null

func _update_pose_state() -> void:
	var pose: int = HandPose.IDLE
	if is_instance_valid(_interaction):
		var programming: bool = false
		if _interaction.has_method("is_programming"):
			programming = _interaction.is_programming()
		var pressed: bool = bool(_interaction.get("pointer_pressed"))
		if programming:
			pose = HandPose.GRAB if pressed else HandPose.POINT
	hand_pose = pose

func _update_pointer(camera: Camera3D) -> void:
	if not use_viewport_pointer:
		return
	if not is_instance_valid(_interaction) or not _interaction.has_method("is_programming"):
		return
	if not _interaction.is_programming():
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var rect: Rect2 = viewport.get_visible_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var mouse: Vector2 = viewport.get_mouse_position()
	pointer_normalized = Vector2(
		clampf(mouse.x / rect.size.x, 0.0, 1.0),
		clampf(mouse.y / rect.size.y, 0.0, 1.0))

func _target_position() -> Vector3:
	var sway: float = sin(_time * sway_speed * TAU) * sway_amount
	match hand_pose:
		HandPose.POINT:
			return Vector3(
				_rest.x * (1.0 - point_inward / maxf(absf(_rest.x), 0.001)),
				_rest.y + 0.020 + sway * 0.5,
				_rest.z - 0.030)
		HandPose.GRAB:
			return Vector3(
				_rest.x * (1.0 - grab_inward / maxf(absf(_rest.x), 0.001)),
				_rest.y + 0.030 + sway * 0.3,
				_rest.z - 0.060)
		_:
			return Vector3(_rest.x, _rest.y + sway, _rest.z)

func _target_basis(camera: Camera3D) -> Basis:
	if hand_pose == HandPose.IDLE:
		return _rest_basis
	var aim: Vector3 = _aim_local(camera)
	if aim.length_squared() < 0.000001:
		return _rest_basis
	var up: Vector3 = Vector3.UP
	if absf(aim.normalized().dot(up)) > 0.98:
		up = Vector3.FORWARD
	return Basis.looking_at(aim, up)

func _aim_local(camera: Camera3D) -> Vector3:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector3.ZERO
	var rect: Rect2 = viewport.get_visible_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector3.ZERO
	var screen: Vector2 = Vector2(
		pointer_normalized.x * rect.size.x,
		pointer_normalized.y * rect.size.y)
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	var local_direction: Vector3 = (camera.global_basis.inverse() * direction).normalized()
	var depth: float = maxf(pointer_depth, 0.05)
	var forward: float = -local_direction.z
	if forward < 0.15:
		forward = 0.15
	return local_direction * (depth / forward)

func get_local_position() -> Vector3:
	return _local_position

func get_local_basis() -> Basis:
	return _local_basis

func get_rest_local() -> Vector3:
	return _rest

func hand_pose_name() -> String:
	match hand_pose:
		HandPose.POINT:
			return "point"
		HandPose.GRAB:
			return "grab"
		_:
			return "idle"
