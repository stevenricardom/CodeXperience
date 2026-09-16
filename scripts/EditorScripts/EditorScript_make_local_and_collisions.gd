@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		print("⚠️ Abre primero la escena donde tienes tus bloques.")
		return
		
	print("🚀 Aplicando estructura de Reddit a '", root.name, "'...")
	var count = 0
	
	# Iteramos hacia atrás para poder borrar contenedores viejos de forma segura
	for i in range(root.get_child_count() - 1, -1, -1):
		var nodo_base = root.get_child(i)
		
		# 1. MAKE LOCAL: Romper el vínculo con el archivo .glb original
		nodo_base.scene_file_path = ""
		nodo_base.owner = root
		
		# Buscar la malla visual dentro del contenedor importado
		var mesh = _get_mesh(nodo_base)
		
		if mesh:
			# Guardamos el nombre original de la pieza (ej. "block-grass")
			var nombre_original = nodo_base.name
			
			# 2. HACER NODO PADRE AL MESH: Extraerlo y ponerlo en la raíz
			if mesh.get_parent() != root:
				mesh.get_parent().remove_child(mesh)
				root.add_child(mesh)
				mesh.owner = root
				mesh.name = nombre_original 
			
			# 3. COLOCAR COLISIONES: Buscar o generar
			var col = _get_body(nodo_base)
			if not col:
				col = _get_body(mesh)
				
			if not col:
				# Generar colisión automática si la pieza no la tiene
				mesh.create_trimesh_collision()
				col = _get_body(mesh)
			
			# Asegurar la jerarquía (Reddit): MeshInstance3D -> StaticBody3D -> CollisionShape
			if col and col.get_parent() != mesh:
				col.get_parent().remove_child(col)
				mesh.add_child(col)
			
			# Asignar permisos (owner) para que Godot guarde todo en el archivo final
			if col:
				col.owner = root
				for shape in col.get_children():
					shape.owner = root
			
			# Eliminar el contenedor .glb viejo que ahora quedó vacío
			if nodo_base != mesh and nodo_base.get_parent() == root:
				nodo_base.free()
				
			count += 1
			
	print("✅ ¡Listo! ", count, " piezas convertidas a la estructura correcta.")

func _get_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D: return n
	for c in n.get_children():
		var res = _get_mesh(c)
		if res: return res
	return null

func _get_body(n: Node) -> StaticBody3D:
	if n is StaticBody3D: return n
	for c in n.get_children():
		var res = _get_body(c)
		if res: return res
	return null
