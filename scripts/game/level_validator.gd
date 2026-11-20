class_name LevelValidator
extends RefCounted
## Validador BFS, cálculo de par de bloques y generador local de niveles.

const MIN_X: int = -1
const MAX_X: int = 6
const MIN_Z: int = 11
const MAX_Z: int = 18

# 0: Norte (-Z), 1: Este (+X), 2: Sur (+Z), 3: Oeste (-X)
const DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 0, -1),
	Vector3i(1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(-1, 0, 0),
]


static func is_in_bounds(cell: Vector3i) -> bool:
	return cell.x >= MIN_X and cell.x <= MAX_X and cell.z >= MIN_Z and cell.z <= MAX_Z


static func count_code_blocks(code_text: String) -> int:
	var count: int = 0
	for raw_line in code_text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#") or line == "pass":
			continue
		count += 1
	return count


static func validate_and_score_level(
	start_pos: Vector3i,
	start_dir: int,
	target_pos: Vector3i,
	obstacles: Array,
	plant_cells: Array,
	unlocked_blocks: Array
) -> Dictionary:
	var norm_start := Vector3i(start_pos.x, 0, start_pos.z)
	var norm_target := Vector3i(target_pos.x, 0, target_pos.z)
	var norm_dir: int = ((start_dir % 4) + 4) % 4

	var empty_actions: Array[String] = []
	var unsolvable := {
		"solvable": false,
		"min_actions": -1,
		"par_blocks": 1,
		"optimal_actions": empty_actions,
	}

	if not is_in_bounds(norm_target):
		return unsolvable

	var obstacle_set: Dictionary = {}
	for raw_obs in obstacles:
		var obs_cell: Vector3i = _to_cell(raw_obs)
		obstacle_set[obs_cell] = true

	if obstacle_set.has(norm_target):
		return unsolvable

	var unique_plants: Array[Vector3i] = []
	var plant_index_map: Dictionary = {}
	for raw_plant in plant_cells:
		var p_cell: Vector3i = _to_cell(raw_plant)
		if not is_in_bounds(p_cell) or obstacle_set.has(p_cell):
			return unsolvable
		if not plant_index_map.has(p_cell):
			plant_index_map[p_cell] = unique_plants.size()
			unique_plants.append(p_cell)

	if unique_plants.size() > 20:
		return unsolvable

	var full_mask: int = (1 << unique_plants.size()) - 1

	var q_pos: Array[Vector3i] = [norm_start]
	var q_dir: Array[int] = [norm_dir]
	var q_mask: Array[int] = [0]
	var q_parent: Array[int] = [-1]
	var q_action: Array[String] = [""]

	var visited: Dictionary = {}
	visited[Vector4i(norm_start.x, norm_start.z, norm_dir, 0)] = true

	var head: int = 0
	while head < q_pos.size():
		var pos: Vector3i = q_pos[head]
		var dir: int = q_dir[head]
		var mask: int = q_mask[head]

		if pos == norm_target and mask == full_mask:
			var optimal_actions: Array[String] = _reconstruct_actions(q_parent, q_action, head)
			var par_blocks: int = _compute_par_blocks(optimal_actions, unlocked_blocks)
			return {
				"solvable": true,
				"min_actions": optimal_actions.size(),
				"par_blocks": par_blocks,
				"optimal_actions": optimal_actions,
			}

		# 1. Avanzar
		var next_pos: Vector3i = pos + DIRECTIONS[dir]
		if is_in_bounds(next_pos) and not obstacle_set.has(next_pos):
			var next_key := Vector4i(next_pos.x, next_pos.z, dir, mask)
			if not visited.has(next_key):
				visited[next_key] = true
				q_pos.append(next_pos)
				q_dir.append(dir)
				q_mask.append(mask)
				q_parent.append(head)
				q_action.append("avanzar")

		# 2. Girar derecha
		var right_dir: int = (dir + 1) % 4
		var right_key := Vector4i(pos.x, pos.z, right_dir, mask)
		if not visited.has(right_key):
			visited[right_key] = true
			q_pos.append(pos)
			q_dir.append(right_dir)
			q_mask.append(mask)
			q_parent.append(head)
			q_action.append("girar_derecha")

		# 3. Girar izquierda
		var left_dir: int = (dir + 3) % 4
		var left_key := Vector4i(pos.x, pos.z, left_dir, mask)
		if not visited.has(left_key):
			visited[left_key] = true
			q_pos.append(pos)
			q_dir.append(left_dir)
			q_mask.append(mask)
			q_parent.append(head)
			q_action.append("girar_izquierda")

		# 4. Interactuar (si hay semilla pendiente en la casilla actual)
		if plant_index_map.has(pos):
			var bit: int = 1 << int(plant_index_map[pos])
			if (mask & bit) == 0:
				var next_mask: int = mask | bit
				var plant_key := Vector4i(pos.x, pos.z, dir, next_mask)
				if not visited.has(plant_key):
					visited[plant_key] = true
					q_pos.append(pos)
					q_dir.append(dir)
					q_mask.append(next_mask)
					q_parent.append(head)
					q_action.append("interactuar")

		head += 1

	return unsolvable


