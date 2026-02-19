extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")
var HexGrid = load("res://Scripts/HexGrid.gd")

var _gm = null
var _station = null
var _scout = null
var _attacker = null

func before_each():
	_gm = GameManager.new()
	add_child(_gm)
	_gm.test_force_online = true
	_gm.my_side_id = 1
	
	# Create Station (Dock Host)
	_station = Ship.new()
	_station.name = "Station"
	_station.side_id = 1
	_station.configure_space_station()
	_station.grid_position = Vector3i(0, 0, 0)
	_gm.ships.append(_station)
	_gm.add_child(_station)
	
	# Create Scout (Dock Guest)
	_scout = Ship.new()
	_scout.name = "Scout"
	_scout.side_id = 1
	_scout.configure_assault_scout()
	_scout.grid_position = Vector3i(0, 0, 0)
	_gm.ships.append(_scout)
	_gm.add_child(_scout)
	
	# Dock them
	_scout.dock_at(_station)
	assert_true(_scout.is_docked, "Scout should be docked")

	# Create Attacker (Enemy)
	_attacker = Ship.new()
	_attacker.name = "Attacker"
	_attacker.side_id = 2
	_attacker.configure_destroyer()
	_attacker.grid_position = Vector3i(2, -2, 0) # Just nearby
	_gm.ships.append(_attacker)
	_gm.add_child(_attacker)

func after_each():
	_gm.free()

func test_undock_and_target():
	# 1. Simulate Move Phase: Move Scout AWAY from Station
	# Station stays at (0,0,0) (or orbits, but let's keep it simple first)
	# Scout moves to (1, -1, 0)
	_gm.current_phase = _gm.Phase.MOVEMENT
	_gm.current_side_id = 1
	
	# Setup movement for Scout
	var path = [Vector3i(1, -1, 0)]
	var facing = 0
	
	# Manually trigger move execution logic
	# Use _on_commit_move? simpler: verify _handle_docking_states logic directly or via turn execution?
	# Let's try to invoke the full movement execution flow if possible, or simulate it.
	
	# Set new position directly to simulate "after move"
	_scout.grid_position = Vector3i(1, -1, 0)
	_scout.has_moved = true
	
	# Call _handle_docking_states which should trigger undocking
	_gm._handle_docking_states(_scout)
	
	# Assert Undocked
	assert_false(_scout.is_docked, "Scout should be undocked after moving away")
	assert_null(_scout.docked_host, "Scout docked_host should be null")
	
	# 2. Simulate Combat Phase: Attacker tries to target Scout
	_gm.current_phase = _gm.Phase.COMBAT
	_gm.current_side_id = 2 # Enemy turn to fire
	_gm.my_side_id = 2 # We are the attacker
	_gm.selected_ship = _attacker
	
	# Check targeting validity
	# Verify target check doesn't block it
	# We can call _check_for_valid_combat_targets? Or just check the logic block:
	# if s.is_docked and s.ship_class in ["Fighter", "Assault Scout"]: return
	
	# If assert_false(_scout.is_docked) passed, then the targeting Logic should pass too.
	# Let's verify via _get_valid_targets if it exists, or just logic.
	
	# Let's pretend we click on it
	_gm.combat_target = _scout
	
	# Check the condition manually (reproducing GameManager logic)
	var is_immune = _scout.is_docked and _scout.ship_class in ["Fighter", "Assault Scout"]
	assert_false(is_immune, "Scout should NOT be immune to targeting")
	
func test_undock_during_orbit():
	# Scenario: Station Orbits, Scout moves away.
	# Station moves to (0, -1, 1). Scout moves to (1, 0, -1).
	# Station Setup
	_station.grid_position = Vector3i(0, 0, 0)
	_station.orbit_direction = 1 # CW
	
	# Scout Setup
	_scout.grid_position = Vector3i(0, 0, 0)
	_scout.dock_at(_station)
	
	# Move Station (Orbit)
	var new_station_pos = Vector3i(1, -1, 0) # Just picking a neighbor
	_station.grid_position = new_station_pos
	
	# Move Scout (Away from new station pos)
	var new_scout_pos = Vector3i(-1, 1, 0)
	_scout.grid_position = new_scout_pos
	
	# Run docking check
	_gm._handle_docking_states(_scout)
	
	assert_false(_scout.is_docked, "Scout should undock if positions diverge")

func test_undock_sync():
	# Verify that undocking is synced via net_state
	# 1. Undock the ship (Server State)
	_scout.undock()
	assert_false(_scout.is_docked, "Server: Scout Undocked")
	
	# 2. Serialize State
	var data = _scout.get_net_state()
	
	# 3. Create a 'Client' representation (Ghost/Proxy)
	var client_scout = Ship.new()
	client_scout.name = "ClientScout"
	client_scout.is_docked = true # Simulate Client thinking it's still docked (Scenario Start)
	
	# 4. Apply State
	client_scout.apply_net_state(data)
	
	# 5. Assert Client is now Undocked
	assert_false(client_scout.is_docked, "Client: Scout should be undocked after sync")
	
	client_scout.free()

func test_undock_integrated_flow():
	# goal: Verify successful undock via execute_all_movement
	# Setup
	_station.grid_position = Vector3i(0, 0, 0)
	_scout.grid_position = Vector3i(0, 0, 0)
	_scout.dock_at(_station)
	assert_true(_scout.is_docked, "Setup: Scout docked")
	
	# Give Orders to move away
	var target_hex = Vector3i(1, -1, 0)
	_scout.planned_path.clear()
	_scout.planned_path.append(target_hex)
	_scout.planned_facing = 0
	_scout.has_orders = true
	_scout.has_moved = false
	
	# Mock GameManager state
	_gm.current_side_id = 1
	
	# Execute
	_gm.execute_all_movement()
	
	# Verify
	# 1. Scout has moved
	assert_eq(_scout.grid_position, target_hex, "Scout moved")
	
	# 2. Scout is Undocked (Result of _handle_docking_states being called in _apply_movement_plan)
	assert_false(_scout.is_docked, "Scout execution triggered undock")
