@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		print("⚠️ No hay ninguna escena abierta en el editor.")
		return

	print("🚀 Procesando nodos de la escena '", root.name, "'...")
	var contador = 0

	# 1. Recorremos los nodos base de cada pieza (ej. block-grass-corner)
	for hijo in root.get_children():
		_procesar_pieza(hijo, root)
		contador += 1

	print("✅ ¡Completado! Se convirtieron a locales y se reorganizaron ", contador, " piezas como hermanos.")

func _procesar_pieza(nodo_pieza: Node, scene_root: Node):
	# Hacer la pieza local
	nodo_pieza.scene_file_path = ""
	nodo_pieza.owner = scene_root
	
	# 2. Buscar el MeshInstance3D dentro de la pieza
	var mesh_instance = _encontrar_mesh(nodo_pieza)
	if not mesh_instance:
		return
		
	mesh_instance.owner = scene_root

	# 3. Generar la colisión si no la tiene
	var static_body = _encontrar_static_body(mesh_instance)
	if not static_body:
		mesh_instance.create_trimesh_collision()
		# Al crearla, Godot la mete dentro del mesh. La volvemos a buscar:
		static_body = _encontrar_static_body(mesh_instance)

	# 4. LA CORRECCIÓN: Si el StaticBody quedó dentro del Mesh, lo sacamos para que sean hermanos
	if static_body and static_body.get_parent() == mesh_instance:
		mesh_instance.remove_child(static_body)
		nodo_pieza.add_child(static_body) # Ahora cuelga de la pieza principal
		
	# 5. Asignar el owner a la colisión y a su forma geométrica
	if static_body:
		static_body.owner = scene_root
		for shape in static_body.get_children():
			shape.owner = scene_root

func _encontrar_mesh(nodo: Node) -> MeshInstance3D:
	if nodo is MeshInstance3D:
		return nodo
	for child in nodo.get_children():
		if child is MeshInstance3D:
			return child
		var res = _encontrar_mesh(child)
		if res:
			return res
	return null

func _encontrar_static_body(nodo: Node) -> StaticBody3D:
	for child in nodo.get_children():
		if child is StaticBody3D:
			return child
	return null
