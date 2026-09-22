class_name BlockDefinition
## Definiciones estáticas de todos los tipos de bloque, sus colores y templates de código.

enum Category { TRACTOR, LOOP, FLOW, VARIABLE }

const BLOCKS: Dictionary = {
	"avanzar": { "label": "Avanzar()", "category": Category.TRACTOR, "container": false, "code": "avanzar()" },
	"girar_derecha": { "label": "Girar Derecha()", "category": Category.TRACTOR, "container": false, "code": "girar_derecha()" },
	"girar_izquierda": { "label": "Girar Izquierda()", "category": Category.TRACTOR, "container": false, "code": "girar_izquierda()" },
	"interactuar": { "label": "Interactuar()", "category": Category.TRACTOR, "container": false, "code": "interactuar()" },
	"for_loop": { "label": "for i in range({count}):", "category": Category.LOOP, "container": true, "code": "for i in range({count}):" },
	"while_loop": { "label": "while {condition}:", "category": Category.FLOW, "container": true, "code": "while {condition}:" },
	"if_block": { "label": "if {condition}:", "category": Category.FLOW, "container": true, "code": "if {condition}:" },
	"elif_block": { "label": "elif {condition}:", "category": Category.FLOW, "container": true, "code": "elif {condition}:" },
	"else_block": { "label": "else:", "category": Category.FLOW, "container": true, "code": "else:" },
	"var_decl": { "label": "var {name} = {value}", "category": Category.VARIABLE, "container": false, "code": "var {name} = {value}" },
	"var_ref": { "label": "{name}", "category": Category.VARIABLE, "container": false, "code": "{name}" },
	"var_inc": { "label": "{name} += 1", "category": Category.VARIABLE, "container": false, "code": "{name} += 1" },
}

const CATEGORY_COLORS: Dictionary = {
	Category.TRACTOR: Color(0.98, 0.82, 0.28),
	Category.LOOP: Color(0.3, 0.6, 1.0),
	Category.FLOW: Color(0.75, 0.45, 0.9),
	Category.VARIABLE: Color(0.3, 0.8, 0.4),
}

static func get_color(type: String) -> Color:
	var def: Dictionary = BLOCKS.get(type, {})
	var cat = def.get("category", Category.TRACTOR)
	return CATEGORY_COLORS.get(cat, Color.WHITE)

static func get_label(type: String, params: Dictionary = {}) -> String:
	var def: Dictionary = BLOCKS.get(type, {})
	var label: String = def.get("label", type)
	for key in params:
		label = label.replace("{" + key + "}", str(params[key]))
	return label

static func is_container(type: String) -> bool:
	return BLOCKS.get(type, {}).get("container", false)

static func generate_code_line(type: String, params: Dictionary = {}) -> String:
	var def: Dictionary = BLOCKS.get(type, {})
	var code: String = def.get("code", "")
	for key in params:
		code = code.replace("{" + key + "}", str(params[key]))
	return code
