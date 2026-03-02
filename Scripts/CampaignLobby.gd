extends Control

@onready var state_label = $MarginContainer/VBoxContainer/HBoxContainer/InfoPanel/VBoxContainer/StateLabel
@onready var upf_list = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/UPFPanel/List
@onready var sathar_list = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/SatharPanel/List
@onready var unassigned_list = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/UnassignedPanel/List

@onready var btn_join_upf = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/UPFPanel/JoinBtn
@onready var btn_join_sathar = $MarginContainer/VBoxContainer/HBoxContainer/ForcesPanel/HBox/SatharPanel/JoinBtn

@onready var start_btn = $MarginContainer/VBoxContainer/StartBtn
@onready var back_btn = $MarginContainer/VBoxContainer/BackBtn

func _ready():
	btn_join_upf.pressed.connect(_on_join_upf)
	btn_join_sathar.pressed.connect(_on_join_sathar)
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	NetworkManager.lobby_updated.connect(_refresh_ui)
	NetworkManager.player_connected.connect(_on_refresh)
	NetworkManager.player_disconnected.connect(_on_refresh)
	NetworkManager.server_disconnected.connect(_on_server_disconnect)
	
	_refresh_ui()

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
		if has_upf and has_sathar and unassigned_list.item_count == 0:
			start_btn.disabled = false
			start_btn.text = "Launch Campaign"
		else:
			start_btn.disabled = true
			start_btn.text = "Waiting for Players..."

func _on_join_upf():
	NetworkManager.rpc("request_team_change", 1)

func _on_join_sathar():
	NetworkManager.rpc("request_team_change", 2)

func _on_start_pressed():
	if multiplayer.is_server():
		NetworkManager.rpc("start_game_rpc")

func _on_back_pressed():
	# Disconnect and go back
	NetworkManager.lobby_data["teams"].erase(multiplayer.get_unique_id())
	NetworkManager.multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_server_disconnect():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
