extends RefCounted
## Tema compartido de la "Estación de Programación" de CodeXperience.
##
## Estética: base oscura azulada, acentos verde menta (primario) y ámbar
## (secundario), tarjetas con bordes suaves, tipografía legible y estados
## hover / pressed / focus / disabled coherentes en todos los paneles.
##
## Se construye por código para poder aplicar variaciones de tipo (botones
## primarios, de acento, de peligro, etc.) tanto a los widgets definidos en
## las escenas .tscn como a los creados dinámicamente en los scripts.

# ============================================
# PALETA
# ============================================
const BG_DEEP := Color(0.043, 0.055, 0.078)      # Fondo general de panel
const SURFACE := Color(0.071, 0.090, 0.125)      # Fondo de tarjeta
const CARD := Color(0.098, 0.125, 0.169)         # Tarjeta
const CARD_HOVER := Color(0.129, 0.169, 0.220)   # Tarjeta en hover
const CARD_PRESSED := Color(0.078, 0.106, 0.145) # Tarjeta presionada
const INPUT_BG := Color(0.063, 0.082, 0.114)     # Campos de texto
const BORDER := Color(0.180, 0.220, 0.286)       # Borde suave
const BORDER_STRONG := Color(0.271, 0.333, 0.416)

const TEXT := Color(0.886, 0.925, 0.965)         # Texto principal
const TEXT_MUTED := Color(0.635, 0.694, 0.769)   # Texto secundario
const TEXT_FAINT := Color(0.451, 0.506, 0.588)   # Texto terciario / deshabilitado

const MINT := Color(0.435, 0.890, 0.690)         # Acento primario
const MINT_DEEP := Color(0.161, 0.404, 0.310)
const AMBER := Color(0.957, 0.769, 0.420)        # Acento secundario
const AMBER_DEEP := Color(0.451, 0.325, 0.129)
const ROSE := Color(0.945, 0.522, 0.510)         # Peligro / cancelar
const ROSE_DEEP := Color(0.427, 0.196, 0.196)
const SKY := Color(0.541, 0.749, 0.965)          # Información / bucles
const LILAC := Color(0.741, 0.667, 0.941)         # Control de flujo

const FONT_BODY := 16
const FONT_BUTTON := 17
const FONT_SECTION := 19
const FONT_TITLE := 25
const FONT_HELP := 16

const MIN_TOUCH_HEIGHT := 44
const MIN_TOUCH_WIDTH := 48

static var _cached: Theme = null

## Devuelve la instancia única del tema (se reutiliza en todos los paneles).
static func get_theme() -> Theme:
	if _cached == null:
		_cached = _build()
	return _cached

# ============================================
# CONSTRUCCIÓN
# ============================================
static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY

	_build_buttons(t)
	_build_labels(t)
	_build_containers(t)
	_build_inputs(t)
	_build_variations(t)
	return t

