extends SceneTree
func _init():
    var stream = load("res://Assets/Audio/Orbital Siege (Drums).mp3")
    print("TEST LOAD DRUMS: ", stream)
    var player = AudioStreamPlayer.new()
    player.stream = stream
    player.play()
    print("IS PLAYING? ", player.playing)
    quit()
