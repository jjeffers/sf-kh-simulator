extends Node

var _player: AudioStreamPlayer
var _tween: Tween

func _ready():
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.bus = "Master" # Or "Music" if we had one

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
	
	if fade_in > 0:
		_player.volume_db = -80.0
		if _tween: _tween.kill()
		_tween = create_tween()
		_tween.tween_property(_player, "volume_db", volume_db, fade_in)

func fade_out(duration: float = 1.0):
	if not _player.playing: return
	
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", -80.0, duration)
	_tween.tween_callback(_player.stop)
