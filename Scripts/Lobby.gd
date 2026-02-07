extends Control

@onready var btn_host = $CenterContainer/VBoxContainer/HBoxContainer/BtnHost
@onready var btn_join = $CenterContainer/VBoxContainer/HBoxContainer/BtnJoin
@onready var line_ip = $CenterContainer/VBoxContainer/LineEditIP
@onready var status = $CenterContainer/VBoxContainer/StatusLabel

func _ready():
	btn_host.pressed.connect(_on_host_pressed)
	btn_join.pressed.connect(_on_join_pressed)
	
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	# When connected or hosting, we can transition. 
	# For simplicity, let's verify connection first.
	NetworkManager.player_connected.connect(_on_player_connected)

func _on_host_pressed():
	status.text = "Hosting..."
	var err = NetworkManager.host_game()
	if err:
		status.text = "Error hosting: %s" % err
		return
		
	status.text = "Waiting for players..."
	_disable_buttons()
	
func _on_join_pressed():
	status.text = "Joining..."
	var ip = line_ip.text
	if ip.is_empty(): ip = "127.0.0.1"
	
	var err = NetworkManager.join_game(ip)
	if err:
		status.text = "Error joining: %s" % err
		return
	
	_disable_buttons()

func _on_connection_failed():
	status.text = "Connection Failed"
	_enable_buttons()

func _on_server_disconnected():
	status.text = "Server Disconnected"
	_enable_buttons()

func _on_player_connected(id, info):
	# In this simple example, we start immediately if we are the host and have 2 players?
	# Or just transition everyone when ready?
	# For now, let's just transition to Main scene immediately upon connection success for self?
	# Better: Host controls start.
	
	status.text = "Player Connected: %s" % id
	
	# Transition logic:
	# If we are just testing, let's say ANY successful connection moves to Game?
	# No, Host needs to wait. Client needs to wait for Host.
	
	if multiplayer.is_server():
		if NetworkManager.players.size() >= 2:
			status.text = "Starting Game..."
			# Use RPC to tell everyone to switch?
			# Or just load scene? (Godot Sync Loader)
			# Simpler: Main scene load.
			_start_game.rpc()
	else:
		if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			status.text = "Connected! Waiting for host..."

@rpc("call_local", "reliable")
func _start_game():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _disable_buttons():
	btn_host.disabled = true
	btn_join.disabled = true
	line_ip.editable = false

func _enable_buttons():
	btn_host.disabled = false
	btn_join.disabled = false
	line_ip.editable = true
