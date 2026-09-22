extends SceneTree

func _init():
	var lib = load("res://assets/meshlibrary/preset_result_tiles/tiles_meshlibrary/assets_nature_tiles.tres")
	if lib:
		print("MeshLibrary loaded. Items:")
		for id in lib.get_item_list():
			print(str(id) + ": " + lib.get_item_name(id))
	else:
		print("Failed to load MeshLibrary")
	quit()