static func sanitize_or_fallback(
	raw_data: Dictionary,
	start_pos: Vector3i,
	start_dir: int,
	unlocked_blocks: Array,
	level_index: int
) -> Dictionary:
	if raw_data.is_empty():
		return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)

	var mission: String = str(raw_data.get("mission", "reach")).strip_edges().to_lower()
	if mission != "reach" and mission != "plant":
		return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)

	var has_interactuar: bool = "interactuar" in unlocked_blocks
	if mission == "plant" and not has_interactuar:
		return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)

	var raw_target: Variant = raw_data.get("target")
	if typeof(raw_target) != TYPE_DICTIONARY:
		return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)
	var target_dict: Dictionary = raw_target
	if not target_dict.has("x") or not target_dict.has("z"):
		return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)

	var target_pos := Vector3i(int(target_dict["x"]), 0, int(target_dict["z"]))
	var norm_start := Vector3i(start_pos.x, 0, start_pos.z)
	if not is_in_bounds(target_pos) or target_pos == norm_start:
		return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)

	var obs_vecs: Array[Vector3i] = []
	var obs_dicts: Array = []
	var obs_seen: Dictionary = {}
	var raw_obstacles: Variant = raw_data.get("obstacles", [])
	if typeof(raw_obstacles) != TYPE_ARRAY:
		return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)

	for item in raw_obstacles:
		if typeof(item) != TYPE_DICTIONARY:
			return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)
		var od: Dictionary = item
		if not od.has("x") or not od.has("z"):
			return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)
		var obs_pos := Vector3i(int(od["x"]), 0, int(od["z"]))
		if not is_in_bounds(obs_pos) or obs_pos == norm_start or obs_pos == target_pos:
			return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)
		if not obs_seen.has(obs_pos):
			obs_seen[obs_pos] = true
			obs_vecs.append(obs_pos)
			obs_dicts.append({"x": obs_pos.x, "z": obs_pos.z})

	var plant_vecs: Array[Vector3i] = []
	var plant_dicts: Array = []
	var plant_seen: Dictionary = {}
	if mission == "plant":
		var raw_plants: Variant = raw_data.get("plant_cells", [])
		if typeof(raw_plants) != TYPE_ARRAY or (raw_plants as Array).is_empty():
			return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)
		for item in raw_plants:
			if typeof(item) != TYPE_DICTIONARY:
				return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)
			var pd: Dictionary = item
			if not pd.has("x") or not pd.has("z"):
				return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)
			var p_pos := Vector3i(int(pd["x"]), 0, int(pd["z"]))
			if not is_in_bounds(p_pos) or p_pos == norm_start or p_pos == target_pos or obs_seen.has(p_pos):
				return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)
			if not plant_seen.has(p_pos):
				plant_seen[p_pos] = true
				plant_vecs.append(p_pos)
				plant_dicts.append({"x": p_pos.x, "z": p_pos.z})

	var bfs: Dictionary = validate_and_score_level(
		norm_start, start_dir, target_pos, obs_vecs, plant_vecs, unlocked_blocks
	)
	if not bool(bfs.get("solvable", false)):
		return generate_fallback_level(start_pos, start_dir, unlocked_blocks, level_index)

	var has_loops: bool = ("for_loop" in unlocked_blocks) or ("while_loop" in unlocked_blocks)
	var hint_text: String = str(raw_data.get("hint", "")).strip_edges()
	if hint_text.is_empty():
		hint_text = _build_auto_hint(mission, bfs["optimal_actions"], plant_vecs, target_pos, has_loops)

	var message_text: String = str(raw_data.get("message", "")).strip_edges()
	if message_text.is_empty():
		message_text = "¡Nuevo desafío listo en el campo!"

	return {
		"mission": mission,
		"target": {"x": target_pos.x, "z": target_pos.z},
		"obstacles": obs_dicts,
		"plant_cells": plant_dicts,
		"par_blocks": int(bfs["par_blocks"]),
		"hint": hint_text,
		"message": message_text,
	}


