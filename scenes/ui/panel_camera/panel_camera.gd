extends Control
## Panel de Cámara: Muestra la vista cenital del campo.

const StationTheme = preload("res://scenes/ui/theme/station_theme.gd")

func _ready() -> void:
	# Tema compartido de la estación.
	theme = StationTheme.get_theme()
