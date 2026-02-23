extends SceneTree
func _init():
    var script = load("res://Scripts/GameManager.gd")
    if script: print("Loaded")
    else: print("Failed to load")
    quit()
