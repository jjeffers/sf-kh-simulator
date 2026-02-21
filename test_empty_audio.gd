extends SceneTree
func _init():
    var player = AudioStreamPlayer.new()
    # player.stream is null
    player.play()
    print("FINISHED PLAY")
    quit()
