extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)

func after_each():
	_gm.free()
    
func test_rpc_add_attack():
	# Setup Ships
	var s1 = ShipScript.new()
	s1.name = "Ship1"
	s1.side_id = 1
	s1.current_weapon_index = 0
	s1.weapons = [ {"name": "Laser", "type": "Laser", "range": 5, "arc": "360", "ammo": 10}]
	_gm.ships.append(s1)
	
	var s2 = ShipScript.new()
	s2.name = "Target1"
	s2.side_id = 2
	_gm.ships.append(s2)
	
	# Execute RPC (Direct call to simulate receipt)
	_gm.rpc_add_attack("Ship1", "Target1", 0)
	
	# Verify Queue
	assert_eq(_gm.queued_attacks.size(), 1, "Should have 1 queued attack")
	var atk = _gm.queued_attacks[0]
	assert_eq(atk["source"], s1)
	assert_eq(atk["target"], s2)
	assert_eq(atk["weapon_name"], "Laser")
	
func test_rpc_remove_attack():
	# Setup (Same as above)
	var s1 = ShipScript.new()
	s1.name = "Ship1"
	s1.weapons = [ {"name": "Laser", "type": "Laser", "range": 5, "arc": "360", "ammo": 10}]
	_gm.ships.append(s1)
	
	var s2 = ShipScript.new()
	s2.name = "Target1"
	_gm.ships.append(s2)
	
	# Add first
	_gm.rpc_add_attack("Ship1", "Target1", 0)
	assert_eq(_gm.queued_attacks.size(), 1)
	
	# Remove
	_gm.rpc_remove_attack("Ship1", 0)
	
	# Verify Empty
	assert_eq(_gm.queued_attacks.size(), 0, "Queue should be empty after removal")
