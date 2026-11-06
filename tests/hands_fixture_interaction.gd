extends Node
## Stub mínimo de DesktopInteraction para las pruebas de manos.
## Expone la misma superficie pública que el script real, sin tocar el ratón.

var pointer_pressed := false
var _programming := false

func is_programming() -> bool:
	return _programming

func is_exploring() -> bool:
	return not _programming

func set_programming(value: bool) -> void:
	_programming = value

func set_pointer_pressed(value: bool) -> void:
	pointer_pressed = value
