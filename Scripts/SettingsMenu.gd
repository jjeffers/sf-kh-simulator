extends CanvasLayer

@onready var music_slider = $Panel/VBox/HBoxMusic/MusicSlider
@onready var sfx_slider = $Panel/VBox/HBoxSFX/SFXSlider
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

func _on_music_changed(value: float):
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(value))

func _on_sfx_changed(value: float):
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(value))

func _on_close_pressed():
	closed.emit()
	queue_free()