static func generate_fallback_level(
	start_pos: Vector3i,
	start_dir: int,
	unlocked_blocks: Array,
	level_index: int
) -> Dictionary:
	var norm_start := Vector3i(start_pos.x, 0, start_pos.z)
	var has_interactuar: bool = "interactuar" in unlocked_blocks
	var has_loops: bool = ("for_loop" in unlocked_blocks) or ("while_loop" in unlocked_blocks)

	var candidates: Array[Dictionary] = _build_curated_candidates(level_index, has_interactuar, has_loops)
	for candidate in candidates:
		var built: Dictionary = _try_build_candidate(candidate, norm_start, start_dir, unlocked_blocks, has_loops)
		if not built.is_empty():
			return built

	# Generación procedural determinista para niveles altos o posiciones iniciales personalizadas.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_index * 7919 + norm_start.x * 31 + norm_start.z * 97 + (1 if has_interactuar else 0))

	var norm_dir: int = ((start_dir % 4) + 4) % 4
	var entry_cell: Vector3i = norm_start + DIRECTIONS[norm_dir]

	for _attempt in range(28):
		var mission: String = "plant" if (has_interactuar and rng.randi_range(0, 1) == 1) else "reach"
		var target_pos := Vector3i(rng.randi_range(MIN_X, MAX_X), 0, rng.randi_range(MIN_Z, MAX_Z))
		if target_pos == norm_start:
			continue

		var obs_vecs: Array[Vector3i] = []
		var obs_seen: Dictionary = {}
		var obs_count: int = clampi(1 + floori(float(level_index) / 3.0), 1, 5)
		for _i in range(obs_count * 2):
			if obs_vecs.size() >= obs_count:
				break
			var o_cell := Vector3i(rng.randi_range(MIN_X, MAX_X), 0, rng.randi_range(MIN_Z, MAX_Z))
			if o_cell == norm_start or o_cell == entry_cell or o_cell == target_pos or obs_seen.has(o_cell):
				continue
			obs_seen[o_cell] = true
			obs_vecs.append(o_cell)

		var plant_vecs: Array[Vector3i] = []
		var plant_seen: Dictionary = {}
		if mission == "plant":
			var plant_count: int = clampi(1 + (level_index % 3), 1, 3)
			for _j in range(plant_count * 3):
				if plant_vecs.size() >= plant_count:
					break
				var p_cell := Vector3i(rng.randi_range(MIN_X, MAX_X), 0, rng.randi_range(MIN_Z, MAX_Z))
				if p_cell == norm_start or p_cell == target_pos or obs_seen.has(p_cell) or plant_seen.has(p_cell):
					continue
				plant_seen[p_cell] = true
				plant_vecs.append(p_cell)
			if plant_vecs.is_empty():
				mission = "reach"

		var bfs: Dictionary = validate_and_score_level(
			norm_start, start_dir, target_pos, obs_vecs, plant_vecs, unlocked_blocks
		)
		if bool(bfs.get("solvable", false)) and int(bfs.get("min_actions", 0)) >= 3:
			return _format_level_dict(
				mission,
				target_pos,
				obs_vecs,
				plant_vecs,
				int(bfs["par_blocks"]),
				_build_auto_hint(mission, bfs["optimal_actions"], plant_vecs, target_pos, has_loops),
				"¡Nivel %d generado! Traza tu ruta óptima." % maxi(1, level_index)
			)

	# Respaldo universal sin obstáculos garantizado en el grid.
	var safe_target := Vector3i(clampi(norm_start.x, MIN_X, MAX_X), 0, clampi(norm_start.z - 3, MIN_Z, MAX_Z))
	if safe_target == norm_start:
		safe_target = Vector3i(2, 0, 15)
	var safe_bfs: Dictionary = validate_and_score_level(
		norm_start, start_dir, safe_target, [], [], unlocked_blocks
	)
	return _format_level_dict(
		"reach",
		safe_target,
		[],
		[],
		maxi(1, int(safe_bfs.get("par_blocks", 3))),
		_build_auto_hint("reach", safe_bfs.get("optimal_actions", []), [], safe_target, has_loops),
		"¡Ruta despejada! Lleva el tractor hasta la meta."
	)


