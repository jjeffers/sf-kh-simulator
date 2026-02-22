extends SceneTree

func _init():
	var ship = load("res://Scripts/Ship.gd")
	if ship == null:
		print("SHIP FAILED TO LOAD")
	else:
		var s = ship.new()
		if s == null:
			print("SHIP INSTANTIATION FAILED")
		else:
			print("SHIP LOADED")
			
	var combat = load("res://Scripts/Combat.gd")
	if combat == null:
		print("COMBAT FAILED TO LOAD")
	else:
		print("COMBAT LOADED")
		
	var gm = load("res://Scripts/GameManager.gd")
	if gm == null:
		print("GM FAILED TO LOAD")
	else:
		print("GM LOADED")
	quit()
