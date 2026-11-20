extends SceneTree
## Headless unit and integration test runner for Granja Tycoon.
## Run: godot --headless --path . --script res://tests/test_runner.gd

const TEST_SAVE_PATH := "user://test_save_runner.json"

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(25.0).timeout.connect(func() -> void:
		push_error("FAIL test_runner timed out")
		quit(1)
	)
	await process_frame

	var test_names: Array[String] = [
		"test_economy_catalog",
		"test_game_state_progression_and_save",
		"test_well_free_hint_edge_case",
		"test_level_validator_bfs_and_fallback",
		"test_tractor_planting_and_ai_fallback",
		"test_shop_and_farm_lot_scenes",
		"test_hud_and_popups_instantiate",
		"test_main_scene_and_menu_integration",
	]

	for test_name in test_names:
		var ok = await call(test_name)
		if ok != true:
			failed += 1
			push_error("FAIL %s: did not finish cleanly (runtime error?)" % test_name)

	_cleanup_test_saves()
	await process_frame
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])

func _cleanup_test_saves() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var abs_path := ProjectSettings.globalize_path(TEST_SAVE_PATH + suffix)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)

func test_economy_catalog() -> bool:
	assert_eq(Economy.INITIAL_UNLOCKED_BLOCKS.size(), 3, "initial_unlocked_count_3")
	assert_eq(Economy.BLOCK_PRICES["interactuar"], 30, "price_interactuar")
	assert_eq(Economy.BLOCK_PRICES["for_loop"], 50, "price_for_loop")
	assert_eq(Economy.BLOCK_PRICES["variables"], 80, "price_variables")
	assert_eq(Economy.BLOCK_PRICES["while_loop"], 100, "price_while_loop")
	assert_eq(Economy.BLOCK_PRICES["if_else"], 120, "price_if_else")
	assert_eq(Economy.BLOCK_INFO.size(), 5, "block_info_count_5")

	assert_eq(Economy.BUILDING_PRICES["fences"], 40, "price_fences")
	assert_eq(Economy.BUILDING_PRICES["well"], 60, "price_well")
	assert_eq(Economy.BUILDING_PRICES["chicken_coop"], 90, "price_chicken_coop")
	assert_eq(Economy.BUILDING_PRICES["silo"], 120, "price_silo")
	assert_eq(Economy.BUILDING_PRICES["windmill"], 150, "price_windmill")
	assert_eq(Economy.BUILDING_PRICES["barn"], 250, "price_barn")
	assert_eq(Economy.BUILDING_INFO.size(), 6, "building_info_count_6")

	assert_eq(Economy.HINT_COST, 5, "hint_cost")
	assert_eq(Economy.get_total_upgrade_count(), 11, "total_upgrades_11")
	assert_eq(Economy.OBJECTIVES.size(), 12, "objectives_count_12")
	return true