static func _build_curated_candidates(level_index: int, has_interactuar: bool, has_loops: bool) -> Array[Dictionary]:
	if level_index <= 1:
		return [{
			"mission": "reach",
			"target": Vector3i(-1, 0, 16),
			"obstacles": [],
			"plant_cells": [],
			"hint": "Usa 3 bloques Avanzar() seguidos para ir directo al Norte hasta la meta.",
			"message": "¡Primer día en la granja! Conduce el tractor hasta el cultivo.",
		}]

	if level_index == 2:
		return [{
			"mission": "reach",
			"target": Vector3i(2, 0, 16),
			"obstacles": [Vector3i(0, 0, 17)],
			"plant_cells": [],
			"hint": "Avanza 3 casillas al Norte, gira a la derecha y avanza 3 casillas más."
				+ (" Con Bucle FOR puedes comprimir cada tramo." if has_loops else ""),
			"message": "¡Hora de girar! Esquiva la roca y alcanza el objetivo.",
		}]

	var pool: Array[Dictionary] = []
	if has_interactuar:
		pool.append({
			"mission": "plant",
			"target": Vector3i(-1, 0, 14),
			"obstacles": [Vector3i(0, 0, 16)],
			"plant_cells": [Vector3i(-1, 0, 17), Vector3i(-1, 0, 16)],
			"hint": "Avanza por la columna oeste, usa Interactuar() en cada casilla de tierra y sigue hasta la meta.",
			"message": "¡Misión de siembra! Planta las 2 parcelas y llega a la meta.",
		})
		pool.append({
			"mission": "reach",
			"target": Vector3i(3, 0, 14),
			"obstacles": [Vector3i(-1, 0, 15), Vector3i(0, 0, 16), Vector3i(2, 0, 15)],
			"plant_cells": [],
			"hint": "Avanza al Norte hasta Z=16 o rodea por Z=17 hacia el Este para evitar las rocas.",
			"message": "¡Campo rocoso! Planifica el desvío más corto.",
		})
		pool.append({
			"mission": "plant",
			"target": Vector3i(4, 0, 15),
			"obstacles": [Vector3i(0, 0, 17), Vector3i(2, 0, 16)],
			"plant_cells": [Vector3i(0, 0, 15), Vector3i(1, 0, 15), Vector3i(2, 0, 15)],
			"hint": "Sube hasta Z=15, gira a la derecha y repite Avanzar() + Interactuar()"
				+ (" dentro de un Bucle FOR." if has_loops else " 3 veces."),
			"message": "¡Surco en línea! Siembra las tres parcelas consecutivas.",
		})
		pool.append({
			"mission": "reach",
			"target": Vector3i(5, 0, 12),
			"obstacles": [Vector3i(0, 0, 18), Vector3i(0, 0, 17), Vector3i(2, 0, 15), Vector3i(4, 0, 13)],
			"plant_cells": [],
			"hint": "Sube por el borde izquierdo, cruza por Z=14 o Z=16 y sube al Noreste.",
			"message": "¡Ruta larga! Aprovecha tramos rectos para ahorrar bloques.",
		})
		pool.append({
			"mission": "plant",
			"target": Vector3i(1, 0, 12),
			"obstacles": [Vector3i(1, 0, 15), Vector3i(2, 0, 14)],
			"plant_cells": [Vector3i(-1, 0, 16), Vector3i(-1, 0, 13), Vector3i(1, 0, 13)],
			"hint": "Siembra primero la columna izquierda y luego gira al Este para la última parcela antes de la meta.",
			"message": "¡Cosecha mixta! Completa todas las siembras antes de terminar.",
		})
	else:
		pool.append({
			"mission": "reach",
			"target": Vector3i(-1, 0, 13),
			"obstacles": [Vector3i(0, 0, 16), Vector3i(1, 0, 15)],
			"plant_cells": [],
			"hint": "Avanza 6 veces directo al Norte" + (" usando un Bucle FOR." if has_loops else "."),
			"message": "¡Recta larga! Llega al extremo norte del campo.",
		})
		pool.append({
			"mission": "reach",
			"target": Vector3i(4, 0, 14),
			"obstacles": [Vector3i(-1, 0, 15), Vector3i(1, 0, 16), Vector3i(2, 0, 15)],
			"plant_cells": [],
			"hint": "Sube a Z=17 o Z=16, rodea las rocas hacia el Este y termina en X=4, Z=14.",
			"message": "¡Esquiva las piedras! Encuentra el camino más eficiente.",
		})
		pool.append({
			"mission": "reach",
			"target": Vector3i(5, 0, 12),
			"obstacles": [Vector3i(0, 0, 18), Vector3i(2, 0, 15), Vector3i(4, 0, 14)],
			"plant_cells": [],
			"hint": "Sube primero hacia el Norte antes de girar al Este hacia la esquina superior derecha.",
			"message": "¡Expedición al otro lado del campo!",
		})

	if level_index <= 7 and not pool.is_empty():
		var idx: int = (level_index - 3) % pool.size()
		var reordered: Array[Dictionary] = [pool[idx]]
		for i in range(pool.size()):
			if i != idx:
				reordered.append(pool[i])
		return reordered

	var empty_candidates: Array[Dictionary] = []
	return empty_candidates


