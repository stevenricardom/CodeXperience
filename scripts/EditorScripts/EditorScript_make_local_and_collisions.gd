@tool
extends EditorScript

func _run():
	var root = get_scene()
	if not root:
		print("⚠️ Abre primero la escena donde tienes tus bloques.")
		return
		
	print("🚀 Procesando la escena '", root.name, "'...")
	var count = 0
	
	# Iteramos hacia atrás para poder borrar contenedores de forma segura
	for i in range(root.get_child_count() - 1, -1, -1):
		var nodo_base = root.get_child(i)
		
		# Evitar procesar piezas que ya fueron convertidas
		if nodo_base is MeshInstance3D and nodo_base.scene_file_path == "":
			continue
		
		# 1. MAKE LOCAL: Romper el vínculo con el archivo .glb
		nodo_base.scene_file_path = ""
		nodo_base.owner = root
		
		var mesh = _get_mesh(nodo_base)
		
		if mesh:
			var nombre_original = nodo_base.name
			
			# 2. EXTRAER MESH Y MANTENER TRANSFORMACIÓN
			if mesh.get_parent() != root:
				var global_trans = mesh.global_transform
				mesh.get_parent().remove_child(mesh)
				root.add_child(mesh)
				mesh.global_transform = global_trans
				mesh.name = nombre_original
				
			mesh.owner = root
			
			# 3. COLOCAR COLISIONES (Buscar o generar)
			var col = _get_body(nodo_base)
			if not col:
				col = _get_body(mesh)
				
			if not col:
				mesh.create_trimesh_collision()
				col = _get_body(mesh)
			
			# Ajustar la jerarquía de la colisión manteniendo su posición
			if col and col.get_parent() != mesh:
				var col_trans = col.global_transform
				col.get_parent().remove_child(col)
				mesh.add_child(col)
				col.global_transform = col_trans
			
			# Asignar permisos (owner) para guardar los datos
			if col:
				col.owner = root
				for shape in col.get_children():
					shape.owner = root
			
			# 4. ELIMINAR EL CONTENEDOR VIEJO
			if nodo_base != mesh and nodo_base.get_parent() == root:
				nodo_base.queue_free()
				
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