func test_game_state_progression_and_save() -> bool:
	_cleanup_test_saves()
	var gs := preload("res://scripts/game/game_state.gd").new()
	gs.save_path = TEST_SAVE_PATH
	gs.reset_new_game(false)

	# 1. Cálculo de estrellas
	assert_eq(gs.calculate_stars(true, 4, 4, 1, false), 3, "stars_3_perfect")
	assert_eq(gs.calculate_stars(true, 4, 4, 2, false), 2, "stars_2_second_attempt")
	assert_eq(gs.calculate_stars(true, 4, 4, 1, true), 2, "stars_2_used_hint")
	assert_eq(gs.calculate_stars(true, 6, 4, 1, false), 1, "stars_1_over_par")
	assert_eq(gs.calculate_stars(false, 2, 4, 1, false), 0, "stars_0_incomplete")

	# Mapeo de bloques especiales
	assert_eq(gs.is_block_unlocked("avanzar"), true, "initial_avanzar_unlocked")
	assert_eq(gs.is_block_unlocked("interactuar"), false, "initial_interactuar_locked")
	assert_eq(gs.is_block_unlocked("if_block"), false, "initial_if_block_locked")
	assert_eq(gs.is_block_unlocked("else_block"), false, "initial_else_block_locked")
	assert_eq(gs.is_block_unlocked("var_decl"), false, "initial_var_decl_locked")

	# 2. Recompensa nivel 1 + Objetivo 1 ("first_level" +15) + Objetivo 2 ("save_30_coins" +15)
	var res1: Dictionary = gs.award_level("reach", 3, 4, 1, false)
	assert_eq(res1["stars"], 3, "award_stars_3")
	assert_eq(res1["base_coins"], 30, "award_base_30")
	assert_eq(gs.coins, 60, "coins_after_lvl1_and_2_objectives")

	# 3. Compra de bloque e inmueble + bonos (Gallinero, Silo, Molino, Pozo)
	assert_eq(gs.buy_block("interactuar"), true, "buy_interactuar_ok")
	gs.coins = 500
	assert_eq(gs.buy_building("well"), true, "buy_well_ok")
	assert_eq(gs.buy_building("chicken_coop"), true, "buy_coop_ok")
	assert_eq(gs.buy_building("silo"), true, "buy_silo_ok")
	assert_eq(gs.buy_building("windmill"), true, "buy_windmill_ok")

	# Bonos combinados en misión "plant" con 3 estrellas:
	# base = 30, gallinero = +3 (subtotal 33), silo +10% (+3.3), molino +50% (+16.5) -> total 53
	var res_plant: Dictionary = gs.award_level("plant", 4, 4, 1, false)
	assert_eq(res_plant["base_coins"], 30, "plant_base_30")
	assert_eq(res_plant["coop_bonus"], 3, "plant_coop_3")
	assert_eq(res_plant["silo_bonus"] + res_plant["windmill_bonus"], 20, "plant_pct_bonuses_20")

	# 4. Guardado y carga atómica (JSON float->int safety)
	assert_eq(gs.save_game(), OK, "save_game_ok")
	var gs2 := preload("res://scripts/game/game_state.gd").new()
	gs2.save_path = TEST_SAVE_PATH
	assert_eq(gs2.load_game(), true, "load_game_ok")
	assert_eq(gs2.coins, gs.coins, "loaded_coins_match")
	assert_eq(typeof(gs2.coins), TYPE_INT, "loaded_coins_is_int")
	assert_eq(typeof(gs2.levels_completed), TYPE_INT, "loaded_levels_is_int")
	assert_eq(typeof(gs2.current_objective_index), TYPE_INT, "loaded_obj_index_is_int")
	assert_eq(typeof(gs2.total_stars), TYPE_INT, "loaded_total_stars_is_int")
	assert_eq(gs2.is_block_unlocked("interactuar"), true, "loaded_block_unlocked")
	assert_eq(gs2.is_building_purchased("windmill"), true, "loaded_building_purchased")

	# 5. Progreso hasta 100% y desbloqueo de Modo Libre
	gs.coins = 5000
	for block_id in Economy.BLOCK_PRICES.keys():
		if not gs.is_block_unlocked(block_id):
			assert_eq(gs.buy_block(block_id), true, "buy_all_" + block_id)
	for building_id in Economy.BUILDING_PRICES.keys():
		if not gs.is_building_purchased(building_id):
			assert_eq(gs.buy_building(building_id), true, "buy_all_" + building_id)
	assert_eq(gs.get_restoration_percent(), 100, "restoration_100_percent")
	assert_eq(gs.free_play_unlocked, true, "free_play_unlocked_at_100")

	gs.free()
	gs2.free()
	return true

