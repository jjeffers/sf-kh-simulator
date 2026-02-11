extends Control

@onready var container_controls = $CenterContainer/VBoxContainer
@onready var btn_host = $CenterContainer/VBoxContainer/HBoxContainer/BtnHost
@onready var btn_join = $CenterContainer/VBoxContainer/HBoxContainer/BtnJoin
@onready var line_ip = $CenterContainer/VBoxContainer/LineEditIP
@onready var status = $CenterContainer/VBoxContainer/StatusLabel

var line_port: LineEdit
var opt_scenario: OptionButton
var opt_side: OptionButton

func _ready():
	_setup_port_ui() # Add Port Field
	
	btn_host.pressed.connect(_on_host_pressed)
	btn_join.pressed.connect(_on_join_pressed)
	
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	# When connected or hosting, we can transition. 
	# For simplicity, let's verify connection first.
	NetworkManager.player_connected.connect(_on_player_connected)
	
	_setup_scenario_ui()

func _setup_port_ui():
	# Port Input
	var hbox_port = HBoxContainer.new()
	container_controls.add_child(hbox_port)
	container_controls.move_child(hbox_port, container_controls.get_children().find(line_ip) + 1)
	
	var lbl_port = Label.new()
	lbl_port.text = "Port:"
	hbox_port.add_child(lbl_port)
	
	line_port = LineEdit.new()
	line_port.text = "7000"
	line_port.placeholder_text = "7000"
	line_port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_port.add_child(line_port)

func _setup_scenario_ui():
	# Scenario Dropdown
	var lbl_scen = Label.new()
	lbl_scen.text = "Select Scenario:"
	container_controls.add_child(lbl_scen)
	container_controls.move_child(lbl_scen, 0)
	
	opt_scenario = OptionButton.new()
	container_controls.add_child(opt_scenario)
	container_controls.move_child(opt_scenario, 1)
	
	for key in ScenarioManager.SCENARIOS:
		var s = ScenarioManager.SCENARIOS[key]
		opt_scenario.add_item(s["name"])
		opt_scenario.set_item_metadata(opt_scenario.item_count - 1, key)
		
	# Side Dropdown (Default to first scenario sides)
	var lbl_side = Label.new()
	lbl_side.text = "Host Plays As:"
	container_controls.add_child(lbl_side)
	container_controls.move_child(lbl_side, 2)
	
	opt_side = OptionButton.new()
	container_controls.add_child(opt_side)
	container_controls.move_child(opt_side, 3)
	
	opt_scenario.item_selected.connect(_on_scenario_selected)
	_on_scenario_selected(0) # Init sides
	
func _on_scenario_selected(idx):
	opt_side.clear()
	var key = opt_scenario.get_item_metadata(idx)
	var scen = ScenarioManager.get_scenario(key)
	var sides = scen.get("sides", {})
	
	for side_idx in sides:
		var s_data = sides[side_idx]
		opt_side.add_item(s_data["name"])
		opt_side.set_item_metadata(opt_side.item_count - 1, side_idx)

func _on_host_pressed():
	status.text = "Hosting..."
	
	var port = 7000
	if line_port and line_port.text.is_valid_int():
		port = int(line_port.text)
		
	var err = NetworkManager.host_game(port)
	if err:
		status.text = "Error hosting: %s" % err
		return
		
	status.text = "Waiting for players on Port %d..." % port
	_disable_buttons()
	
func _on_join_pressed():
	status.text = "Joining..."
	var ip = line_ip.text
	if ip.is_empty(): ip = "127.0.0.1"
	
	var port = 7000
	if line_port and line_port.text.is_valid_int():
		port = int(line_port.text)
	
	var err = NetworkManager.join_game(ip, port)
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
			
			# Getting Selected Data
			var scen_key = opt_scenario.get_selected_metadata()
			var host_side = opt_side.get_selected_metadata()
			
			# RPC to start game with params
			var rng_seed = randi()
			_start_game.rpc(scen_key, host_side, rng_seed)
	else:
		if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			status.text = "Connected! Waiting for host..."

@rpc("call_local", "reliable")
func _start_game(scen_key: String, host_side: int, rng_seed: int):
	NetworkManager.game_setup_data = {
		"scenario": scen_key,
		"host_side": host_side,
		"seed": rng_seed
	}
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _disable_buttons():
	btn_host.disabled = true
	btn_join.disabled = true
	line_ip.editable = false
	if line_port: line_port.editable = false

func _enable_buttons():
	btn_host.disabled = false
	btn_join.disabled = false
	line_ip.editable = true
	if line_port: line_port.editable = true
