extends SceneTree

func _init():
	var gm = load("res://Scripts/GameManager.gd")
	if gm == null:
		print("FAILED TO LOAD GAMEMANAGER")
	else:
		print("SUCCESSFULLY LOADED GAMEMANAGER")
	quit()