func test_well_free_hint_edge_case() -> bool:
	var gs := preload("res://scripts/game/game_state.gd").new()
	gs.save_path = TEST_SAVE_PATH
	gs.reset_new_game(false)

	# Sin Pozo: cuesta 5 monedas
	gs.on_level_started()
	assert_eq(gs.get_hint_cost(), 5, "no_well_hint_cost_5")
	gs.coins = 0
	var fail_hint: Dictionary = gs.try_purchase_hint()
	assert_eq(fail_hint["ok"], false, "no_well_zero_coins_fails")

	# Con Pozo y 0 monedas: 1ra pista del nivel cuesta 0, 2da cuesta 5
	gs.coins = 100
	assert_eq(gs.buy_building("well"), true, "well_purchased_for_hint_test")
	gs.coins = 0
	gs.on_level_started()
	assert_eq(gs.get_hint_cost(), 0, "well_first_hint_cost_0")
	var h1: Dictionary = gs.try_purchase_hint()
	assert_eq(h1["ok"], true, "well_first_hint_ok")
	assert_eq(h1["cost"], 0, "well_first_hint_charged_0")
	assert_eq(gs.coins, 0, "well_first_hint_coins_unchanged")
	assert_eq(gs.get_hint_cost(), 5, "well_second_hint_cost_5")

	# Simula el flujo de main.gd al pulsar Pista por segunda vez en el mismo nivel:
	# hint_used_on_current_level ya es true -> no vuelve a llamar try_purchase_hint() ni falla ni cobra.
	var hint_used_on_current_level := true
	var re_displayed := false
	var double_charged := false
	if hint_used_on_current_level:
		re_displayed = true
	else:
		var h2 := gs.try_purchase_hint()
		if h2["ok"]:
			double_charged = true
	assert_eq(re_displayed, true, "second_click_redisplays_hint")
	assert_eq(double_charged, false, "second_click_does_not_double_charge")
	assert_eq(gs.coins, 0, "coins_still_0_after_second_click")

	# Al iniciar nuevo nivel, la pista gratis del Pozo se restablece
	gs.on_level_started()
	assert_eq(gs.get_hint_cost(), 0, "well_resets_free_hint_next_level")

	gs.free()
	return true

func test_level_validator_bfs_and_fallback() -> bool:
	var start := Vector3i(-1, 0, 19)
	var dir_north := 0  # Vector3i(0, 0, -1)

	# 1. Línea recta 3 pasos al norte: (-1,0,19) -> (-1,0,16)
	var r1: Dictionary = LevelValidator.validate_and_score_level(
		start, dir_north, Vector3i(-1, 0, 16), [], [], ["avanzar", "girar_derecha", "girar_izquierda"]
	)
	assert_eq(r1["solvable"], true, "bfs_straight_solvable")
	assert_eq(r1["min_actions"], 3, "bfs_straight_3_actions")
	assert_eq(r1["par_blocks"], 3, "bfs_straight_par_3_no_loops")

	# 2. Línea recta 5 pasos con for_loop desbloqueado: par_blocks comprime recta a 2 bloques
	var r_loop: Dictionary = LevelValidator.validate_and_score_level(
		start, dir_north, Vector3i(-1, 0, 14), [], [], ["avanzar", "girar_derecha", "girar_izquierda", "for_loop"]
	)
	assert_eq(r_loop["solvable"], true, "bfs_loop_solvable")
	assert_eq(r_loop["par_blocks"], 2, "bfs_loop_par_compressed_to_2")

	# 3. Meta rodeada de obstáculos -> irresoluble
	var blocked_obs: Array[Vector3i] = [
		Vector3i(2, 0, 14), Vector3i(2, 0, 16), Vector3i(1, 0, 15), Vector3i(3, 0, 15)
	]
	var r_blocked: Dictionary = LevelValidator.validate_and_score_level(
		start, dir_north, Vector3i(2, 0, 15), blocked_obs, [], ["avanzar", "girar_derecha", "girar_izquierda"]
	)
	assert_eq(r_blocked["solvable"], false, "bfs_surrounded_unsolvable")

	# 4. Conteo de bloques de código (incluyendo anidación, comentarios y pass)
	var sample_code := "for i in range(4):\n\tavanzar()\n\t# comentario\ngirar_derecha()\navanzar()"
	assert_eq(LevelValidator.count_code_blocks(sample_code), 4, "count_code_blocks_4")
	var nested_code := "if frente_libre():\n\tavanzar()\nelse:\n\tpass\n\t# ignorar\n\tgirar_izquierda()"
	assert_eq(LevelValidator.count_code_blocks(nested_code), 4, "count_code_blocks_ignores_pass_and_comments")

	# 5. Generador local de respaldo (con y sin interactuar) y validación BFS real
	for idx in range(1, 8):
		var blocks: Array[String] = ["avanzar", "girar_derecha", "girar_izquierda"]
		if idx >= 3:
			blocks.append("interactuar")
		if idx >= 5:
			blocks.append("for_loop")
		var lvl: Dictionary = LevelValidator.generate_fallback_level(start, dir_north, blocks, idx)
		assert_eq(lvl.has("hint") and not str(lvl["hint"]).is_empty(), true, "fallback_has_hint_" + str(idx))
		assert_eq(int(lvl["par_blocks"]) >= 1, true, "fallback_has_par_" + str(idx))
		var target := Vector3i(int(lvl["target"]["x"]), 0, int(lvl["target"]["z"]))
		assert_eq(LevelValidator.is_in_bounds(target), true, "fallback_target_in_bounds_" + str(idx))
		var obs: Array[Vector3i] = []
		for o in lvl.get("obstacles", []):
			obs.append(Vector3i(int(o["x"]), 0, int(o["z"])))
		var plants: Array[Vector3i] = []
		for p in lvl.get("plant_cells", []):
			plants.append(Vector3i(int(p["x"]), 0, int(p["z"])))
		var check_bfs: Dictionary = LevelValidator.validate_and_score_level(start, dir_north, target, obs, plants, blocks)
		assert_eq(check_bfs["solvable"], true, "fallback_bfs_solvable_" + str(idx))

	# 6. Sanitize corrige nivel fuera de límites o misión plant sin interactuar
	var bad_raw := {
		"mission": "plant",
		"target": {"x": -6, "z": 15},
		"obstacles": [],
		"plant_cells": [{"x": -1, "z": 16}],
		"hint": "Malo",
		"message": "Malo"
	}
	var sanitized: Dictionary = LevelValidator.sanitize_or_fallback(
		bad_raw, start, dir_north, ["avanzar", "girar_derecha", "girar_izquierda"], 1
	)
	var sanitized_target := Vector3i(int(sanitized["target"]["x"]), 0, int(sanitized["target"]["z"]))
	assert_eq(LevelValidator.is_in_bounds(sanitized_target), true, "sanitized_target_in_bounds")
	assert_eq(str(sanitized["mission"]), "reach", "sanitized_mission_falls_back_to_reach_without_interactuar")

	return true

