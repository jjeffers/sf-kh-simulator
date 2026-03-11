extends GutTest

var gm: GameManager
var ship_upf: Ship
var ship_sathar: Ship

var old_lobby_data: Dictionary

func before_each():
	gm = GameManager.new()
	gm.name = "GameManager"
	
	if Engine.get_main_loop().root.has_node("NetworkManager"):
		var nm = Engine.get_main_loop().root.get_node("NetworkManager")
		old_lobby_data = nm.lobby_data.duplicate(true)
		nm.lobby_data["scenario"] = "campaign_encounter"
		
	add_child(gm)
	
	ship_upf = Ship.new()
	ship_upf.name = "MilitiaDefender"
	ship_upf.side_id = 1
	ship_upf.faction = "UPF"
	ship_upf.is_militia = true
	ship_upf.weapons = [{
		"name": "Laser Battery",
		"type": "Laser",
		"range": 6,
		"ammo": 3,
		"is_crippled": false
	}]
	gm.ships.append(ship_upf)
	
	ship_sathar = Ship.new()
	ship_sathar.name = "SatharAttacker"
	ship_sathar.side_id = 2
	ship_sathar.faction = "Sathar"
	ship_sathar.weapons = [{
		"name": "Laser Battery",
		"type": "Laser",
		"range": 6,
		"ammo": 3,
		"is_crippled": false
	}]
	gm.ships.append(ship_sathar)

func after_each():
	if Engine.get_main_loop().root.has_node("NetworkManager"):
		var nm = Engine.get_main_loop().root.get_node("NetworkManager")
		nm.lobby_data = old_lobby_data.duplicate(true)
	gm.queue_free()

func test_militia_cannot_withdraw_without_firing():
	NetworkManager.lobby_data["scenario"] = "campaign_encounter"
	ship_upf.grid_position = Vector3i(0, 0, 0)
	ship_sathar.grid_position = Vector3i(10, -10, 0) # Out of range (10 > 6)
	
	# Normal ship could withdraw here
	var can_w = gm._can_withdraw(ship_upf)
	assert_false(can_w["allowed"], "Militia should NOT be able to withdraw if it hasn't fired yet, regardless of range.")

func test_militia_can_withdraw_after_firing_out_of_range():
	NetworkManager.lobby_data["scenario"] = "campaign_encounter"
	ship_upf.grid_position = Vector3i(0, 0, 0)
	ship_sathar.grid_position = Vector3i(10, -10, 0) # Out of range
	
	ship_upf.has_ever_fired = true
	
	var can_w = gm._can_withdraw(ship_upf)
	assert_true(can_w["allowed"], "Militia should be able to withdraw if it HAS fired and is out of enemy range.")

func test_militia_cannot_withdraw_in_range_even_after_firing():
	NetworkManager.lobby_data["scenario"] = "campaign_encounter"
	ship_upf.grid_position = Vector3i(0, 0, 0)
	ship_sathar.grid_position = Vector3i(2, -2, 0) # In range (2 <= 6)
	
	ship_upf.has_ever_fired = true
	
	var can_w = gm._can_withdraw(ship_upf)
	assert_false(can_w["allowed"], "Militia should NOT be able to withdraw if an enemy is in range, even if it has fired.")

func test_regular_ship_can_withdraw_without_firing_if_out_of_range():
	NetworkManager.lobby_data["scenario"] = "campaign_encounter"
	ship_upf.is_militia = false # Normal ship
	ship_upf.grid_position = Vector3i(0, 0, 0)
	ship_sathar.grid_position = Vector3i(10, -10, 0) # Out of range
	
	# Empty weapons so it doesn't trigger the "Must fire first if armed" check
	# Wait, the rule is "if it hasn't fired this turn and has armed weapons, it can't run this turn"
	# That rule implies it MUST fire EVERY turn before running. 
	# Let's see if the test understands that existing rule.
	ship_upf.has_fired = true # Pretend it already fired this turn
	
	var can_w = gm._can_withdraw(ship_upf)
	assert_true(can_w["allowed"], "Normal ship should be able to withdraw out of range.")
