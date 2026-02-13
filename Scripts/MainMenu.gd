extends Control

@onready var address_input = $VBoxContainer/AddressInput
@onready var host_button = $VBoxContainer/HostButton
@onready var join_button = $VBoxContainer/JoinButton
@onready var status_label = $StatusLabel

func _ready():
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	NetworkManager.player_connected.connect(_on_connection_success)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	# Start Music
	MusicManager.play_music("res://Assets/Audio/Orbital Siege.mp3", -12.0, 2.0)
	
	_load_last_server()

func _on_host_pressed():
	_save_last_server(address_input.text)
	var data = _get_target_address_port()
	var port = data["port"]
	
	status_label.text = "Hosting on %d..." % port
	var err = NetworkManager.host_game(port)
	if err != OK:
		status_label.text = "Host Error: %s" % err
	else:
		_transition_to_lobby()

func _on_join_pressed():
	_save_last_server(address_input.text)
	var data = _get_target_address_port()
	var addr = data["address"]
	var port = data["port"]
	
	status_label.text = "Connecting to %s:%d..." % [addr, port]
	var err = NetworkManager.join_game(addr, port)
	if err != OK:
		status_label.text = "Join Error: %s" % err

func _on_connection_success(_id, _info):
	# If we successfully connected (as client), we go to lobby
	# For host, we already went to lobby?
	# Wait, host gets player_connected for self too.
	_transition_to_lobby()

func _on_connection_failed():
	status_label.text = "Connection Failed."

func _on_server_disconnected():
	status_label.text = "Server Disconnected."

func _transition_to_lobby():
	if not is_inside_tree(): return
	get_tree().change_scene_to_file("res://Scenes/Lobby.tscn")

func _get_target_address_port() -> Dictionary:
	var txt = address_input.text.strip_edges()
	var default_port = 7000
	var default_addr = "127.0.0.1"
	
	if txt.is_empty():
		return {"address": default_addr, "port": default_port}
	
	# Check for port ":PORT"
	var parts = txt.split(":")
	var addr = parts[0]
	var port = default_port
	
	if parts.size() > 1:
		var p_str = parts[1]
		if p_str.is_valid_int():
			port = p_str.to_int()
	
	if addr.is_empty():
		addr = default_addr
		
	return {"address": addr, "port": port}

const SETTINGS_FILE = "user://settings.cfg"

func _load_last_server():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		var addr = config.get_value("Network", "server_address", "")
		if not addr.is_empty():
			address_input.text = addr

func _save_last_server(addr: String):
	addr = addr.strip_edges()
	if addr.is_empty(): return
	
	var config = ConfigFile.new()
	config.load(SETTINGS_FILE) # Load existing to preserve other settings if any
	config.set_value("Network", "server_address", addr)
	config.save(SETTINGS_FILE)
