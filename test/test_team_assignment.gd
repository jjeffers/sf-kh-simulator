extends GutTest

var network_manager
var game_manager_script = load("res://Scripts/GameManager.gd")
var scenario_manager_script = load("res://Scripts/ScenarioManager.gd")
var game_manager

func before_all():
	# Mock NetworkManager if not present?
	# NetworkManager is Autoload. Access it.
	network_manager = get_node("/root/NetworkManager")

func after_each():
	if is_instance_valid(game_manager):
		game_manager.free()
	network_manager.lobby_data["teams"].clear()
	network_manager.game_setup_data.clear()

func test_host_assignment_surprise_attack_upf():
	# Simulate Surprise Attack
	# Side 0: Sathar. Side 1: UPF.
	# Lobby Team 2 -> Side 1 (UPF).
	# Host joins Team 2
	network_manager.lobby_data["scenario"] = "surprise_attack"
	network_manager.lobby_data["teams"][1] = 2
	
	# Force Server Role
	# We can't easily mock multiplayer.is_server() without partial doubles or running safe defaults.
	# GameManager checks matches multiplayer.get_unique_id() if server.
	# In GUT, we might be server?
	# We'll assume local logic works if we are Peer 1.
	
	game_manager = game_manager_script.new()
	add_child_autofree(game_manager)
	
	# _ready() runs.
	# It should set my_side_id based on NetworkManager.lobby_data["teams"][1] (which is 2)
	
	# Assert
	assert_eq(game_manager.my_side_id, 2, "Host should be assigned Side ID 2 (UPF)")

func test_host_assignment_last_stand_upf():
	# Simulate Last Stand
	# Side 0: UPF. Side 1: Sathar.
	# Lobby Team 1 -> Side 0 (UPF).
	# Host joins Team 1
	network_manager.lobby_data["scenario"] = "the_last_stand"
	network_manager.lobby_data["teams"][1] = 1
	
	game_manager = game_manager_script.new()
	add_child_autofree(game_manager)
	
	assert_eq(game_manager.my_side_id, 1, "Host should be assigned Side ID 1 (UPF)")

func test_host_fallback_assignment():
	# Simulate Host NOT in team (Default)
	network_manager.lobby_data["scenario"] = "surprise_attack"
	# network_manager.lobby_data["teams"].erase(1) 
	
	game_manager = game_manager_script.new()
	add_child_autofree(game_manager)
	
	# Should fall back to Side 2? No, code says:
	# if my_side_id == 0: if server: my_side_id = 1.
	# Side 1 is Sathar in Surprise Attack.
	
	assert_eq(game_manager.my_side_id, 1, "Host default fallback should be Side ID 1")
