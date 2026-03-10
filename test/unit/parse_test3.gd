extends SceneTree

func _init():
	var test_runner = load("res://Scripts/NetworkManager.gd").new()
	# Just call the hook manually to see what's actually there 
	print("Starting simulation")
	
	var res = preload("res://Scripts/MainMenu.gd").new()
	# This won't run cleanly due to tree dependencies, but we can verify the JSON directly.
	
	quit()
