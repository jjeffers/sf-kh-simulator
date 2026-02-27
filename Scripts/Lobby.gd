extends Control

@onready var team1_list = $HBoxContainer/Team1Panel/VBoxContainer/List
@onready var team2_list = $HBoxContainer/Team2Panel/VBoxContainer/List
@onready var unassigned_list = $HBoxContainer/UnassignedPanel/VBoxContainer/List

@onready var btn_start = $ButtonStart
@onready var opt_scenario = $OptionScenario

var scenario_key = "surprise_attack" # Default

func _ready():
	# Connect to NetworkManager signals
	NetworkManager.lobby_updated.connect(_refresh_ui)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.player_connected.connect(_on_refresh)
	NetworkManager.player_disconnected.connect(_on_refresh)
	NetworkManager.server_disconnected.connect(_on_server_disconnect)
	
	# Initial Refresh
	if multiplayer.is_server():
		# Initialize scenario list
		var preselected = NetworkManager.lobby_data.get("scenario", "")
		opt_scenario.clear()
		var idx = 0
		var selected_idx = 0
		for key in ScenarioManager.SCENARIOS:
			if "test" in key:
				continue
				
			var s_name = ScenarioManager.SCENARIOS[key].get("name", key)
			opt_scenario.add_item(s_name, idx)
			# Store key as metadata if possible, or just use index mapping
			opt_scenario.set_item_metadata(idx, key)
			if key == preselected:
				selected_idx = idx
			idx += 1
		
		opt_scenario.select(selected_idx)
		NetworkManager.lobby_data["scenario"] = opt_scenario.get_item_metadata(selected_idx)
		
	_refresh_ui()
	
	if not multiplayer.is_server():
		btn_start.disabled = true
		opt_scenario.disabled = true
	else:
		btn_start.pressed.connect(_on_start_pressed)
		opt_scenario.item_selected.connect(_on_scenario_selected)

	# CLI Automation
	var args = OS.get_cmdline_args()
	var auto_start = false
	var wait_players = 1
	var auto_side_id = 0
	var auto_scenario = ""
	for i in range(args.size()):
		if args[i] == "--side" and i + 1 < args.size():
			auto_side_id = args[i + 1].to_int()
		if args[i] == "--scenario" and i + 1 < args.size():
			auto_scenario = args[i + 1]
		if args[i] == "--host" or args[i] == "--start":
			auto_start = true
		if args[i] == "--wait" and i + 1 < args.size():
			wait_players = args[i + 1].to_int()
			
	if auto_scenario != "" and multiplayer.is_server():
		# Force the server to select this scenario before auto-starting
		for idx in range(opt_scenario.item_count):
			if opt_scenario.get_item_metadata(idx) == auto_scenario:
				opt_scenario.select(idx)
				_on_scenario_selected(idx)
				break
			
	if auto_side_id > 0:
		var join_func = func():
			if auto_side_id == 1:
				_on_join_team_1_pressed()
			elif auto_side_id == 2:
				_on_join_team_2_pressed()
			
		if multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 0:
			join_func.call_deferred()
		else:
			# If joining as client, we need to wait for the connection success signal
			# NetworkManager emits player_connected for self when OK
			var wait_con = func(id, info): return
			wait_con = func(id, info):
				if id == multiplayer.get_unique_id():
					join_func.call_deferred()
			NetworkManager.player_connected.connect(wait_con)

	if auto_start and multiplayer.is_server():
		if NetworkManager.players.size() >= wait_players:
			# Wait slightly for team assignment RPCs to resolve locally
			get_tree().create_timer(0.5).timeout.connect(_on_start_pressed)
		else:
			var start_callable = func(id, info):
				if NetworkManager.players.size() >= wait_players:
					get_tree().create_timer(0.5).timeout.connect(_on_start_pressed)
			NetworkManager.player_connected.connect(start_callable)

func _on_refresh(_id = 0, _info = {}):
	_refresh_ui()

@onready var team1_label = $HBoxContainer/Team1Panel/VBoxContainer/Label
@onready var team2_label = $HBoxContainer/Team2Panel/VBoxContainer/Label

# ... (Existing lines)

func _refresh_ui():
	# Update Labels based on Scenario
	var scen_key = NetworkManager.lobby_data.get("scenario", "surprise_attack")
	var scen_data = ScenarioManager.get_scenario(scen_key)
	
	if not scen_data.is_empty():
		var sides = scen_data.get("sides", {})
		# Team 1 -> Side 0
		var side0 = sides.get(0, {})
		var role0 = side0.get("role", "Team 1")
		var name0 = side0.get("name", "Unknown")
		team1_label.text = "%s (%s)" % [name0, role0]
		
		# Team 2 -> Side 1
		var side1 = sides.get(1, {})
		var role1 = side1.get("role", "Team 2")
		var name1 = side1.get("name", "Unknown")
		team2_label.text = "%s (%s)" % [name1, role1]

	# Clear Lists
	team1_list.clear() # ItemList
	team2_list.clear()
	unassigned_list.clear()
	
	var players = NetworkManager.players
	var lobby = NetworkManager.lobby_data
	
	# Populate Player Lists
	for pid in players:
		var p_name = players[pid].get("name", "Unknown")
		var tid = lobby["teams"].get(pid, 0)
		
		# Add " (You)" to local player
		if pid == multiplayer.get_unique_id():
			p_name += " (You)"
			
		if tid == 1:
			team1_list.add_item(p_name)
		elif tid == 2:
			team2_list.add_item(p_name)
		else:
			unassigned_list.add_item(p_name)
			

func _on_start_pressed():
	print("[Lobby] Start Game Pressed!")
	MusicManager.fade_out(2.0)
	NetworkManager.rpc("start_game_rpc")

func _on_game_started():
	# Scene flow usually handled by NetworkManager or here?
	MusicManager.fade_out(2.0)
	pass # NetworkManager changes scene

func _on_scenario_selected(idx):
	var key = opt_scenario.get_item_metadata(idx)
	NetworkManager.lobby_data["scenario"] = key
	NetworkManager.rpc("update_lobby_data", NetworkManager.lobby_data)

func _on_join_team_1_pressed():
	NetworkManager.rpc("request_team_change", 1)

func _on_join_team_2_pressed():
	NetworkManager.rpc("request_team_change", 2)

func _on_server_disconnect():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
