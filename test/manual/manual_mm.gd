extends SceneTree

func _init():
    var mn = preload("res://Scripts/MusicManager.gd").new()
    self.root.add_child(mn)
    
    print("Testing play_music 1...")
    mn.play_music("res://Assets/Audio/Orbital Siege.mp3", -12.0, 2.0)
    
    # Wait half a second, then play 2
    var t = create_timer(0.5)
    await t.timeout
    
    print("Testing play_music 2...")
    mn.play_music("res://Assets/Audio/Orbital Siege (Drums).mp3")
    
    # Wait a bit
    var t2 = create_timer(1.5)
    await t2.timeout
    
    print("Fading players are size: ", mn._fading_players.size())
    for f in mn._fading_players:
        print("Fading player vol: ", f.volume_db)
    
    if mn._active_player:
        print("Active player vol: ", mn._active_player.volume_db, " playing: ", mn._active_player.playing)
    else:
        print("NO ACTIVE PLAYER")
    
    quit()
