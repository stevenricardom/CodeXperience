extends XRController3D

@export var max_reach: float = 0.85
@export var max_drop: float = 0.65
@export var max_side: float = 0.5

@onready var camera: XRCamera3D = $"../XRCamera3D"

# Memoria para rastrear el movimiento de la cámara
var _last_camera_transform: Transform3D

func _ready() -> void:
	if camera:
		_last_camera_transform = camera.global_transform

func _process(_delta: float) -> void:
	if not get_viewport().use_xr and camera:
		
		# --- NUEVO: Arrastrar las manos al girar la cabeza ---
		var current_cam_transform := camera.global_transform
		if current_cam_transform != _last_camera_transform:
			# Calculamos cuánto rotó la cámara en este fotograma exacto
			var delta_transform := current_cam_transform * _last_camera_transform.affine_inverse()
			# Le aplicamos esa misma rotación a la mano
			global_transform = delta_transform * global_transform
		# -----------------------------------------------------

		# 1. Límite esférico
		var offset: Vector3 = position - camera.position
		if offset.length() > max_reach:
			position = camera.position + (offset.normalized() * max_reach)
			
		# 2. Límite estricto de "techo"
		if position.y > camera.position.y:
			position.y = camera.position.y
			
		# 3. Límite estricto de "suelo"
		if position.y < camera.position.y - max_drop:
			position.y = camera.position.y - max_drop
			
		# 4. Restricción de Campo de Visión (Frente a la cámara y lados)
		var local_pos: Vector3 = camera.to_local(global_position)
		var pos_changed: bool = false
		
		if local_pos.z > -0.1:
			local_pos.z = -0.1
			pos_changed = true
			
		# 5. Límite para izquierda y derecha
		var clamped_x: float = clamp(local_pos.x, -max_side, max_side)
		if local_pos.x != clamped_x:
			local_pos.x = clamped_x
			pos_changed = true
			
		if pos_changed:
			global_position = camera.to_global(local_pos)

		# Actualizamos la memoria de la cámara para el siguiente fotograma
		_last_camera_transform = camera.global_transform
