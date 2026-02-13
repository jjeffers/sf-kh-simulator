extends GutTest

var _gm = null
var _shooter: Ship = null
var _target: Ship = null

func before_each():
	_gm = load("res://Scripts/GameManager.gd").new()
	add_child(_gm)
	
	_shooter = Ship.new()
	_shooter.name = "Shooter"
	_shooter.side_id = 1
	_shooter.configure_assault_scout() # Has Laser Battery (Range 9)
	_gm.add_child(_shooter)
	
	_target = Ship.new()
	_target.name = "Target"
	_target.side_id = 2
	_target.configure_assault_scout()
	_gm.add_child(_target)
	
	_gm.ships.clear()
	_gm.ships.append(_shooter)
	_gm.ships.append(_target)

func after_each():
	_gm.free()

func test_fire_out_of_planet():
	# Shooter at (0,0,0) [PLANET]
	# Target at (0, -2, 2) [OUTSIDE]
	# Planet at (0,0,0)
	_gm.planet_hexes.clear()
	_gm.planet_hexes.append(Vector3i(0, 0, 0))
	_shooter.grid_position = Vector3i(0, 0, 0)
	_target.grid_position = Vector3i(0, -2, 2)
	
	var weapon = _shooter.weapons[0] # Laser Battery
	var valid = _gm._get_valid_targets_for_weapon(_shooter, weapon)
	
	assert_eq(valid.size(), 1, "Should be able to fire OUT of planet")
	if valid.size() > 0:
		assert_eq(valid[0], _target, "Target should be valid")

func test_fire_into_planet():
	# Shooter at (0, -2, 2) [OUTSIDE]
	# Target at (0,0,0) [PLANET]
	# Planet at (0,0,0)
	_gm.planet_hexes.clear()
	_gm.planet_hexes.append(Vector3i(0, 0, 0))
	_shooter.grid_position = Vector3i(0, -2, 2)
	_target.grid_position = Vector3i(0, 0, 0)
	
	var weapon = _shooter.weapons[0]
	var valid = _gm._get_valid_targets_for_weapon(_shooter, weapon)
	
	assert_eq(valid.size(), 1, "Should be able to fire INTO planet")

func test_blocked_by_intermediate_planet():
	# Shooter at (0, -2, 2)
	# Target at (0, 2, -2)
	# Planet at (0,0,0) (Exact middle)
	_gm.planet_hexes.clear()
	_gm.planet_hexes.append(Vector3i(0, 0, 0))
	_shooter.grid_position = Vector3i(0, -2, 2)
	_target.grid_position = Vector3i(0, 2, -2)
	
	var weapon = _shooter.weapons[0]
	var valid = _gm._get_valid_targets_for_weapon(_shooter, weapon)
	
	assert_eq(valid.size(), 0, "Should be BLOCKED by intermediate planet")

func test_no_block_if_clear():
	# Shooter at (0, -2, 2)
	# Target at (0, -3, 3) (Adjacent)
	# Planet at (0,0,0) (Far away)
	_gm.planet_hexes.clear()
	_gm.planet_hexes.append(Vector3i(0, 0, 0))
	_shooter.grid_position = Vector3i(0, -2, 2)
	_target.grid_position = Vector3i(0, -3, 3)
	
	var weapon = _shooter.weapons[0]
	var valid = _gm._get_valid_targets_for_weapon(_shooter, weapon)
	
	assert_eq(valid.size(), 1, "Should NOT be blocked if clear")