static func _try_build_candidate(
	candidate: Dictionary,
	start_pos: Vector3i,
	start_dir: int,
	unlocked_blocks: Array,
	has_loops: bool
) -> Dictionary:
	var target_pos: Vector3i = candidate["target"]
	var obs_vecs: Array[Vector3i] = []
	for o in candidate["obstacles"]:
		obs_vecs.append(o)
	var plant_vecs: Array[Vector3i] = []
	for p in candidate["plant_cells"]:
		plant_vecs.append(p)

	if target_pos == start_pos:
		return {}
	for o in obs_vecs:
		if o == start_pos:
			return {}

	var bfs: Dictionary = validate_and_score_level(
		start_pos, start_dir, target_pos, obs_vecs, plant_vecs, unlocked_blocks
	)
	if not bool(bfs.get("solvable", false)):
		return {}

	var mission: String = str(candidate["mission"])
	var hint_text: String = str(candidate.get("hint", "")).strip_edges()
	if hint_text.is_empty():
		hint_text = _build_auto_hint(mission, bfs["optimal_actions"], plant_vecs, target_pos, has_loops)

	return _format_level_dict(
		mission,
		target_pos,
		obs_vecs,
		plant_vecs,
		int(bfs["par_blocks"]),
		hint_text,
		str(candidate.get("message", "¡Nuevo nivel listo!"))
	)


static func _format_level_dict(
	mission: String,
	target_pos: Vector3i,
	obstacles: Array,
	plant_cells: Array,
	par_blocks: int,
	hint_text: String,
	message_text: String
) -> Dictionary:
	var obs_dicts: Array = []
	for o in obstacles:
		obs_dicts.append({"x": o.x, "z": o.z})
	var plant_dicts: Array = []
	for p in plant_cells:
		plant_dicts.append({"x": p.x, "z": p.z})

	return {
		"mission": mission,
		"target": {"x": target_pos.x, "z": target_pos.z},
		"obstacles": obs_dicts,
		"plant_cells": plant_dicts,
		"par_blocks": maxi(1, par_blocks),
		"hint": hint_text,
		"message": message_text,
	}


