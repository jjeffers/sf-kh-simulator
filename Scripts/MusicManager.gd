extends Node

var _player: AudioStreamPlayer
var _tween: Tween

func _ready():
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.bus = "Music"
	_load_settings()

func _load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	
	if err == OK:
		if config.has_section_key("Audio", "music_volume"):
			var vol = config.get_value("Audio", "music_volume")
			if music_bus >= 0:
				AudioServer.set_bus_volume_db(music_bus, linear_to_db(vol))
		else:
			if music_bus >= 0:
				AudioServer.set_bus_volume_db(music_bus, linear_to_db(0.65))
			config.set_value("Audio", "music_volume", 0.65)
			config.save("user://settings.cfg")
			
		if config.has_section_key("Audio", "sfx_volume"):
			var vol = config.get_value("Audio", "sfx_volume")
			if sfx_bus >= 0:
				AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(vol))
		else:
			if sfx_bus >= 0:
				AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(1.0))
			config.set_value("Audio", "sfx_volume", 1.0)
			config.save("user://settings.cfg")
	else:
		if music_bus >= 0:
			AudioServer.set_bus_volume_db(music_bus, linear_to_db(0.65))
		if sfx_bus >= 0:
			AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(1.0))
		config.set_value("Audio", "music_volume", 0.65)
		config.set_value("Audio", "sfx_volume", 1.0)
		config.save("user://settings.cfg")

func play_music(stream_path: String, volume_db: float = 0.0, fade_in: float = 0.0):
	var stream = load(stream_path)
	if not stream:
		printerr("MusicManager: Could not load stream: %s" % stream_path)
		return
		
	if _player.stream == stream and _player.playing:
		return # Already playing
		
	_player.stream = stream
	_player.volume_db = volume_db
	_player.play()
	
	if _tween: _tween.kill()
	
	if fade_in > 0:
		_player.volume_db = -80.0
		_tween = create_tween()
		_tween.tween_property(_player, "volume_db", volume_db, fade_in)

func fade_out(duration: float = 1.0):
	if not _player.playing: return
	
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", -80.0, duration)
	_tween.tween_callback(_player.stop)
