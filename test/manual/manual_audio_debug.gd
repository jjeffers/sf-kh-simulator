extends SceneTree
func _init():
    var bus_idx = AudioServer.get_bus_index("Music")
    var vol = AudioServer.get_bus_volume_db(bus_idx)
    var muted = AudioServer.is_bus_mute(bus_idx)
    var master_vol = AudioServer.get_bus_volume_db(0)
    var master_muted = AudioServer.is_bus_mute(0)
    
    var file = FileAccess.open("user://audio_debug.txt", FileAccess.WRITE)
    file.store_string("Music Bus -> vol: " + str(vol) + ", muted: " + str(muted) + "\n")
    file.store_string("Master Bus -> vol: " + str(master_vol) + ", muted: " + str(master_muted) + "\n")
    file.close()
    
    quit()