static func _compute_par_blocks(actions: Array[String], unlocked_blocks: Array) -> int:
	if actions.is_empty():
		return 1

	var has_loops: bool = ("for_loop" in unlocked_blocks) or ("while_loop" in unlocked_blocks)
	if not has_loops:
		return actions.size()

	var blocks: int = 0
	var i: int = 0
	var n: int = actions.size()

	while i < n:
		# 1. Racha de k >= 3 acciones idénticas consecutivas -> 1 bucle + 1 bloque interno = 2
		var run_len: int = 1
		while i + run_len < n and actions[i + run_len] == actions[i]:
			run_len += 1
		if run_len >= 3:
			blocks += 2
			i += run_len
			continue

		# 2. Patrón repetido de 2 acciones [A, B] (A != B) repetido >= 2 veces -> 3 bloques
		if i + 3 < n and actions[i] != actions[i + 1]:
			var pair_reps: int = _count_pattern_reps(actions, i, 2)
			if pair_reps >= 2:
				blocks += 3
				i += pair_reps * 2
				continue

		# 3. Patrón repetido de 3 acciones [A, B, C] repetido >= 2 veces -> 4 bloques
		if i + 5 < n:
			var triple_reps: int = _count_pattern_reps(actions, i, 3)
			if triple_reps >= 2:
				blocks += 4
				i += triple_reps * 3
				continue

		blocks += 1
		i += 1

	return maxi(1, blocks)


static func _count_pattern_reps(actions: Array[String], start_idx: int, pat_len: int) -> int:
	var n: int = actions.size()
	var reps: int = 1
	while start_idx + (reps + 1) * pat_len <= n:
		var matches: bool = true
		for offset in range(pat_len):
			if actions[start_idx + offset] != actions[start_idx + reps * pat_len + offset]:
				matches = false
				break
		if not matches:
			break
		reps += 1
	return reps


static func _reconstruct_actions(q_parent: Array[int], q_action: Array[String], goal_idx: int) -> Array[String]:
	var reversed: Array[String] = []
	var cur: int = goal_idx
	while cur > 0:
		reversed.append(q_action[cur])
		cur = q_parent[cur]

	var actions: Array[String] = []
	for idx in range(reversed.size() - 1, -1, -1):
		actions.append(reversed[idx])
	return actions


static func _to_cell(raw_val: Variant) -> Vector3i:
	if raw_val is Vector3i:
		var v: Vector3i = raw_val
		return Vector3i(v.x, 0, v.z)
	if typeof(raw_val) == TYPE_DICTIONARY:
		var d: Dictionary = raw_val
		return Vector3i(int(d.get("x", 0)), 0, int(d.get("z", 0)))
	return Vector3i.ZERO


static func _build_auto_hint(
	mission: String,
	optimal_actions: Array,
	plant_cells: Array,
	target_pos: Vector3i,
	has_loops: bool
) -> String:
	var prefix_forward: int = 0
	for act in optimal_actions:
		if str(act) == "avanzar":
			prefix_forward += 1
		else:
			break

	var parts: Array[String] = []
	if prefix_forward >= 3 and has_loops:
		parts.append("Comienza con un bucle FOR de %d pasos Avanzar()." % prefix_forward)
	elif prefix_forward > 0:
		parts.append("Comienza avanzando %d %s hacia adelante." % [
			prefix_forward,
			"casilla" if prefix_forward == 1 else "casillas",
		])

	if mission == "plant" and not plant_cells.is_empty():
		parts.append("Usa Interactuar() sobre las %d casillas marcadas." % plant_cells.size())

	parts.append("Lleva el tractor finalmente a la meta en (%d, %d)." % [target_pos.x, target_pos.z])
	return " ".join(parts)
