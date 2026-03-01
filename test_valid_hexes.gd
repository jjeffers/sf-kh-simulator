extends SceneTree

func _init():
	var scenario_manager = preload("res://Scripts/ScenarioManager.gd").new()
	
	# Stub out hex grid to prevent errors when parsing
	# Note: since ScenarioManager uses static functions, we can call it directly on the class
	
	NetworkManager.lobby_data = {"scenario": "battle_of_kenzah"}
	
	# Create a dummy ship
	var test_ship = Node.new()
	test_ship.set_script(preload("res://Scripts/Ship.gd"))
	test_ship.ship_class = "Assault Scout"
	test_ship.name = "Rapier"
	
	var ships = [test_ship]
	
	# Call static function via class (assuming the script itself is the class)
	var sc = preload("res://Scripts/ScenarioManager.gd")
	var hexes = sc.get_valid_deployment_hexes(0, ships, [], test_ship)
	
	print("\n\n=== HEXES FOR BATTLE OF KENZAH UPF ===")
	print("Size of valid_hexes: ", hexes.size())
	if hexes.size() > 0:
		print("Sample hexes: ", hexes[0], hexes[1])
	print("=========================================\n\n")
	
	quit()
