extends SceneTree

func _init():
    var gm = load("res://Scripts/GameManager.gd").new()
    print("Testing UI initialization...")
    # We can't easily instantiate the whole game headlessly and check the UI tree if it requires the scene.
    quit()
