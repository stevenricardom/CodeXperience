@tool
extends EditorScript

# ⚠️ CAMBIA ESTO: Pon aquí la ruta de la carpeta donde tienes tus archivos .glb
const DIRECTORIO_ORIGEN = "res://resources/models/farm_models/vehicles/tractor/" 
# Ruta donde se guardarán las escenas finales
const DIRECTORIO_DESTINO = "res://assets/scenes/farm_assets/vehicles/"

func _run():
	print("🚀 Iniciando conversión masiva de .glb a .tscn...")

	# 1. Asegurar que el directorio de destino exista
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(DIRECTORIO_DESTINO):
		dir.make_dir_recursive(DIRECTORIO_DESTINO)

	# 2. Abrir el directorio de origen
	var source_dir = DirAccess.open(DIRECTORIO_ORIGEN)
	if not source_dir:
		print("⚠️ Error: No se encontró la carpeta de origen: ", DIRECTORIO_ORIGEN)
		return

	var count = 0
	source_dir.list_dir_begin()
	var file_name = source_dir.get_next()

	# 3. Iterar sobre todos los archivos de la carpeta
	while file_name != "":
		# Ignorar carpetas y procesar solo archivos .glb
		if not source_dir.current_is_dir() and file_name.ends_with(".glb"):
			_convertir_glb_a_tscn(DIRECTORIO_ORIGEN + file_name, file_name)
			count += 1
		file_name = source_dir.get_next()

	print("✅ ¡Perfecto! ", count, " archivos convertidos y guardados en ", DIRECTORIO_DESTINO)

func _convertir_glb_a_tscn(file_path: String, file_name: String):
	# Cargar el archivo .glb original en memoria
	var glb_scene: PackedScene = load(file_path)
	if not glb_scene:
		return

	# Instanciarlo virtualmente (sin agregarlo a ninguna escena abierta)
	var root_node = glb_scene.instantiate()
	var clean_name = file_name.replace(".glb", "") # Quitamos la extensión para el nombre

	# 1. Buscar la malla visual (MeshInstance3D)
	var mesh = _get_mesh(root_node)
	if not mesh:
		print("⚠️ Omitido: No se encontró malla en ", file_name)
		root_node.free()
		return

	# 2. HACER NODO PADRE AL MESH (Estructura Reddit)
	if mesh.get_parent():
		mesh.get_parent().remove_child(mesh)
	
	mesh.name = clean_name
	
	# 3. COLOCAR COLISIONES
	var col = _get_body(root_node)
	if not col:
		col = _get_body(mesh)

	if not col:
		# Generar colisión trimesh si no tiene ninguna
		mesh.create_trimesh_collision()
		col = _get_body(mesh)

	# 4. Anidar la colisión estrictamente dentro de la malla (Hijo directo)
	if col and col.get_parent() != mesh:
		if col.get_parent():
			col.get_parent().remove_child(col)
		mesh.add_child(col)

	# 5. ASIGNAR OWNER: Para guardar como escena (.tscn), todo nodo hijo debe tener 
	#    como 'owner' al nodo raíz de la escena (en este caso, la malla extraída).
	_set_owner_recursive(mesh, mesh)

	# 6. EMPAQUETAR Y GUARDAR
	var packed_scene = PackedScene.new()
	packed_scene.pack(mesh) # Empaqueta el MeshInstance3D junto con su StaticBody3D

	var save_path = DIRECTORIO_DESTINO + clean_name + ".tscn"
	ResourceSaver.save(packed_scene, save_path)
	print("💾 Guardado: ", save_path)

	# Limpieza de nodos en memoria RAM
	if root_node and is_instance_valid(root_node):
		root_node.free()
	if mesh and is_instance_valid(mesh):
		mesh.free()

# Funciones auxiliares de búsqueda (recursivas)
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

func _set_owner_recursive(node: Node, scene_root: Node):
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
