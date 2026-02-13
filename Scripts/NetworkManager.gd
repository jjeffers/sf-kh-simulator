extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected
signal connection_failed
signal lobby_updated
signal game_started

const PORT = 7000
const MAX_CLIENTS = 2

# Player Info: { name: "Name", id: 1 }
var players = {}
var player_info = {"name": "Player"}

var game_setup_data = {} # { "scenario": "key", "host_side": 0 }

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
	var error = peer.create_client(url)
	if error:
		return error
	multiplayer.multiplayer_peer = peer

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

@rpc("authority", "call_local", "reliable")
func start_game_rpc():
	print("[NetworkManager] Starting Game RPC received. Changing Scene to Main.tscn...")
	game_started.emit()
	# Scene change handled by caller usually, but signal is good
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
