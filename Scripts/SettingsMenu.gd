extends CanvasLayer

@onready var music_slider = $Panel/VBox/HBoxMusic/MusicSlider
@onready var sfx_slider = $Panel/VBox/HBoxSFX/SFXSlider
@onready var player_name_input = $Panel/VBox/HBoxPlayer/PlayerNameInput
@onready var close_btn = $Panel/VBox/CloseBtn

var music_bus: int
var sfx_bus: int

signal closed

func _ready():
	music_bus = AudioServer.get_bus_index("Music")
	sfx_bus = AudioServer.get_bus_index("SFX")
	
	close_btn.pressed.connect(_on_close_pressed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	
	if music_bus >= 0:
		music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
	if sfx_bus >= 0:
		sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))
		
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var loaded_name = config.get_value("Player", "name", "")
		if loaded_name != "":
			player_name_input.text = loaded_name

func _on_music_changed(value: float):
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(value))

func _on_sfx_changed(value: float):
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(value))

func _on_close_pressed():
	_save_settings()
	closed.emit()
	queue_free()

func _save_settings():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	if music_bus >= 0:
		config.set_value("Audio", "music_volume", db_to_linear(AudioServer.get_bus_volume_db(music_bus)))
	if sfx_bus >= 0:
		config.set_value("Audio", "sfx_volume", db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)))
		
	var p_name = player_name_input.text.strip_edges()
	if p_name != "":
		config.set_value("Player", "name", p_name)
		# Immediately update NetworkManager if available
		if NetworkManager and "player_info" in NetworkManager:
			NetworkManager.player_info["name"] = p_name
			
	config.save("user://settings.cfg")