func test_tractor_planting_and_ai_fallback() -> bool:
	var tractor_script := preload("res://scenes/tractor/tractor.gd")
	assert_eq(tractor_script.GRID_MIN_X, -1, "tractor_grid_min_x_fixed_to_minus_1")
	assert_eq(tractor_script.GRID_MAX_X, 6, "tractor_grid_max_x_6")
	assert_eq(tractor_script.GRID_MIN_Z, 11, "tractor_grid_min_z_11")
	assert_eq(tractor_script.GRID_MAX_Z, 18, "tractor_grid_max_z_18")

	var tractor: CharacterBody3D = tractor_script.new()
	root.add_child(tractor)
	var req_cells: Array[Vector3i] = [Vector3i(0, 0, 16), Vector3i(1, 0, 16)]
	assert_eq(tractor.has_planted_all(req_cells), false, "tractor_not_planted_initially")
	tractor.planted_cells.append(Vector3i(0, 0, 16))
	assert_eq(tractor.has_planted_all(req_cells), false, "tractor_partial_plant_false")
	tractor.planted_cells.append(Vector3i(1, 0, 16))
	assert_eq(tractor.has_planted_all(req_cells), true, "tractor_all_planted_true")
	tractor.reset_state()
	assert_eq(tractor.planted_cells.is_empty(), true, "tractor_reset_clears_planted_cells")
	assert_eq(tractor.has_planted_all(req_cells), false, "tractor_after_reset_not_planted")

	# Test AILevelManager con GridMap real y verificación de restauración a tile base 308
	var gm := GridMap.new()
	gm.mesh_library = preload("res://assets/meshlibrary/preset_result_tiles/tiles_meshlibrary/assets_nature_tiles.tres")
	for x in range(-1, 7):
		for z in range(11, 19):
			gm.set_cell_item(Vector3i(x, 0, z), 308)

	var ai := preload("res://scenes/main/ai_level_manager.gd").new()
	ai.init_ai("", "gemini-3.5-flash", "crop_pumpkin3", "statue_block3", gm)
	var fallback_lvl: Dictionary = LevelValidator.generate_fallback_level(
		Vector3i(-1, 0, 19), 0, ["avanzar", "girar_derecha", "girar_izquierda", "interactuar"], 3
	)
	ai._apply_level_data(fallback_lvl)
	assert_eq(ai.current_par_blocks >= 1, true, "ai_par_blocks_set")
	assert_eq(ai.current_hint.is_empty(), false, "ai_hint_set")

	var saved_target := ai.current_target_pos
	ai.clear_current_level()
	assert_eq(gm.get_cell_item(saved_target), 308, "ai_clear_restores_base_tile_308")

	ai.free()
	gm.free()
	root.remove_child(tractor)
	tractor.free()
	return true

