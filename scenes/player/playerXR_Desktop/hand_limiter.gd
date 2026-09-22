extends XRController3D

## Posición de reposo en espacio LOCAL de la cámara.
## X se espeja automáticamente para la mano izquierda.
@export var rest_local: Vector3 = Vector3(0.12, -0.06, -0.22)

## Velocidad a la que la mano regresa al punto de reposo (0 = no regresa)
@export var return_speed: float = 3.0

## Tecla que el XR Simulator usa para mover esta mano (Q = izquierda, E = derecha).
## Se asigna automáticamente, pero puedes sobreescribirla en el Inspector.
@export var controller_key: Key = KEY_E

## Radio máximo de alcance desde la cámara
@export var max_reach: float = 0.65
## Cuánto puede bajar la mano bajo la cámara
@export var max_drop: float = 0.35
## Cuánto puede subir la mano SOBRE la cámara
@export var max_above: float = 0.20
## Cuánto puede alejarse a los lados
@export var max_side: float = 0.4
## Margen mínimo al frente (no puede quedar detrás de la cámara)
@export var front_margin: float = 0.22

## Rotación extra encima de la de la cámara (grados)
@export var rotation_offset_deg: Vector3 = Vector3(0.0, 0.0, 0.0)

## Velocidad a la que la rotación regresa al reposo tras soltar Shift
@export var rotation_return_speed: float = 5.0

@onready var camera: XRCamera3D = $"../XRCamera3D"

var _is_left_hand: bool = false
var _rot_offset: Basis
var _prev_camera_basis: Basis
var _rest: Vector3   # rest_local con X ya ajustada al lado correcto
var _is_rotating: bool = false   # true mientras Shift + tecla de mano está presionado

func _ready() -> void:
	_is_left_hand = (tracker == &"left_hand")
	_rest = rest_local
	if _is_left_hand:
		_rest.x = -abs(_rest.x)
	else:
		_rest.x =  abs(_rest.x)
	_rot_offset = Basis.from_euler(rotation_offset_deg * (PI / 180.0))
	# Asignamos la tecla por defecto según la mano (se puede sobreescribir en Inspector)
	if _is_left_hand:
		controller_key = KEY_Q
	else:
		controller_key = KEY_E
	set_process(not get_viewport().use_xr)
	# Guardamos la basis inicial de la cámara para calcular deltas
	await get_tree().process_frame
	if camera:
		_prev_camera_basis = camera.global_basis

func _process(_delta: float) -> void:
	if get_viewport().use_xr:
		set_process(false)
		return
	if not camera:
		return

	# ── 1. APLICAR DELTA DE ROTACIÓN DE CÁMARA ─────────────────────────────
	# Calculamos cuánto rotó la cámara desde el último frame.
	# Esa rotación se aplica directamente al offset de la mano respecto a la
	# cámara, de modo que la mano SIEMPRE sigue la rotación de cámara
	# de forma inmediata, sin zonas muertas.
	var cam_delta: Basis = camera.global_basis * _prev_camera_basis.inverse()
	var offset: Vector3 = global_position - camera.global_position
	var rotated_offset: Vector3 = cam_delta * offset

	# ── 2. PASAR A ESPACIO LOCAL DE CÁMARA ────────────────────────────────────
	var local_pos: Vector3 = camera.to_local(camera.global_position + rotated_offset)

	# ── 3. RETORNO AL PUNTO DE REPOSO ───────────────────────────────────────
	# Solo regresa cuando el jugador NO está sosteniendo la tecla del simulador.
	# Mientras Q / E está presionado, la mano la controla el XR Simulator.
	var key_held: bool = Input.is_key_pressed(controller_key)
	if return_speed > 0.0 and not key_held:
		local_pos = local_pos.lerp(_rest, return_speed * _delta)

	# ── 4. APLICAR LÍMITES ──────────────────────────────────────────────────
	# Límite esférico
	if local_pos.length() > max_reach:
		local_pos = local_pos.normalized() * max_reach

	# Vertical
	local_pos.y = clamp(local_pos.y, -max_drop, max_above)

	# Frente
	if local_pos.z > -front_margin:
		local_pos.z = -front_margin

	# Lados — asimétrico por mano para evitar que se bloqueen
	if _is_left_hand:
		local_pos.x = clamp(local_pos.x, -max_side, 0.0)
	else:
		local_pos.x = clamp(local_pos.x, 0.0, max_side)

	global_position = camera.to_global(local_pos)

	# ── 5. ROTACIÓN ─────────────────────────────────────────────────────────
	# Cuando Shift + tecla de mano están presionados, el XR Simulator rota la
	# mano vía rotate_device(). NO debemos sobrescribir la rotación en ese caso.
	var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
	var rest_basis: Basis = camera.global_basis * _rot_offset

	if key_held and shift_held:
		# Modo rotación activa: dejamos que el XR Simulator controle la rotación.
		# Solo aplicamos el delta de cámara para que la mano siga la cámara.
		global_basis = cam_delta * global_basis
		_is_rotating = true
	elif _is_rotating:
		# Acaba de soltar Shift o la tecla: interpolar de vuelta al reposo
		var current_quat: Quaternion = Quaternion(global_basis.orthonormalized())
		var rest_quat: Quaternion = Quaternion(rest_basis.orthonormalized())
		var blended: Quaternion = current_quat.slerp(rest_quat, rotation_return_speed * _delta)
		global_basis = Basis(blended)
		# Cuando está suficientemente cerca del reposo, dejamos de interpolar
		if current_quat.dot(rest_quat) > 0.999:
			global_basis = rest_basis
			_is_rotating = false
	else:
		# Estado normal: rotación fija siguiendo la cámara + offset
		global_basis = rest_basis

	# ── 6. GUARDAR BASIS PARA EL PRÓXIMO FRAME ──────────────────────────────
	_prev_camera_basis = camera.global_basis
