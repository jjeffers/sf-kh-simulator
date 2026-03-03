extends CanvasLayer

@onready var btn_resume = $Panel/VBox/BtnResume
@onready var btn_save = $Panel/VBox/BtnSave
@onready var btn_load = $Panel/VBox/BtnLoad
@onready var btn_settings = $Panel/VBox/BtnSettings
@onready var btn_quit = $Panel/VBox/BtnQuit

signal closed

func _ready():
	_update_buttons()
	btn_resume.pressed.connect(_on_resume)
	btn_save.pressed.connect(_on_save)
	btn_load.pressed.connect(_on_load)
	btn_settings.pressed.connect(_on_settings)
	btn_quit.pressed.connect(_on_quit)

func _update_buttons():
	if multiplayer.is_server():
		btn_save.disabled = false
		btn_load.disabled = false
	else:
		btn_save.disabled = true
		btn_load.disabled = true
		btn_save.tooltip_text = "Only the Host can save the campaign."
		btn_load.tooltip_text = "Only the Host can load a campaign."

func _on_resume():
	closed.emit()
	queue_free()

func _on_save():
	if multiplayer.is_server():
		var fd = FileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		fd.access = FileDialog.ACCESS_USERDATA
		fd.current_dir = "user://"
		fd.filters = PackedStringArray(["*.json ; JSON Files"])
		fd.title = "Save Campaign"
		fd.use_native_dialog = true
		fd.file_selected.connect(func(path):
			if CampaignManager.save_campaign(path):
				ConsoleManager.log_message("[color=green]Campaign saved successfully to %s.[/color]" % path.get_file())
			else:
				ConsoleManager.log_message("[color=red]Failed to save campaign.[/color]")
			fd.queue_free()
		)
		fd.canceled.connect(func(): fd.queue_free())
		add_child(fd)
		fd.popup_centered(Vector2(600, 400))

func _on_load():
	if multiplayer.is_server():
		var fd = FileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		fd.access = FileDialog.ACCESS_USERDATA
		fd.current_dir = "user://"
		fd.filters = PackedStringArray(["*.json ; JSON Files"])
		fd.title = "Load Campaign"
		fd.use_native_dialog = true
		fd.file_selected.connect(func(path):
			if CampaignManager.load_campaign(path):
				ConsoleManager.log_message("[color=green]Campaign loaded successfully from %s.[/color]" % path.get_file())
			else:
				ConsoleManager.log_message("[color=red]Failed to load campaign.[/color]")
			fd.queue_free()
		)
		fd.canceled.connect(func(): fd.queue_free())
		add_child(fd)
		fd.popup_centered(Vector2(600, 400))

func _on_settings():
	var settings_scn = load("res://Scenes/SettingsMenu.tscn").instantiate()
	add_child(settings_scn)

func _on_quit():
	# Return to main menu cleanly
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	# If networked, disconnect
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	queue_free()