static func _build_buttons(t: Theme) -> void:
	t.set_stylebox("normal", "Button", _flat(CARD, BORDER, 1, 10, 16, 9))
	t.set_stylebox("hover", "Button", _flat(CARD_HOVER, MINT_DEEP, 1, 10, 16, 9))
	t.set_stylebox("pressed", "Button", _flat(CARD_PRESSED, MINT, 1, 10, 16, 9))
	t.set_stylebox("disabled", "Button", _flat(Color(0.071, 0.086, 0.110), Color(0.129, 0.157, 0.196), 1, 10, 16, 9))
	t.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), AMBER, 2, 10, 16, 9))

	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", MINT)
	t.set_color("font_disabled_color", "Button", TEXT_FAINT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_font_size("font_size", "Button", FONT_BUTTON)
	t.set_constant("h_separation", "Button", 8)

static func _build_labels(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", FONT_BODY)
	t.set_constant("line_spacing", "Label", 4)

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", FONT_BODY)

static func _build_containers(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", _flat(SURFACE, BORDER, 1, 12, 12, 12))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	var sep := StyleBoxLine.new()
	sep.color = BORDER
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("separator", "VSeparator", sep)
	t.set_constant("separation", "HSeparator", 12)
	t.set_constant("separation", "VSeparator", 12)

	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("margin_left", "MarginContainer", 16)
	t.set_constant("margin_top", "MarginContainer", 16)
	t.set_constant("margin_right", "MarginContainer", 16)
	t.set_constant("margin_bottom", "MarginContainer", 16)

static func _build_inputs(t: Theme) -> void:
	var field := _flat(INPUT_BG, BORDER, 1, 8, 10, 8)
	var field_focus := _flat(INPUT_BG, MINT, 2, 8, 10, 8)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_FAINT)
	t.set_color("caret_color", "LineEdit", MINT)
	t.set_font_size("font_size", "LineEdit", FONT_BODY)

	t.set_stylebox("normal", "CodeEdit", field)
	t.set_stylebox("focus", "CodeEdit", field_focus)
	t.set_color("font_color", "CodeEdit", TEXT)
	t.set_font_size("font_size", "CodeEdit", FONT_BODY)

	t.set_stylebox("normal", "RichTextLabel", _flat(INPUT_BG, BORDER, 1, 10, 12, 12))

static func _build_variations(t: Theme) -> void:
	# --- Botón primario (menta): acción principal ---
	t.set_type_variation("StationPrimary", "Button")
	t.set_stylebox("normal", "StationPrimary", _flat(Color(0.106, 0.196, 0.169), MINT_DEEP, 1, 10, 16, 9))
	t.set_stylebox("hover", "StationPrimary", _flat(Color(0.145, 0.290, 0.239), MINT, 1, 10, 16, 9))
	t.set_stylebox("pressed", "StationPrimary", _flat(Color(0.075, 0.157, 0.133), MINT, 2, 10, 16, 9))
	t.set_stylebox("disabled", "StationPrimary", _flat(Color(0.078, 0.106, 0.110), Color(0.129, 0.157, 0.196), 1, 10, 16, 9))
	t.set_stylebox("focus", "StationPrimary", _flat(Color(0, 0, 0, 0), AMBER, 2, 10, 16, 9))
	t.set_color("font_color", "StationPrimary", MINT)
	t.set_color("font_hover_color", "StationPrimary", Color.WHITE)
	t.set_color("font_pressed_color", "StationPrimary", Color.WHITE)
	t.set_color("font_disabled_color", "StationPrimary", TEXT_FAINT)

	# --- Botón de acento (ámbar): construir / confirmar ---
	t.set_type_variation("StationAccent", "Button")
	t.set_stylebox("normal", "StationAccent", _flat(Color(0.184, 0.153, 0.090), AMBER_DEEP, 1, 10, 16, 9))
	t.set_stylebox("hover", "StationAccent", _flat(Color(0.259, 0.208, 0.114), AMBER, 1, 10, 16, 9))
	t.set_stylebox("pressed", "StationAccent", _flat(Color(0.133, 0.110, 0.063), AMBER, 2, 10, 16, 9))
	t.set_stylebox("disabled", "StationAccent", _flat(Color(0.078, 0.106, 0.110), Color(0.129, 0.157, 0.196), 1, 10, 16, 9))
	t.set_stylebox("focus", "StationAccent", _flat(Color(0, 0, 0, 0), AMBER, 2, 10, 16, 9))
	t.set_color("font_color", "StationAccent", AMBER)
	t.set_color("font_hover_color", "StationAccent", Color.WHITE)
	t.set_color("font_pressed_color", "StationAccent", Color.WHITE)
	t.set_color("font_disabled_color", "StationAccent", TEXT_FAINT)

	# --- Botón de peligro (rosa): limpiar / cancelar ---
	t.set_type_variation("StationDanger", "Button")
	t.set_stylebox("normal", "StationDanger", _flat(Color(0.184, 0.106, 0.106), ROSE_DEEP, 1, 10, 16, 9))
	t.set_stylebox("hover", "StationDanger", _flat(Color(0.259, 0.137, 0.137), ROSE, 1, 10, 16, 9))
	t.set_stylebox("pressed", "StationDanger", _flat(Color(0.133, 0.078, 0.078), ROSE, 2, 10, 16, 9))
	t.set_stylebox("disabled", "StationDanger", _flat(Color(0.078, 0.106, 0.110), Color(0.129, 0.157, 0.196), 1, 10, 16, 9))
	t.set_stylebox("focus", "StationDanger", _flat(Color(0, 0, 0, 0), AMBER, 2, 10, 16, 9))
	t.set_color("font_color", "StationDanger", ROSE)
	t.set_color("font_hover_color", "StationDanger", Color.WHITE)
	t.set_color("font_pressed_color", "StationDanger", Color.WHITE)
	t.set_color("font_disabled_color", "StationDanger", TEXT_FAINT)

	# --- Botón fantasma: acción secundaria sin peso visual ---
	t.set_type_variation("StationGhost", "Button")
	t.set_stylebox("normal", "StationGhost", _flat(Color(0.078, 0.098, 0.133), BORDER, 1, 10, 14, 8))
	t.set_stylebox("hover", "StationGhost", _flat(CARD_HOVER, BORDER_STRONG, 1, 10, 14, 8))
	t.set_stylebox("pressed", "StationGhost", _flat(CARD_PRESSED, TEXT_MUTED, 1, 10, 14, 8))
	t.set_stylebox("disabled", "StationGhost", _flat(Color(0.071, 0.086, 0.110), Color(0.129, 0.157, 0.196), 1, 10, 14, 8))
	t.set_stylebox("focus", "StationGhost", _flat(Color(0, 0, 0, 0), AMBER, 2, 10, 14, 8))
	t.set_color("font_color", "StationGhost", TEXT_MUTED)
	t.set_color("font_hover_color", "StationGhost", TEXT)
	t.set_color("font_pressed_color", "StationGhost", TEXT)
	t.set_color("font_disabled_color", "StationGhost", TEXT_FAINT)

	# --- Etiquetas ---
	t.set_type_variation("StationTitle", "Label")
	t.set_color("font_color", "StationTitle", MINT)
	t.set_font_size("font_size", "StationTitle", FONT_TITLE)

	t.set_type_variation("StationSection", "Label")
	t.set_color("font_color", "StationSection", TEXT)
	t.set_font_size("font_size", "StationSection", FONT_SECTION)

	t.set_type_variation("StationHelp", "Label")
	t.set_color("font_color", "StationHelp", TEXT_MUTED)
	t.set_font_size("font_size", "StationHelp", FONT_HELP)

	t.set_type_variation("StationValue", "Label")
	t.set_color("font_color", "StationValue", TEXT)
	t.set_font_size("font_size", "StationValue", 20)

# ============================================
# HELPERS
# ============================================
static func _flat(bg: Color, border: Color, border_w: int, radius: int, pad_h: int, pad_v: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s

## Aplica el tema compartido a un control raíz (los hijos heredan el tema).
static func apply(control: Control) -> void:
	control.theme = get_theme()
