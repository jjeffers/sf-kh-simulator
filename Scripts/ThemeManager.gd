extends Node

func _ready():
	var theme = ThemeDB.get_project_theme()
	if theme == null:
		theme = Theme.new()
		ProjectSettings.set_setting("gui/theme/custom", "res://Scripts/GlobalTheme.tres") # Not ideal
