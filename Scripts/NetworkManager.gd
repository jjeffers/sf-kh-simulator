extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected
signal connection_failed
signal lobby_updated
signal game_started
signal all_players_loaded

const PORT = 7000
const MAX_CLIENTS = 2

# Player Info: { name: "Name", id: 1, version: "0.29.1.dev" }
var players = {}
var player_info = {
	"name": "Player",
	"version": ProjectSettings.get_setting("application/config/version", "unknown")
}
var loaded_players = {}

var game_setup_data = {} # { "scenario": "key", "host_side": 0 }
var disconnect_reason = ""

# Lobby Data
var lobby_data = {
	"scenario": "surprise_attack",
	"teams": {}, # peer_id: team_id (1=Attacker, 2=Defender, 0=Unassigned)
	"ship_assignments": {}, # ship_name: peer_id
	"player_numbers": {} # peer_id: number (1, 2, 3...)
}

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func join_game(address = "", port = PORT):
	if address.is_empty():
		address = "127.0.0.1"
	
	var url = "ws://%s:%d" % [address, port]
	print("Connecting to %s" % url)
	
	var peer = WebSocketMultiplayerPeer.new()
	peer.handshake_headers = PackedStringArray(["ngrok-skip-browser-warning: true"])
	var error = peer.create_client(url)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	
	return OK

func host_game(port = PORT):
	var peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_server(port)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	
	players[1] = player_info
	player_connected.emit(1, player_info)
	
	# Host is unassigned initially? Or Team 1?
	lobby_data["teams"][1] = 0
	lobby_data["player_numbers"][1] = 1 # Host is Player 1
	
	# Ensure clean state
	game_setup_data.clear()
	
	return OK

func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)
	# Send current lobby state to new player
	if multiplayer.is_server():
		lobby_data["teams"][id] = 0 # Default Unassigned
		
		# Assign Player Number
		var new_num = lobby_data["player_numbers"].size() + 1
		lobby_data["player_numbers"][id] = new_num
		print("Assigned Player %d to Peer %d" % [new_num, id])
		
		rpc("update_lobby_data", lobby_data)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	
	if multiplayer.is_server():
		# Verify Version matches the Server's Version
		var server_version = player_info.get("version", "unknown")
		var client_version = new_player_info.get("version", "unknown")
		
		if server_version != client_version:
			var msg = "Version Mismatch! Server: %s, Client: %s" % [server_version, client_version]
			print("[NetworkManager] Rejecting Peer %d - %s" % [new_player_id, msg])
			receive_rejection.rpc_id(new_player_id, msg)
			# Disconnect the peer; give it a tiny delay to ensure the RPC finishes first
			var timer = get_tree().create_timer(0.5)
			timer.timeout.connect(func():
				if multiplayer.multiplayer_peer:
					multiplayer.multiplayer_peer.disconnect_peer(new_player_id)
			)
			return

	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)

func _on_player_disconnected(id):
	players.erase(id)
	if multiplayer.is_server():
		lobby_data["teams"].erase(id)
		# Clear ship assignments for this player
		var ships_to_clear = []
		for s_name in lobby_data["ship_assignments"]:
			if lobby_data["ship_assignments"][s_name] == id:
				ships_to_clear.append(s_name)
		for s in ships_to_clear:
			lobby_data["ship_assignments"].erase(s)
			
		rpc("update_lobby_data", lobby_data)
		
	player_disconnected.emit(id)

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_connected_fail():
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	lobby_data["team_names"] = {} # Optional additional cleanup?
	lobby_data["teams"].clear()
	lobby_data["ship_assignments"].clear()
	game_setup_data.clear() # Prevent test data from leaking into game
	server_disconnected.emit()

# --- Lobby RPCs ---

@rpc("authority", "call_local", "reliable")
func receive_rejection(reason: String):
	print("[NetworkManager] Connection rejected: ", reason)
	disconnect_reason = reason

@rpc("any_peer", "call_local", "reliable")
func request_team_change(team_id: int):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	lobby_data["teams"][sender_id] = team_id
	
	# Clear ship assignments if switching teams?
	# Or keep them if valid? Safest to clear.
	var ships_to_clear = []
	for s_name in lobby_data["ship_assignments"]:
		if lobby_data["ship_assignments"][s_name] == sender_id:
			ships_to_clear.append(s_name)
	for s in ships_to_clear:
		lobby_data["ship_assignments"].erase(s)
		
	rpc("update_lobby_data", lobby_data)

@rpc("any_peer", "call_local", "reliable")
func request_ship_claim(ship_name: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Validate: Is ship free or owned by sender?
	var current_owner = lobby_data["ship_assignments"].get(ship_name, 0)
	if current_owner == 0 or current_owner == sender_id:
		lobby_data["ship_assignments"][ship_name] = sender_id
		rpc("update_lobby_data", lobby_data)

@rpc("authority", "call_local", "reliable")
func update_lobby_data(data: Dictionary):
	lobby_data = data
	lobby_updated.emit()

@rpc("authority", "reliable")
func sync_campaign_state(state_data: Dictionary):
	print("[NetworkManager] Received Campaign State Sync")
	var cm = CampaignManager
	var old_day = cm.current_day
		
	var old_encounters = cm.active_encounters.duplicate()
	cm.deserialize_state(state_data)
	
	var new_encounters = []
	for e in cm.active_encounters:
		if not old_encounters.has(e):
			new_encounters.append(e)
		cm.campaign_encounter_triggered.emit(e, [], [])
		
	if cm.current_day > old_day:
		cm.campaign_day_advanced.emit(cm.current_day)
	else:
		# Always emit an update trigger so the map redraws and auto-prompts fire
		cm.campaign_state_updated.emit()

@rpc("authority", "call_local", "reliable")
func start_game_rpc():
	print("[NetworkManager] Starting Game RPC received.")
	loaded_players.clear()
	game_started.emit()
	if lobby_data.get("game_mode", "") == "campaign" and lobby_data.get("scenario", "") != "campaign_encounter":
		get_tree().change_scene_to_file("res://Scenes/CampaignMap.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/Main.tscn")

@rpc("any_peer", "call_local", "reliable")
func client_loaded_scene():
	var sender_id = 1
	if multiplayer.has_multiplayer_peer():
		sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0: sender_id = (multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1)
	
	print("[NetworkManager] Player %d finished loading." % sender_id)
	loaded_players[sender_id] = true
	
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var all_ready = true
		for pid in players:
			if not loaded_players.has(pid):
				all_ready = false
				break
		if all_ready:
			print("[NetworkManager] All Players Ready!")
			all_players_loaded.emit()
