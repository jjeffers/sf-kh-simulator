extends GutTest

var processor: AutoDeployProcessor
var ships: Array
var valid_hexes: Array[Vector3i]
var gm_mock: Node

# Mock a barebones GameManager
class MockGameManager extends Node:
    var ships: Array = []
    var planet_hexes: Array[Vector3i] = []
    var map_radius: int = 35
    var deployment_mines_placed: Array[Vector3i] = []
    var deployment_seekers_placed: Array[Vector3i] = []

func before_each():
    processor = AutoDeployProcessor.new()
    ships = []
    valid_hexes = [
        Vector3i(0, 0, 0), Vector3i(1, -1, 0), Vector3i(0, 1, -1),
        Vector3i(-1, 0, 1), Vector3i(2, -2, 0), Vector3i(0, 2, -2)
    ]
    gm_mock = MockGameManager.new()
    add_child_autofree(gm_mock)
    
func test_categorize_ships():
    var s1 = load("res://Scripts/Ship.gd").new()
    s1.ship_class = "Battleship"
    var s2 = load("res://Scripts/Ship.gd").new()
    s2.ship_class = "Assault Scout"
    var s3 = load("res://Scripts/Ship.gd").new()
    s3.ship_class = "Minelayer"
    
    ships = [s1, s2, s3]
    var roles = processor._categorize_ships(ships)
    
    assert_eq(roles[AutoDeployProcessor.ROLE_FRONT_LINE].size(), 1, "One front line ship")
    assert_eq(roles[AutoDeployProcessor.ROLE_ESCORT].size(), 1, "One escort")
    assert_eq(roles[AutoDeployProcessor.ROLE_SUPPORT].size(), 1, "One support")
    
func test_execute_placement_spacing_and_facing():
    var s1 = load("res://Scripts/Ship.gd").new()
    s1.ship_class = "Battleship"
    s1.side_id = 1
    
    var s2 = load("res://Scripts/Ship.gd").new()
    s2.ship_class = "Heavy Cruiser"
    s2.side_id = 1
    
    ships = [s1, s2]
    
    # Mock Enemy mass at (10, -10, 0)
    var enemy = load("res://Scripts/Ship.gd").new()
    enemy.side_id = 2
    enemy.is_deployed = true
    enemy.grid_position = Vector3i(10, -10, 0)
    gm_mock.ships.append(enemy)
    
    processor.execute(ships, valid_hexes, gm_mock)
    
    assert_true(s1.is_deployed, "Ship 1 is deployed")
    assert_true(s2.is_deployed, "Ship 2 is deployed")
    assert_ne(s1.grid_position, s2.grid_position, "Ships must not stack in same hex")
    
    # Since enemy is roughly +X, -Y, the ideal facing should be toward 0 or 1.
    assert_true(s1.facing == 0 or s1.facing == 1 or s1.facing == 5, "Should face generally towards enemy")

func test_space_station_speed_locks_and_orbit():
    var s1 = load("res://Scripts/Ship.gd").new()
    s1.ship_class = "Space Station"
    s1.side_id = 1
    
    gm_mock.planet_hexes.clear()
    gm_mock.planet_hexes.append(Vector3i(1, -1, 0)) # A planet inside valid_hexes
    
    ships = [s1]
    processor.execute(ships, valid_hexes, gm_mock)
    
    assert_eq(s1.speed, 0, "Space Station should have zero speed")
    assert_eq(s1.orbit_direction, 1, "Space Station defaults to CW orbit")
    
    # Needs to be adj (dist = 1) to (1, -1, 0)
    var dist = HexGrid.hex_distance(s1.grid_position, Vector3i(1, -1, 0))
    assert_eq(dist, 1, "Space station should strongly prefer orbiting the planet at dist 1")

func test_auto_deploy_collision_avoidance():
    var s1 = load("res://Scripts/Ship.gd").new()
    s1.ship_class = "Assault Scout" # Usually gets speed 10
    s1.side_id = 1
    s1.adf = 5
    
    # Force planet directly in front of the only valid deployment hex
    valid_hexes = [Vector3i.ZERO]
    gm_mock.planet_hexes.clear()
    gm_mock.planet_hexes.append(Vector3i(2, 0, -2)) # East (+X, 0, -Z) at Distance 2
    
    # Mock Enemy mass perfectly East (facing 0)
    var enemy = load("res://Scripts/Ship.gd").new()
    enemy.side_id = 2
    enemy.is_deployed = true
    enemy.grid_position = Vector3i(10, 0, -10) # East is +X, 0, -X
    gm_mock.ships.append(enemy)
    
    ships = [s1]
    processor.execute(ships, valid_hexes, gm_mock)
    
    assert_eq(s1.facing, 0, "Ship should be forced to face East toward the enemy")
    assert_true(s1.speed < 2, "Speed must be dropped heavily to safely avoid passing through the planet at dist 2. Act: " + str(s1.speed))
    
