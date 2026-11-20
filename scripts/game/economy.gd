class_name Economy
extends RefCounted
## Catálogo central de bloques, edificios, precios, bonos y objetivos del juego.

const INITIAL_UNLOCKED_BLOCKS: Array[String] = [
	"avanzar",
	"girar_derecha",
	"girar_izquierda",
]

const BLOCK_PRICES: Dictionary = {
	"interactuar": 30,
	"for_loop": 50,
	"variables": 80,
	"while_loop": 100,
	"if_else": 120,
}

const BLOCK_INFO: Dictionary = {
	"interactuar": {
		"name": "Interactuar()",
		"price": 30,
		"desc": "Planta semillas en el campo y habilita misiones de Sembrar.",
		"icon": "",
	},
	"for_loop": {
		"name": "Bucle FOR",
		"price": 50,
		"desc": "Repite instrucciones un número fijo de veces para ahorrar bloques.",
		"icon": "",
	},
	"variables": {
		"name": "Taller de Variables",
		"price": 80,
		"desc": "Crea variables y condiciones personalizadas para controlar flujos.",
		"icon": "",
	},
	"while_loop": {
		"name": "Bucle WHILE",
		"price": 100,
		"desc": "Repite instrucciones mientras se cumpla una condición.",
		"icon": "",
	},
	"if_else": {
		"name": "Condicional IF / ELSE",
		"price": 120,
		"desc": "Toma decisiones según una condición lógica.",
		"icon": "",
	},
}

const BUILDING_PRICES: Dictionary = {
	"fences": 40,
	"well": 60,
	"chicken_coop": 90,
	"silo": 120,
	"windmill": 150,
	"barn": 250,
}

const BUILDING_INFO: Dictionary = {
	"fences": {
		"name": "Cercas",
		"price": 40,
		"bonus": "Delimita y protege el campo con cercas de madera.",
		"scene_path": "res://assets/scenes/farm_assets/structures/Bld_02_Fence_Wood_01.tscn",
		"icon": "",
	},
	"well": {
		"name": "Pozo",
		"price": 60,
		"bonus": "1 pista gratis por nivel.",
		"scene_path": "res://assets/scenes/farm_assets/structures/Bld_Well_01.tscn",
		"icon": "",
	},
	"chicken_coop": {
		"name": "Gallinero",
		"price": 90,
		"bonus": "+1 moneda por cada estrella.",
		"scene_path": "res://assets/scenes/farm_assets/structures/Bld_Chicken_Coop_01.tscn",
		"icon": "",
	},
	"silo": {
		"name": "Silo",
		"price": 120,
		"bonus": "+10 % monedas en cada nivel.",
		"scene_path": "res://assets/scenes/farm_assets/structures/Bld_Silo_01.tscn",
		"icon": "",
	},
	"windmill": {
		"name": "Molino",
		"price": 150,
		"bonus": "+50 % monedas en misiones de Sembrar.",
		"scene_path": "res://assets/scenes/farm_assets/structures/Bld_Windmill_01.tscn",
		"icon": "",
	},
	"barn": {
		"name": "Granero",
		"price": 250,
		"bonus": "Estructura principal para alcanzar el 100 %.",
		"scene_path": "res://assets/scenes/farm_assets/structures/Bld_Barn_01.tscn",
		"icon": "",
	},
}

const HINT_COST: int = 5

const OBJECTIVES: Array[Dictionary] = [
	{
		"id": "first_level",
		"title": "Primeros surcos",
		"desc": "Completa 1 nivel con el tractor.",
		"reward": 15,
		"type": "levels_completed",
		"target": 1,
	},
	{
		"id": "save_30_coins",
		"title": "Ahorro inicial",
		"desc": "Alcanza 30 monedas en tu reserva.",
		"reward": 15,
		"type": "coins_reached",
		"target": 30,
	},
	{
		"id": "buy_interactuar",
		"title": "Manos a la tierra",
		"desc": "Compra el bloque Interactuar() en la Tienda.",
		"reward": 20,
		"type": "block_unlocked",
		"target": "interactuar",
	},
	{
		"id": "first_plant",
		"title": "Primera cosecha",
		"desc": "Completa 1 misión de Sembrar.",
		"reward": 25,
		"type": "plant_levels_completed",
		"target": 1,
	},
	{
		"id": "buy_fences",
		"title": "Terreno cercado",
		"desc": "Construye las Cercas alrededor del campo.",
		"reward": 20,
		"type": "building_purchased",
		"target": "fences",
	},
	{
		"id": "buy_for_loop",
		"title": "Automatización",
		"desc": "Compra el bloque Bucle FOR en la Tienda.",
		"reward": 25,
		"type": "block_unlocked",
		"target": "for_loop",
	},
	{
		"id": "buy_well",
		"title": "Agua fresca",
		"desc": "Construye el Pozo para recibir 1 pista gratis por nivel.",
		"reward": 25,
		"type": "building_purchased",
		"target": "well",
	},
	{
		"id": "three_stars",
		"title": "Código eficiente",
		"desc": "Logra 3 estrellas en un nivel.",
		"reward": 30,
		"type": "max_stars",
		"target": 3,
	},
	{
		"id": "buy_chicken_coop",
		"title": "Granja avícola",
		"desc": "Construye el Gallinero (+1 moneda por estrella).",
		"reward": 30,
		"type": "building_purchased",
		"target": "chicken_coop",
	},
	{
		"id": "buy_vars_and_while",
		"title": "Lógica avanzada",
		"desc": "Compra Taller de Variables y Bucle WHILE.",
		"reward": 40,
		"type": "blocks_all",
		"target": ["variables", "while_loop"],
	},
	{
		"id": "buy_silo_and_windmill",
		"title": "Cosecha mayor",
		"desc": "Construye el Silo y el Molino de viento.",
		"reward": 40,
		"type": "buildings_all",
		"target": ["silo", "windmill"],
	},
	{
		"id": "restore_100",
		"title": "Maestro Granjero",
		"desc": "Compra IF / ELSE y construye el Granero para el 100 %.",
		"reward": 50,
		"type": "restoration_percent",
		"target": 100,
	},
]


## Devuelve la cantidad total de mejoras comprables (5 bloques + 6 edificios = 11).
static func get_total_upgrade_count() -> int:
	return BLOCK_PRICES.size() + BUILDING_PRICES.size()
