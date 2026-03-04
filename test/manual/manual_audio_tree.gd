extends SceneTree
func _init():
    var mn = preload("res://Scripts/MusicManager.gd").new()
    self.root.add_child(mn)
    
    mn.play_music("res://Assets/Audio/Orbital Siege.mp3", -12.0, 2.0)
    
    var t = create_timer(0.1)
    await t.timeout
    
    mn.play_music("res://Assets/Audio/Orbital Siege (Drums).mp3")
    
    var t2 = create_timer(0.5)
    await t2.timeout
    
    print("CHILDREN IN MUSIC_MANAGER:")
    for child in mn.get_children():
        if child is AudioStreamPlayer:
             print("- player: ", child.stream.resource_path, " | playing: ", child.playing, " | DB: ", child.volume_db)
    
    quit()
