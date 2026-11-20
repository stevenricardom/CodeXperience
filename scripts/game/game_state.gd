extends Node
## Autoload GameState: progresión, monedas, tienda, pistas, objetivos y guardado atómico.

signal coins_changed(new_coins: int, delta: int)
signal blocks_updated()
signal building_purchased(building_id: String)
signal restoration_changed(percent: int)
signal objective_updated(objective: Dictionary)
signal objective_completed(objective: Dictionary)
signal victory_100_reached()

const SAVE_VERSION: int = 1

var save_path: String = "user://save.json"

var coins: int = 0
var unlocked_blocks: Array[String] = []
var purchased_buildings: Array[String] = []
var current_objective_index: int = 0
var levels_completed: int = 0
var plant_levels_completed: int = 0
var total_stars: int = 0
var max_stars_in_single_level: int = 0
var free_play_unlocked: bool = false
var free_hint_used_this_level: bool = false


func _init() -> void:
	reset_new_game(false)


func _ready() -> void:
	if has_save_file():
		load_game()
	else:
		reset_new_game(false)


func reset_new_game(persist: bool = true) -> void:
	coins = 0
	unlocked_blocks.clear()
	for block_id in Economy.INITIAL_UNLOCKED_BLOCKS:
		unlocked_blocks.append(block_id)
	purchased_buildings.clear()
	current_objective_index = 0
	levels_completed = 0
	plant_levels_completed = 0
	total_stars = 0
	max_stars_in_single_level = 0
	free_play_unlocked = false
	free_hint_used_this_level = false

	coins_changed.emit(coins, 0)
	blocks_updated.emit()
	restoration_changed.emit(get_restoration_percent())
	objective_updated.emit(get_current_objective())

	if persist:
		save_game()


func has_save_file() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> Error:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"coins": coins,
		"unlocked_blocks": unlocked_blocks,
		"purchased_buildings": purchased_buildings,
		"current_objective_index": current_objective_index,
		"levels_completed": levels_completed,
		"plant_levels_completed": plant_levels_completed,
		"total_stars": total_stars,
		"max_stars_in_single_level": max_stars_in_single_level,
		"free_play_unlocked": free_play_unlocked,
	}

	var tmp_path: String = save_path + ".tmp"
	var bak_path: String = save_path + ".bak"

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()

	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var bak_err: Error = DirAccess.rename_absolute(save_path, bak_path)
		if bak_err != OK:
			return bak_err

	var rename_err: Error = DirAccess.rename_absolute(tmp_path, save_path)
	if rename_err != OK:
		if FileAccess.file_exists(bak_path) and not FileAccess.file_exists(save_path):
			DirAccess.rename_absolute(bak_path, save_path)
		return rename_err

	return OK


func load_game() -> bool:
	var data: Variant = _read_json_dict(save_path)
	if data == null and FileAccess.file_exists(save_path + ".bak"):
		data = _read_json_dict(save_path + ".bak")
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var dict: Dictionary = data
	var _version: int = int(dict.get("version", SAVE_VERSION))
	coins = maxi(0, int(dict.get("coins", 0)))
	current_objective_index = clampi(
		int(dict.get("current_objective_index", 0)),
		0,
		Economy.OBJECTIVES.size()
	)
	levels_completed = maxi(0, int(dict.get("levels_completed", 0)))
	plant_levels_completed = maxi(0, int(dict.get("plant_levels_completed", 0)))
	total_stars = maxi(0, int(dict.get("total_stars", 0)))
	max_stars_in_single_level = clampi(int(dict.get("max_stars_in_single_level", 0)), 0, 3)
	free_play_unlocked = bool(dict.get("free_play_unlocked", false))
	free_hint_used_this_level = false

	unlocked_blocks.clear()
	for base_block in Economy.INITIAL_UNLOCKED_BLOCKS:
		unlocked_blocks.append(base_block)
	var raw_blocks: Variant = dict.get("unlocked_blocks", [])
	if typeof(raw_blocks) == TYPE_ARRAY:
		for item in raw_blocks:
			var block_id: String = str(item)
			if not block_id in unlocked_blocks:
				unlocked_blocks.append(block_id)

	purchased_buildings.clear()
	var raw_buildings: Variant = dict.get("purchased_buildings", [])
	if typeof(raw_buildings) == TYPE_ARRAY:
		for item in raw_buildings:
			var bld_id: String = str(item)
			if Economy.BUILDING_PRICES.has(bld_id) and not (bld_id in purchased_buildings):
				purchased_buildings.append(bld_id)

	if get_restoration_percent() >= 100:
		free_play_unlocked = true

	coins_changed.emit(coins, 0)
	blocks_updated.emit()
	restoration_changed.emit(get_restoration_percent())
	objective_updated.emit(get_current_objective())
	return true


