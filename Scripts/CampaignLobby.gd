extends Control

@onready var state_label = $MarginContainer/VBoxContainer/HBoxContainer/InfoPanel/VBoxContainer/StateLabel
@onready var upf_list = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/UPFPanel/List
@onready var sathar_list = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/SatharPanel/List
@onready var unassigned_list = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/UnassignedPanel/List

@onready var btn_join_upf = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/UPFPanel/JoinBtn
@onready var btn_join_sathar = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/SatharPanel/JoinBtn

@onready var start_btn = $MarginContainer/VBoxContainer/StartBtn
@onready var back_btn = $MarginContainer/VBoxContainer/BackBtn

var auto_started = false

func _ready():
	MusicManager.play_music("res://Assets/Audio/Orbital Siege (Drums).mp3")
	btn_join_upf.pressed.connect(_on_join_upf)
	btn_join_sathar.pressed.connect(_on_join_sathar)
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	NetworkManager.lobby_updated.connect(_refresh_ui)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.player_connected.connect(_on_refresh)
	NetworkManager.player_disconnected.connect(_on_refresh)
	NetworkManager.server_disconnected.connect(_on_server_disconnect)
	
	_refresh_ui()

func _on_game_started():
	MusicManager.fade_out(2.0)
	pass # Scene change is handled by NetworkManager

func _on_refresh(_id = 0, _info = {}):
	_refresh_ui()

func _refresh_ui():
	# In Campaign mode, 1 = UPF, 2 = Sathar
	upf_list.clear()
	sathar_list.clear()
	unassigned_list.clear()
	
	var players = NetworkManager.players
	var lobby = NetworkManager.lobby_data
	
	var has_upf = false
	var has_sathar = false
	
	for pid in players:
		var p_name = players[pid].get("name", "Unknown")
		var tid = lobby["teams"].get(pid, 0)
		
		if pid == multiplayer.get_unique_id():
			p_name += " (You)"
			
		if tid == 1:
			upf_list.add_item(p_name)
			has_upf = true
		elif tid == 2:
			sathar_list.add_item(p_name)
			has_sathar = true
		else:
			unassigned_list.add_item(p_name)
			
	if not multiplayer.is_server():
		start_btn.disabled = true
		start_btn.text = "Waiting for Host..."
	else:
		if unassigned_list.item_count == 0:
			start_btn.disabled = false
			start_btn.text = "Launch Campaign"
		else:
			start_btn.disabled = true
			start_btn.text = "Assign Factions to Start"

	if lobby.get("is_saved_game", false):
		var day = lobby.get("current_day", 1)
		var f_destroyed = lobby.get("destroyed_fortresses", 0)
		var s_destroyed = lobby.get("destroyed_stations", 0)
		state_label.text = "Loaded Save: Day %d\nDestroyed Fortresses: %d\nDestroyed Stations: %d" % [day, f_destroyed, s_destroyed]
	else:
		state_label.text = "New Campaign\nDay 1"

	# Handle Auto-CLI actions
	var args = OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "--faction" and i + 1 < args.size():
			var fac = args[i+1].to_upper()
			var my_id = multiplayer.get_unique_id()
			var current_team = lobby["teams"].get(my_id, 0)
			
			if fac == "UPF" and current_team != 1:
				_on_join_upf()
			elif fac == "SATHAR" and current_team != 2:
				_on_join_sathar()

	if multiplayer.is_server() and not auto_started and not start_btn.disabled:
		if "--auto-start" in args:
			auto_started = true
			# Small delay to ensure client synced before scene switch
			get_tree().create_timer(1.0).timeout.connect(_on_start_pressed)

func _on_join_upf():
	NetworkManager.rpc("request_team_change", 1)

func _on_join_sathar():
	NetworkManager.rpc("request_team_change", 2)

func _on_start_pressed():
	if multiplayer.is_server():
		print("[CampaignLobby] Launch Campaign Pressed!")
		
		# INITIALIZE CAMPAIGN FOR SERVER (If not loading a save)
		var cm = CampaignManager
		if not NetworkManager.lobby_data.get("is_saved_game", false):
			cm.start_new_campaign()
		
		# BUILD FULL SYNC PAYLOAD
		var state_payload = cm.serialize_state()
			
		NetworkManager.rpc("sync_campaign_state", state_payload)
		NetworkManager.rpc("start_game_rpc")

func _on_back_pressed():
	# Disconnect and go back
	NetworkManager.lobby_data["teams"].erase(multiplayer.get_unique_id())
	NetworkManager.multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_server_disconnect():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