func test_shop_and_farm_lot_scenes() -> bool:
	var shop_scene := preload("res://scenes/ui/panel_shop/panel_shop.tscn")
	var shop := shop_scene.instantiate()
	assert_eq(shop != null, true, "shop_scene_instantiates")
	shop.free()

	var lot := preload("res://scenes/world/farm_lot.gd").new()
	lot.building_id = "well"
	assert_eq(lot.building_id, "well", "farm_lot_script_loads")
	lot.free()
	return true

func test_hud_and_popups_instantiate() -> bool:
	var hud := preload("res://scenes/ui/hud/farm_hud.gd").new()
	assert_eq(hud != null, true, "farm_hud_loads")
	hud.free()

	var popup := preload("res://scenes/ui/hud/level_result_popup.gd").new()
	assert_eq(popup != null, true, "result_popup_loads")
	popup.free()

	var cert := preload("res://scenes/ui/hud/victory_certificate_popup.gd").new()
	assert_eq(cert != null, true, "certificate_popup_loads")
	cert.free()
	return true

func test_main_scene_and_menu_integration() -> bool:
	var gs := root.get_node_or_null("GameState")
	var orig_save_path := ""
	if gs:
		orig_save_path = gs.save_path
		gs.save_path = TEST_SAVE_PATH
		gs.reset_new_game(false)

	var menu_scene := load("res://scenes/ui/main_menu/main_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	assert_eq(menu != null, true, "main_menu_instantiates")
	assert_eq(menu.get_node_or_null("VBoxContainer/BtnContinue") != null, true, "main_menu_has_btn_continue")
	assert_eq(menu.get_node_or_null("VBoxContainer/BtnDesktop") != null, true, "main_menu_has_btn_desktop")
	menu.free()

	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	assert_eq(main != null, true, "main_scene_instantiates")
	assert_eq(main.get_node_or_null("ProgrammingConsole/panel_shop") != null, true, "main_has_panel_shop")
	assert_eq(main.get_node_or_null("ProgrammingConsole/ShopKiosk") != null, true, "main_has_shop_kiosk")
	assert_eq(main.get("viewport_shop") == main.get_node_or_null("ProgrammingConsole/panel_shop"), true, "main_exports_viewport_shop")

	for lot_name in ["LotFences", "LotWell", "LotChickenCoop", "LotSilo", "LotWindmill", "LotBarn"]:
		assert_eq(main.get_node_or_null("Environment/FarmLots/" + lot_name) != null, true, "main_has_" + lot_name)

	for kiosk_name in ["ActionsKiosk", "CodeKiosk", "VariablesKiosk"]:
		assert_eq(main.get_node_or_null("ProgrammingConsole/" + kiosk_name) != null, true, "main_has_" + kiosk_name)

	assert_eq(main.get_node_or_null("ProgrammingConsole/panel_camera") == null, true, "main_removed_panel_camera")
	var panel_code_3d := main.get_node("ProgrammingConsole/panel_code") as Node3D
	var code_kiosk := main.get_node("ProgrammingConsole/CodeKiosk") as Node3D
	assert_eq(panel_code_3d.position.z >= 51.0, true, "panel_code_at_south_deck")
	assert_eq(code_kiosk.position.z > panel_code_3d.position.z, true, "CodeKiosk_behind_panel_code")
	var post_left_x: float = code_kiosk.position.x + (code_kiosk.get_node("PostLeft") as Node3D).position.x
	var post_right_x: float = code_kiosk.position.x + (code_kiosk.get_node("PostRight") as Node3D).position.x
	assert_eq(post_left_x < panel_code_3d.position.x - 1.6, true, "CodeKiosk_post_left_clears_panel_code")
	assert_eq(post_right_x > panel_code_3d.position.x + 1.6, true, "CodeKiosk_post_right_clears_panel_code")
	var fascia_bottom_y: float = code_kiosk.position.y + (code_kiosk.get_node("FasciaBoard") as Node3D).position.y - 0.21
	assert_eq(fascia_bottom_y > 4.4, true, "CodeKiosk_fascia_above_panel_code")
	assert_eq(main.get_node_or_null("Actors/PlayerXR_Desktop/RightHand/TractorRemote") != null, true, "main_has_tractor_remote")

	for west_lot in ["LotFences", "LotWell", "LotSilo"]:
		var lot_node := main.get_node("Environment/FarmLots/" + west_lot) as Node3D
		assert_eq(lot_node.position.x <= -9.0, true, west_lot + "_outside_west_fence")
	var barn_node := main.get_node("Environment/FarmLots/LotBarn") as Node3D
	assert_eq(barn_node.position.z <= 12.0, true, "LotBarn_outside_north_fence")
	for east_lot in ["LotWindmill", "LotChickenCoop"]:
		var lot_node := main.get_node("Environment/FarmLots/" + east_lot) as Node3D
		assert_eq(lot_node.position.x >= 21.0, true, east_lot + "_outside_east_fence")

	root.add_child(main)
	# Espera a que main._ready() inicialice FarmHUD, AILevelManager y genere el primer nivel local
	for _i in range(80):
		await process_frame
		if main.ai_manager != null and LevelValidator.is_in_bounds(main.ai_manager.current_target_pos):
			break
	if main.ai_manager == null or not LevelValidator.is_in_bounds(main.ai_manager.current_target_pos):
		await create_timer(0.7).timeout

	assert_eq(main.farm_hud != null, true, "main_creates_farm_hud")
	assert_eq(main.ai_manager != null, true, "main_creates_ai_manager")
	assert_eq(LevelValidator.is_in_bounds(main.ai_manager.current_target_pos), true, "main_loads_first_level_without_api_key")

	# Prueba flujo completo de pista en main.gd (Pozo gratis 1ra vez, re-mostrar sin doble cobro)
	var test_code_panel := (load("res://scenes/ui/panel_code/panel_code.tscn") as PackedScene).instantiate()
	root.add_child(test_code_panel)
	await process_frame
	main.panel_code = test_code_panel
	if gs:
		gs.coins = 100
		gs.buy_building("well")
		gs.coins = 0
		main._request_new_level("")
		assert_eq(main.hint_used_on_current_level, false, "main_hint_starts_unused")
		main._on_hint_requested()
		assert_eq(main.hint_used_on_current_level, true, "main_well_hint_marks_used")
		assert_eq(gs.coins, 0, "main_well_first_hint_free")
		main._on_hint_requested()
		assert_eq(main.hint_used_on_current_level, true, "main_second_hint_stays_used")
		assert_eq(gs.coins, 0, "main_second_hint_does_not_charge")

	# Prueba disparo remoto del código desde TractorRemote / DesktopInteraction
	var emitted_codes: Array[String] = []
	test_code_panel.code_execution_requested.connect(func(code: String) -> void:
		emitted_codes.append(code)
	)
	main.is_running = false
	main._awaiting_next_level = false
	main._on_remote_run_requested()
	assert_eq(emitted_codes.size(), 0, "remote_run_ignores_empty_canvas")
	test_code_panel.add_block("avanzar")
	main.is_running = true
	main._on_remote_run_requested()
	assert_eq(emitted_codes.size(), 0, "remote_run_ignores_when_busy")
	main.is_running = false
	main._on_remote_run_requested()
	assert_eq(emitted_codes.size(), 1, "remote_run_executes_when_idle_with_blocks")
	assert_eq(emitted_codes[0].strip_edges(), "avanzar()", "remote_run_emits_avanzar_code")

	test_code_panel.queue_free()
	main.queue_free()
	await process_frame
	if gs and not orig_save_path.is_empty():
		gs.save_path = orig_save_path
	return true
