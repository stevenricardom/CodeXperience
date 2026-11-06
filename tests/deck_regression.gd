extends SceneTree
## Run: Godot --headless --path . --script res://tests/deck_regression.gd
## Regresion del palco de programacion (observation_deck) y de los cuatro paneles.

const DECK_SCENE := "res://scenes/world/observation_deck.tscn"
const MAIN_SCENE := "res://scenes/main/main.tscn"

# Geometria acordada del palco (coordenadas de mundo).
const DECK_TOP := 2.45
const GROUND_Y := 0.95
const DECK_X_MIN := -4.0
const DECK_X_MAX := 6.0
const DECK_Z_MIN := 44.0
const DECK_Z_MAX := 52.0
const RAMP_X_TOP := 6.0
const RAMP_X_BOTTOM := 12.0
const RAMP_Z_MIN := 44.0
const RAMP_Z_MAX := 47.0
const RAMP_RISE := 1.5
const RAMP_RUN := 6.0
const SPAWN_X := 13.5
const SPAWN_Z := 45.5
const FIELD_X_MIN := -2.0
const FIELD_X_MAX := 14.0
const FIELD_Z_MIN := 22.0
const FIELD_Z_MAX := 38.0

var passed := 0
var failed := 0
var aborted := 0
var deck: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(20.0).timeout.connect(func(): quit(1))
	for test_name in [
		"test_deck_scene_exists",
		"test_deck_floor_physics",
		"test_ramp_physics",
		"test_route_is_continuous",
		"test_deck_does_not_invade_field",
		"test_four_desktop_panels",
		"test_main_keeps_node_paths",
	]:
		print("Deck test: ", test_name)
		var result = await call(test_name)
		if result != true:
			aborted += 1
			check(false, test_name + " did not finish")
	if is_instance_valid(deck):
		deck.queue_free()
		await process_frame
	print("Deck regression: %d passed, %d failed, %d aborted" % [passed, failed, aborted])
	quit(1 if (failed > 0 or aborted > 0) else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func ray_down(x: float, z: float) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(
		Vector3(x, 30.0, z), Vector3(x, -5.0, z)
	)
	params.collision_mask = 1
	return root.get_world_3d().direct_space_state.intersect_ray(params)

func test_deck_scene_exists() -> bool:
	check(ResourceLoader.exists(DECK_SCENE), "observation_deck scene exists")
	return true

func test_deck_floor_physics() -> bool:
	if not ResourceLoader.exists(DECK_SCENE):
		return true
	deck = load(DECK_SCENE).instantiate()
	root.add_child(deck)
	await physics_frame
	await physics_frame
	for point in [Vector2(-3, 45), Vector2(1, 47), Vector2(5, 49), Vector2(-1, 51)]:
		var hit := ray_down(point.x, point.y)
		check(not hit.is_empty(), "deck floor is solid at %.0f,%.0f" % [point.x, point.y])
		if not hit.is_empty():
			check(
				absf(hit.position.y - DECK_TOP) < 0.12,
				"deck floor height at %.0f,%.0f is %.2f" % [point.x, point.y, hit.position.y]
			)
	return true

func test_ramp_physics() -> bool:
	if deck == null:
		return true
	var previous := INF
	for x in [6.5, 8.0, 9.5, 11.0]:
		var hit := ray_down(x, 45.5)
		check(not hit.is_empty(), "ramp surface exists at x=%.1f" % x)
		if hit.is_empty():
			continue
		var expected: float = DECK_TOP - (x - RAMP_X_TOP) / RAMP_RUN * RAMP_RISE
		check(
			absf(hit.position.y - expected) < 0.12,
			"ramp surface at x=%.1f is %.2f (expected %.2f)" % [x, hit.position.y, expected]
		)
		if previous < INF:
			check(
				absf(previous - hit.position.y) < 0.40,
				"ramp is walkable between x=%.1f and x=%.1f" % [x - 1.5, x]
			)
		previous = hit.position.y
	# El final de la rampa continua con el suelo.
	var bottom := ray_down(RAMP_X_BOTTOM + 0.5, 45.5)
	check(not bottom.is_empty(), "ground continues after the ramp")
	if not bottom.is_empty():
		check(
			absf(bottom.position.y - GROUND_Y) < 0.12,
			"ramp ends on the ground (%.2f)" % bottom.position.y
		)
	return true

func test_route_is_continuous() -> bool:
	if deck == null:
		return true
	# Recorrido spawn -> rampa -> palco -> punto de vista de los paneles.
	var path := [SPAWN_X, 12.5, 11.0, 9.5, 8.0, 6.5, 5.0, 3.0, 1.0]
	var heights: Array[float] = []
	for x in path:
		var hit := ray_down(x, SPAWN_Z)
		check(not hit.is_empty(), "route has ground at x=%.1f" % x)
		if not hit.is_empty():
			heights.append(hit.position.y)
	for i in range(1, heights.size()):
		check(
			absf(heights[i] - heights[i - 1]) < 0.45,
			"route step between x=%.1f and x=%.1f is %.2f" % [path[i - 1], path[i], absf(heights[i] - heights[i - 1])]
		)
	check(
		heights.size() == path.size() and heights[heights.size() - 1] > DECK_TOP - 0.2,
		"route ends on the deck"
	)
	return true

func test_deck_does_not_invade_field() -> bool:
	if deck == null:
		return true
	for point in [Vector2(6, 30), Vector2(-1, 38), Vector2(10, 25), Vector2(2, 36)]:
		var hit := ray_down(point.x, point.y)
		check(hit.is_empty(), "standalone deck does not occupy field at %.0f,%.0f" % [point.x, point.y])
		if not hit.is_empty():
			check(
				absf(hit.position.y - GROUND_Y) < 0.12,
				"deck does not invade the field at %.0f,%.0f (%.2f)" % [point.x, point.y, hit.position.y]
			)
	# La posicion inicial del tractor queda libre.
	var spawn := ray_down(-0.87, 39.44)
	check(
		spawn.is_empty() or absf(spawn.position.y - GROUND_Y) < 0.5,
		"tractor start position is not blocked by the deck"
	)
	# Todo elDeck queda por detras de z40.
	var deck_aabb := AABB(
		Vector3(DECK_X_MIN, 0, DECK_Z_MIN),
		Vector3(DECK_X_MAX - DECK_X_MIN, DECK_TOP, DECK_Z_MAX - DECK_Z_MIN)
	)
	check(deck_aabb.position.z >= 40.0, "deck is behind z40")
	check(deck_aabb.position.z > FIELD_Z_MAX + 0.5, "deck does not overlap the field")
	return true

func _collect_panels(node: Node, found: Array) -> void:
	if node.is_in_group("desktop_panels"):
		found.append(node)
	for child in node.get_children():
		_collect_panels(child, found)

func test_four_desktop_panels() -> bool:
	if not ResourceLoader.exists(DECK_SCENE):
		return true
	# Los paneles no necesitan estar en el arbol: headless no resuelve frame_post_draw.
	var sample: Node = load(MAIN_SCENE).instantiate()
	var found: Array = []
	_collect_panels(sample, found)
	check(found.size() == 4, "deck exposes exactly four desktop panels (%d)" % found.size())
	var names := []
	for panel in found:
		names.append(panel.get_meta("display_name", ""))
		check(panel.get("input_keyboard") == false, "panel %s disables keyboard input" % panel.name)
		check(panel.get("collision_layer") == 16, "panel %s uses collision layer 16" % panel.name)
		check(panel.has_node("Viewport"), "panel %s has a Viewport child" % panel.name)
		var screen: Vector2 = panel.get("screen_size")
		check(
			absf(screen.x / screen.y - 16.0 / 9.0) < 0.01,
			"panel %s surface keeps 16:9 (%s)" % [panel.name, screen]
		)
		var viewport: Vector2 = panel.get("viewport_size")
		check(
			absf(viewport.x / viewport.y - 16.0 / 9.0) < 0.01,
			"panel %s resolution keeps 16:9 (%s)" % [panel.name, viewport]
		)
		var display_name: String = panel.get_meta("display_name", "")
		check(display_name != "", "panel %s has a display name" % panel.name)
		# Los paneles viven sobre el palco, fuera de la rampa y del paso.
		var world: Vector3 = sample.to_local(panel.transform.origin) if false else panel.position
		check(
			world.y > DECK_TOP - 0.2,
			"panel %s is raised over the deck" % panel.name
		)
		check(
			world.x >= DECK_X_MIN - 0.5 and world.x <= DECK_X_MAX + 0.5,
			"panel %s is inside the deck footprint" % panel.name
		)
		check(
			world.z >= DECK_Z_MIN - 0.5 and world.z <= DECK_Z_MAX + 0.5,
			"panel %s is inside the deck footprint" % panel.name
		)
		check(
			not (world.x >= RAMP_X_TOP - 1.0 and world.z >= RAMP_Z_MIN - 1.0 and world.z <= RAMP_Z_MAX + 1.0),
			"panel %s does not block the ramp" % panel.name
		)
	sample.free()
	return true

func test_main_keeps_node_paths() -> bool:
	if not ResourceLoader.exists(MAIN_SCENE):
		return true
	var main: Node = load(MAIN_SCENE).instantiate()
	for path in [
		"ProgrammingConsole/panel_code",
		"ProgrammingConsole/panel_actions",
		"ProgrammingConsole/panel_variables",
		"ProgrammingConsole/panel_camera",
	]:
		check(main.get_node_or_null(path) != null, "Main keeps the node path " + path)
	check(main.get("viewport_code") == main.get_node("ProgrammingConsole/panel_code"), "Main keeps the exported code path")
	check(main.get("viewport_actions") == main.get_node("ProgrammingConsole/panel_actions"), "Main keeps the exported actions path")
	check(main.get("viewport_variables") == main.get_node("ProgrammingConsole/panel_variables"), "Main keeps the exported variables path")
	var console: Node = main.get_node_or_null("ProgrammingConsole")
	check(console != null, "Main holds the deck console")
	if console != null:
		check(console.has_node("ObservationDeck"), "Main instances the deck scene")
	var player: Node3D = main.get_node_or_null("Actors/PlayerXR_Desktop")
	check(player != null, "Main keeps the desktop player")
	if player != null:
		var world_spawn := player.position
		check(
			absf(world_spawn.x - SPAWN_X) < 0.01 and absf(world_spawn.z - SPAWN_Z) < 0.01,
			"player spawns next to the ramp (%.2f,%.2f)" % [world_spawn.x, world_spawn.z]
		)
		check(
			absf(world_spawn.x - RAMP_X_BOTTOM) < 3.0,
			"player spawn is close to the bottom of the ramp"
		)
	main.free()
	return true
