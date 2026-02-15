extends GutTest

var game_manager: GameManager
var ship: Ship
var station: Ship

func before_each():
	game_manager = GameManager.new()
	add_child_autofree(game_manager)
	
	# Setup needed for input handling
	game_manager.map_radius = 10
	game_manager._ready()
	
	# Create Station
	station = Ship.new()
	station.name = "Station"
	station.grid_position = Vector3i(0, 0, 0)
	station.ship_class = "Space Station"
	station.side_id = 1
	game_manager.ships.append(station)
	game_manager.add_child(station)
	
	# Create Docked Ship (Speed 0)
	ship = Ship.new()
	ship.name = "DockedShip"
	ship.grid_position = Vector3i(0, 0, 0) # Same hex
	ship.ship_class = "Frigate"
	ship.side_id = 1
	ship.facing = 0 # Pointing North-ish
	ship.speed = 0
	ship.is_docked = true
	ship.docked_host = station
	game_manager.ships.append(ship)
	game_manager.add_child(ship)
	
	# Select the ship
	game_manager.selected_ship = ship
	game_manager.start_speed = 0
	game_manager._reset_plotting_state()
	game_manager._spawn_ghost()

func test_docked_ship_can_move_in_any_direction():
	# Initial State: Facing 0
	assert_eq(game_manager.ghost_head_facing, 0, "Initial ghost facing should be 0")
	
	# Target Hex: Direction 3 (Opposite to 0) - "Behind" the ship
	var dir_vec = HexGrid.get_direction_vec(3)
	var target_hex = Vector3i(0, 0, 0) + dir_vec
	
	# 1. Simulate Mouse Hover (Facing Update)
	game_manager._handle_mouse_facing(target_hex)
	
	# VERIFY: Ghost should face 3
	assert_eq(game_manager.ghost_ship.facing, 3, "Ghost should visually rotate to face target")
	
	# CRITICAL CHECK: ghost_head_facing MUST match for input validation to work
	assert_eq(game_manager.ghost_head_facing, 3, "Ghost HEAD facing should update to match visual facing for stationary ship")
	
	# 2. Simulate Click (Move Input)
	game_manager._handle_movement_click(target_hex)
	
	# VERIFY: Path should have 1 step
	assert_eq(game_manager.current_path.size(), 1, "Move should be accepted")
	if game_manager.current_path.size() > 0:
		assert_eq(game_manager.current_path[0], target_hex, "Path should target the clicked hex")