func _read_json_dict(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


func _normalize_block_key(block_key: String) -> String:
	match block_key:
		"if_block", "elif_block", "else_block":
			return "if_else"
		"var_decl", "var_ref", "var_inc":
			return "variables"
		_:
			return block_key


func is_block_unlocked(block_key: String) -> bool:
	return _normalize_block_key(block_key) in unlocked_blocks


func is_building_purchased(building_id: String) -> bool:
	return building_id in purchased_buildings


func buy_block(block_id: String) -> bool:
	if not Economy.BLOCK_PRICES.has(block_id):
		return false
	if is_block_unlocked(block_id):
		return false

	var price: int = int(Economy.BLOCK_PRICES[block_id])
	if coins < price:
		return false

	coins -= price
	unlocked_blocks.append(block_id)

	coins_changed.emit(coins, -price)
	blocks_updated.emit()
	restoration_changed.emit(get_restoration_percent())

	_check_objectives()
	_check_100_victory()
	save_game()
	return true


func buy_building(building_id: String) -> bool:
	if not Economy.BUILDING_PRICES.has(building_id):
		return false
	if is_building_purchased(building_id):
		return false

	var price: int = int(Economy.BUILDING_PRICES[building_id])
	if coins < price:
		return false

	coins -= price
	purchased_buildings.append(building_id)

	coins_changed.emit(coins, -price)
	building_purchased.emit(building_id)
	restoration_changed.emit(get_restoration_percent())

	_check_objectives()
	_check_100_victory()
	save_game()
	return true


func get_restoration_percent() -> int:
	var total: int = Economy.get_total_upgrade_count()
	if total <= 0:
		return 100

	var owned: int = 0
	for block_id in Economy.BLOCK_PRICES.keys():
		if block_id in unlocked_blocks:
			owned += 1
	for building_id in Economy.BUILDING_PRICES.keys():
		if building_id in purchased_buildings:
			owned += 1

	return clampi(roundi(float(owned) * 100.0 / float(total)), 0, 100)


func on_level_started() -> void:
	free_hint_used_this_level = false


func get_hint_cost() -> int:
	if is_building_purchased("well") and not free_hint_used_this_level:
		return 0
	return Economy.HINT_COST


func try_purchase_hint() -> Dictionary:
	var cost: int = get_hint_cost()
	if cost == 0:
		free_hint_used_this_level = true
		return { "ok": true, "cost": 0, "reason": "free_well_hint" }

	if coins < cost:
		return { "ok": false, "cost": cost, "reason": "insufficient_coins" }

	coins -= cost
	coins_changed.emit(coins, -cost)
	save_game()
	return { "ok": true, "cost": cost, "reason": "purchased" }


func calculate_stars(completed: bool, blocks_used: int, par_blocks: int, attempts: int, hint_used: bool) -> int:
	if not completed:
		return 0

	var stars: int = 1
	if blocks_used <= maxi(1, par_blocks):
		stars += 1
		if attempts == 1 and not hint_used:
			stars += 1
	return stars


func award_level(mission: String, blocks_used: int, par_blocks: int, attempts: int, hint_used: bool) -> Dictionary:
	var stars: int = calculate_stars(true, blocks_used, par_blocks, attempts, hint_used)
	var base_coins: int = 10 * stars
	var coop_bonus: int = stars if is_building_purchased("chicken_coop") else 0
	var subtotal: int = base_coins + coop_bonus

	var silo_pct: int = 10 if is_building_purchased("silo") else 0
	var windmill_pct: int = 50 if (is_building_purchased("windmill") and mission == "plant") else 0
	var total_pct: int = silo_pct + windmill_pct

	# Entero exacto con redondeo hacia arriba (evita deriva binaria de 1.1/1.6 en float).
	var pct_bonus: int = floori(float(subtotal * total_pct + 99) / 100.0) if total_pct > 0 else 0
	var silo_bonus: int = 0
	var windmill_bonus: int = 0
	if silo_pct > 0 and windmill_pct > 0:
		silo_bonus = roundi(float(subtotal * silo_pct) / 100.0)
		windmill_bonus = pct_bonus - silo_bonus
	elif silo_pct > 0:
		silo_bonus = pct_bonus
	elif windmill_pct > 0:
		windmill_bonus = pct_bonus

	var level_coins: int = subtotal + pct_bonus

	levels_completed += 1
	if mission == "plant":
		plant_levels_completed += 1
	total_stars += stars
	max_stars_in_single_level = maxi(max_stars_in_single_level, stars)

	coins += level_coins
	coins_changed.emit(coins, level_coins)

	var completed_objectives: Array = _check_objectives()
	var objective_bonus: int = 0
	for obj in completed_objectives:
		objective_bonus += int(obj.get("reward", 0))

	save_game()

	return {
		"stars": stars,
		"base_coins": base_coins,
		"coop_bonus": coop_bonus,
		"silo_bonus": silo_bonus,
		"windmill_bonus": windmill_bonus,
		"objective_bonus": objective_bonus,
		"total_coins_earned": level_coins + objective_bonus,
		"completed_objectives": completed_objectives,
	}


func get_current_objective() -> Dictionary:
	if current_objective_index < 0 or current_objective_index >= Economy.OBJECTIVES.size():
		return {}
	return Economy.OBJECTIVES[current_objective_index]


func _check_objectives() -> Array:
	var newly_completed: Array = []
	while current_objective_index < Economy.OBJECTIVES.size():
		var obj: Dictionary = Economy.OBJECTIVES[current_objective_index]
		if not _is_objective_met(obj):
			break

		current_objective_index += 1
		var reward: int = int(obj.get("reward", 0))
		if reward > 0:
			coins += reward
			coins_changed.emit(coins, reward)

		newly_completed.append(obj)
		objective_completed.emit(obj)
		objective_updated.emit(get_current_objective())

	return newly_completed


func _is_objective_met(obj: Dictionary) -> bool:
	var obj_type: String = str(obj.get("type", ""))
	var target: Variant = obj.get("target")

	match obj_type:
		"levels_completed":
			return levels_completed >= int(target)
		"coins_reached":
			return coins >= int(target)
		"block_unlocked":
			return is_block_unlocked(str(target))
		"plant_levels_completed":
			return plant_levels_completed >= int(target)
		"building_purchased":
			return is_building_purchased(str(target))
		"max_stars":
			return max_stars_in_single_level >= int(target)
		"blocks_all":
			if typeof(target) != TYPE_ARRAY:
				return false
			for block_id in target:
				if not is_block_unlocked(str(block_id)):
					return false
			return true
		"buildings_all":
			if typeof(target) != TYPE_ARRAY:
				return false
			for building_id in target:
				if not is_building_purchased(str(building_id)):
					return false
			return true
		"restoration_percent":
			return get_restoration_percent() >= int(target)
		_:
			return false


func _check_100_victory() -> void:
	if not free_play_unlocked and get_restoration_percent() >= 100:
		free_play_unlocked = true
		victory_100_reached.emit()
