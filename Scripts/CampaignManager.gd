extends Node

signal campaign_day_advanced(new_day: int)
signal fleet_arrived(fleet: CampaignFleet, system_id: String)
signal campaign_encounter_triggered(system_id: String, upf_forces: Array, sathar_forces: Array)
signal open_encounter_dialog(system_id: String)
signal map_data_loaded()
signal turn_ready_changed(upf_ready: bool, sathar_ready: bool)
signal campaign_state_updated()

var map_data: Dictionary = {}
var systems: Dictionary = {} # system_name -> data
var routes: Array = []
var start_circles: Array = []
var _ship_names_data: Dictionary = {}
var _ship_sequential_counters: Dictionary = {}

var fleets: Array[CampaignFleet] = []
var current_day: int = 1

var upf_ready: bool = false
var sathar_ready: bool = false

var active_encounters: Array[String] = []
var encounter_attackers: Dictionary = {}

# Tracks destroyed stations for win/loss conditions
var destroyed_stations_count: int = 0
var destroyed_fortresses_count: int = 0

const TRANSIT_DAYS = 5
const SATHAR_REQUIREMENT_STATIONS = 12
const SATHAR_REQUIREMENT_FORTRESSES = 4

var INIT_UPF_FORTRESSES = ["Theseus", "K'aken-Kar", "Araks", "Prenglar"]
var INIT_UPF_ARMED_STATIONS = [
	"K'tsa-Kar", "Kizk-Kar", "Fromeltar", "Truane's Star", "Dramune", # Inner Reach
	"Dramune", # Outer Reach - NOTE: Dramune has two! Need to handle multiple stations per system or specific names.
	"Cassidine", # Rupert's Hole
	"Cassidine", # Triad
	"Gruna Garu", "Timeon"
]

var UPF_FORTRESSES: Array = []
var UPF_ARMED_STATIONS: Array = []


const UPF_STARSHIP_CONSTRUCTION_CENTERS = [
	"Araks", "Cassidine", "Dramune", "Fromeltar", 
	"Prenglar", "Theseus", "Truane's Star", "White Light"
]

const UPF_SCC_CAPACITIES = {
	"Araks": 20, "Cassidine": 50, "Dramune": 20, "Fromeltar": 40,
	"Prenglar": 70, "Theseus": 20, "Truane's Star": 10, "White Light": 10
}

var sathar_repair_queue: Array = []
var upf_scc_capacity_used: Dictionary = {}

func _ready():
	_load_map_data()
	_load_ship_names_db()

func _load_ship_names_db():
	var file = FileAccess.open("res://Data/ship_names.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			_ship_names_data = json.data
			print("[CampaignManager] Successfully loaded ship_names.json dictionary.")
		else:
			push_error("Failed to parse ship_names.json")
	else:
		push_error("Could not find res://Data/ship_names.json")

func _generate_ship_name(faction: String, ship_class: String) -> String:
	var faction_key = "UPF_Fleet" if faction.to_upper() == "UPF" else "Sathar_Fleet"
	var prefix = faction
	
	if not _ship_names_data.is_empty() and _ship_names_data.has(faction_key):
		var data_block = _ship_names_data[faction_key]
		prefix = data_block.get("Prefix", faction)
		var class_key = ship_class.replace(" ", "_") + "s" # e.g. "Assault Carrier" -> "Assault_Carriers"
		
		if data_block.has(class_key) and data_block[class_key].size() > 0:
			var name_list = data_block[class_key]
			var rnd_idx = randi() % name_list.size()
			var chosen: String = name_list[rnd_idx]
			name_list.remove_at(rnd_idx) # Exhaust this name so it can't be reused
			return "%s %s" % [prefix, chosen]
			
	# Fallback: <Prefix> <ship type> <ship number>
	if not _ship_sequential_counters.has(faction_key):
		_ship_sequential_counters[faction_key] = {}
		
	if not _ship_sequential_counters[faction_key].has(ship_class):
		_ship_sequential_counters[faction_key][ship_class] = 1
	else:
		_ship_sequential_counters[faction_key][ship_class] += 1
		
	var counter = _ship_sequential_counters[faction_key][ship_class]
	return "%s %s %d" % [prefix, ship_class, counter]

func _load_map_data():
	var file = FileAccess.open("res://Data/campaign_map.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			map_data = json.data
			if map_data.has("frontier_sector"):
				var sector = map_data["frontier_sector"]
				
				# Load systems
				for sys in sector.get("systems", []):
					systems[sys["name"]] = sys
				
				# Load routes
				routes = sector.get("navigation_routes", [])
				
				# Load start circles
				start_circles = sector.get("sathar_start_circles", [])
				
				emit_signal("map_data_loaded")
			else:
				push_error("Error: Invalid map data format, missing 'frontier_sector'")
		else:
			push_error("Error parsing campaign_map.json")
	else:
		push_error("Failed to open res://Data/campaign_map.json")

func start_new_campaign():
	current_day = 1
	fleets.clear()
	destroyed_stations_count = 0
	destroyed_fortresses_count = 0
	encounter_attackers.clear()
	
	UPF_FORTRESSES = INIT_UPF_FORTRESSES.duplicate()
	UPF_ARMED_STATIONS = INIT_UPF_ARMED_STATIONS.duplicate()
	
	_initialize_upf_forces()
	_initialize_sathar_forces()
	_initialize_ai_opponents()

func _initialize_upf_forces():
	# 1. Strike Force NOVA
	var nova_loc_roll = randi_range(1, 10)
	var nova_system = "Prenglar"
	if nova_loc_roll <= 3: nova_system = "Prenglar"
	elif nova_loc_roll == 4: nova_system = "Truane's Star"
	elif nova_loc_roll == 5: nova_system = "Dramune" # Inner Reach
	elif nova_loc_roll == 6: nova_system = "Fromeltar"
	elif nova_loc_roll == 7: nova_system = "Kizk-Kar"
	elif nova_loc_roll == 8: nova_system = "K'aken-Kar"
	elif nova_loc_roll == 9: nova_system = "White Light"
	else: nova_system = "K'tsa-Kar"
	
	var tf_nova = create_new_fleet("UPF", nova_system, "Strike Force NOVA")
	_add_ships_to_fleet(tf_nova, {"Battleship": 1, "Light Cruiser": 2})
	
	# 1b. Task Force Cassidine
	var tf_cassidine = create_new_fleet("UPF", "Cassidine", "Task Force Cassidine")
	_add_ships_to_fleet(tf_cassidine, {"Assault Carrier": 1, "Heavy Cruiser": 1, "Light Cruiser": 1, "Frigate": 2, "Assault Scout": 3, "Fighter": 6})
	
	# 1c. Task Force Prenglar
	var tf_prenglar = create_new_fleet("UPF", "Prenglar", "Task Force Prenglar")
	_add_ships_to_fleet(tf_prenglar, {"Battleship": 1, "Assault Carrier": 1, "Light Cruiser": 3, "Destroyer": 2, "Frigate": 3, "Assault Scout": 5, "Minelayer": 1})
	
	# 2. Planetary Militia Forces
	var militias = [
		{"sys": "White Light", "ships": {"Assault Scout": 3, "Frigate": 1}},
		{"sys": "Araks", "ships": {"Assault Scout": 3, "Frigate": 1}},
		{"sys": "K'aken-Kar", "ships": {"Assault Scout": 2}},
		{"sys": "Dramune", "ships": {"Assault Scout": 2, "Frigate": 2}}, # Outer Reach
		{"sys": "Fromeltar", "ships": {"Assault Scout": 3, "Frigate": 1}},
		{"sys": "Gruna Garu", "ships": {"Assault Scout": 2}},
		{"sys": "Dramune2", "ships": {"Assault Scout": 3, "Frigate": 1, "Destroyer": 1}, "actual_sys": "Dramune"}, # Inner Reach (Hack for uniqueness if we used system as fleet name suffix)
		{"sys": "Theseus", "ships": {"Assault Scout": 4, "Frigate": 1, "Destroyer": 1}},
		{"sys": "Truane's Star", "ships": {"Assault Scout": 3, "Frigate": 1}},
		{"sys": "Kizk-Kar", "ships": {"Assault Scout": 2}}
	]
	
	for m in militias:
		var target_sys = m.get("actual_sys", m["sys"])
		var mf = create_new_fleet("UPF", target_sys, "Militia " + m["sys"])
		_add_ships_to_fleet(mf, m["ships"])
		
	# 3. Non-Attached Ships (Randomly distributed among active UPF fleets)
	var unattached = [
		"Destroyer", "Destroyer"
	]
	
	var upf_fleets = []
	for f in fleets:
		if f.faction == "UPF": upf_fleets.append(f)
		
	for ship_type in unattached:
		if upf_fleets.size() > 0:
			var target = upf_fleets[randi() % upf_fleets.size()]
			_add_ships_to_fleet(target, {ship_type: 1})

func _initialize_ai_opponents():
			
	var has_upf_player = false
	var has_sathar_player = false
	var my_team = 0
	
	if has_node("/root/NetworkManager"):
		var nm = get_node("/root/NetworkManager")
		var lobby_data = nm.get("lobby_data")
		var teams = {}
		if lobby_data and typeof(lobby_data) == TYPE_DICTIONARY:
			teams = lobby_data.get("teams", {})
			
		for pid in teams.keys():
			if teams[pid] == 1: has_upf_player = true
			if teams[pid] == 2: has_sathar_player = true
		if multiplayer.has_multiplayer_peer():
			my_team = teams.get(multiplayer.get_unique_id(), 0)
			
	var is_local_bot = "--bot" in OS.get_cmdline_args()
	var spawn_upf = false
	var spawn_sathar = false
	
	if not has_upf_player:
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			spawn_upf = true
	elif my_team == 1 and is_local_bot:
		spawn_upf = true
		
	if not has_sathar_player:
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			spawn_sathar = true
	elif my_team == 2 and is_local_bot:
		spawn_sathar = true
	if spawn_upf:
		if not has_node("CampAI_UPF"):
			var ai = load("res://Scripts/CampaignComputerOpponent.gd").new("UPF")
			ai.name = "CampAI_UPF"
			add_child(ai)
			print("[CampaignManager] Attached CampAI_UPF to tree.")
			ConsoleManager.log_message("[color=yellow]Campaign AI initialized for UPF.[/color]")
	else:
		if has_node("CampAI_UPF"):
			var child = get_node("CampAI_UPF")
			child.queue_free()
			remove_child(child)
		
	if spawn_sathar:
		if not has_node("CampAI_Sathar"):
			var ai = load("res://Scripts/CampaignComputerOpponent.gd").new("Sathar")
			ai.name = "CampAI_Sathar"
			add_child(ai)
			print("[CampaignManager] Attached CampAI_Sathar to tree.")
			ConsoleManager.log_message("[color=yellow]Campaign AI initialized for Sathar.[/color]")
	else:
		if has_node("CampAI_Sathar"):
			var child = get_node("CampAI_Sathar")
			child.queue_free()
			remove_child(child)

func _initialize_sathar_forces():
	var sathar_pool = []
	var sathar_composition = {
		"Fighter": 10,
		"Frigate": 4,
		"Destroyer": 4,
		"Light Cruiser": 2,
		"Heavy Cruiser": 2,
		"Assault Carrier": 2
	}
	
	for type in sathar_composition.keys():
		for i in range(sathar_composition[type]):
			sathar_pool.append(type)
			
	sathar_pool.shuffle()
	
	var num_fleets = 2
	if start_circles.size() == 0: return # Fallback if map not loaded properly
	
	var chosen_circles = []
	var available_circles = start_circles.duplicate()
	available_circles.shuffle()
	
	for i in range(min(num_fleets, available_circles.size())):
		chosen_circles.append(available_circles[i])
	
	var sathar_fleets = []
	for i in range(chosen_circles.size()):
		var circle_name = "Start Circle " + str(int(chosen_circles[i].get("id", 0)))
		sathar_fleets.append(create_new_fleet("Sathar", circle_name, "Fleet " + str(i+1)))
		
	# Ensure each fleet gets at least 1 assault carrier
	var carriers_left = sathar_composition["Assault Carrier"]
	for i in range(num_fleets):
		if carriers_left > 0:
			_add_ships_to_fleet(sathar_fleets[i], {"Assault Carrier": 1})
			sathar_pool.erase("Assault Carrier")
			carriers_left -= 1
			
	var idx = 0
	for ship in sathar_pool:
		var target_fleet = sathar_fleets[idx % num_fleets]
		
		# Ensure no more than 8 fighters per assault carrier in a fleet
		if ship == "Fighter":
			var carrier_count = 0
			var fighter_count = 0
			for s in target_fleet.ships:
				if typeof(s) == TYPE_DICTIONARY:
					if s.get("class", "") == "Assault Carrier": carrier_count += 1
					if s.get("class", "") == "Fighter": fighter_count += 1
			
			if fighter_count >= carrier_count * 8:
				# This fleet is full of fighters relative to its carriers. Find another.
				var alternate_found = false
				for offset in range(1, num_fleets):
					var alt_idx = (idx + offset) % num_fleets
					var alt_fleet = sathar_fleets[alt_idx]
					var alt_carrier_count = 0
					var alt_fighter_count = 0
					for s in alt_fleet.ships:
						if typeof(s) == TYPE_DICTIONARY:
							if s.get("class", "") == "Assault Carrier": alt_carrier_count += 1
							if s.get("class", "") == "Fighter": alt_fighter_count += 1
					if alt_fighter_count < alt_carrier_count * 8:
						_add_ships_to_fleet(alt_fleet, {ship: 1})
						alternate_found = true
						break
				if not alternate_found:
					_add_ships_to_fleet(target_fleet, {ship: 1}) # Fallback, shouldn't happen with correct pool numbers
			else:
				_add_ships_to_fleet(target_fleet, {ship: 1})
		else:
			_add_ships_to_fleet(target_fleet, {ship: 1})
			
		idx += 1

func _add_ships_to_fleet(fleet: CampaignFleet, composition: Dictionary):
	var ShipScript = load("res://Scripts/Ship.gd")
	for ship_class in composition.keys():
		var count = composition[ship_class]
		for i in range(count):
			var designated_name = _generate_ship_name(fleet.faction, ship_class)
			
			var data = {
				"name": designated_name,
				"class": ship_class,
				"hull": 100
			}
			
			if ShipScript:
				var dummy = ShipScript.new()
				var method_name = "configure_" + ship_class.replace(" ", "_").to_lower()
				if dummy.has_method(method_name):
					dummy.call(method_name)
					data["hull"] = dummy.hull
					data["max_hull"] = dummy.max_hull
				dummy.free()
				
			fleet.ships.append(data)

func get_fleets_at_system(system_id: String) -> Array[CampaignFleet]:
	var result: Array[CampaignFleet] = []
	for f in fleets:
		if f.current_system_id == system_id and not f.is_moving():
			result.append(f)
	return result

func _get_systems_with_fleets() -> Dictionary:
	var cache = {}
	for f in fleets:
		if not f.is_moving():
			var sys = f.current_system_id
			if not cache.has(sys):
				cache[sys] = {"UPF": [], "Sathar": []}
			cache[sys][f.faction].append(f)
	return cache

func _get_connected_systems(sys_id: String) -> Array[String]:
	var connected: Array[String] = []
	for r in routes:
		if r["origin"] == sys_id: connected.append(r["destination"])
		elif r["destination"] == sys_id: connected.append(r["origin"])
		
	for sc in start_circles:
		var sc_name = "Start Circle " + str(int(sc.get("id", 0)))
		if sys_id == sc_name: connected.append(sc.get("connected_system", ""))
		elif sys_id == sc.get("connected_system", ""): connected.append(sc_name)
		
	return connected

func _check_upf_supply(start_system_id: String, occupation_cache: Dictionary) -> bool:
	if start_system_id in UPF_FORTRESSES: return true
	if start_system_id in UPF_ARMED_STATIONS: return true
	
	var visited = []
	var queue = [start_system_id]
	visited.append(start_system_id)
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		# Trace block: Has Sathar?
		if occupation_cache.has(current) and occupation_cache[current]["Sathar"].size() > 0:
			if current != start_system_id: # Current occupied system blocks traversing THROUGH it
				continue
		
		if current in UPF_FORTRESSES or current in UPF_ARMED_STATIONS:
			return true
			
		for n_sys in _get_connected_systems(current):
			if not visited.has(n_sys):
				visited.append(n_sys)
				queue.push_back(n_sys)
				
	return false

func _check_sathar_supply(start_system_id: String, occupation_cache: Dictionary) -> bool:
	if start_system_id.begins_with("Start Circle"): return true
	
	var visited = []
	var queue = [start_system_id]
	visited.append(start_system_id)
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		# Trace block: Has UPF fleets or stations?
		var has_upf = (occupation_cache.has(current) and occupation_cache[current]["UPF"].size() > 0)
		var has_station = (current in UPF_FORTRESSES or current in UPF_ARMED_STATIONS)
		
		if has_upf or has_station:
			if current != start_system_id: # Current occupied system blocks traversing THROUGH it
				continue
				
		if current.begins_with("Start Circle"):
			return true
			
		for n_sys in _get_connected_systems(current):
			if not visited.has(n_sys):
				visited.append(n_sys)
				queue.push_back(n_sys)
				
	return false

func are_systems_connected(sys_a: String, sys_b: String) -> bool:
	print("DEBUG are_systems_connected: Checking A=", sys_a, " B=", sys_b)
	for route in routes:
		if (route["origin"] == sys_a and route["destination"] == sys_b) or \
		   (route["origin"] == sys_b and route["destination"] == sys_a):
			print("DEBUG are_systems_connected: Found normal route match!")
			return true
	
	# Also check Sathar start circles
	for circle in start_circles:
		var circle_name = "Start Circle %d" % int(circle.get("id", 0))
		if (sys_a == circle_name and sys_b == circle["connected_system"]) or \
		   (sys_b == circle_name and sys_a == circle["connected_system"]):
			print("DEBUG are_systems_connected: Found START CIRCLE route match!")
			return true
			
	print("DEBUG are_systems_connected: NO MATCH. Returning false.")
	return false

func order_fleet_move(fleet: CampaignFleet, destination_id: String) -> bool:
	if fleet.is_moving():
		return false
	if not are_systems_connected(fleet.current_system_id, destination_id):
		return false
		
	# Enforce Sathar start circles rule: Only Sathar can move to/from them
	if destination_id.begins_with("Start Circle") and fleet.faction != "Sathar":
		return false
	if fleet.current_system_id.begins_with("Start Circle") and fleet.faction != "Sathar":
		return false
		
	if fleet.must_retreat:
		var occupants = _get_systems_with_fleets()
		var enemy_faction = "Sathar" if fleet.faction == "UPF" else "UPF"
		var has_enemy_fleets = (occupants.has(destination_id) and occupants[destination_id].get(enemy_faction, []).size() > 0)
		var has_enemy_station = (enemy_faction == "UPF" and (destination_id in UPF_FORTRESSES or destination_id in UPF_ARMED_STATIONS))
		if has_enemy_fleets or has_enemy_station:
			ConsoleManager.log_message("[color=red]Cannot retreat to a system occupied by enemy forces![/color]")
			return false
			
	var idx = fleets.find(fleet)
	if idx != -1:
		if multiplayer.has_multiplayer_peer():
			rpc_order_fleet_move.rpc(idx, destination_id)
		else:
			rpc_order_fleet_move(idx, destination_id)
		return true
	return false

@rpc("any_peer", "call_local", "reliable")
func rpc_order_fleet_move(fleet_idx: int, destination_id: String):
	if fleet_idx >= 0 and fleet_idx < fleets.size():
		fleets[fleet_idx].start_move(destination_id, TRANSIT_DAYS)
		if (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()) and has_node("/root/NetworkManager"):
			var nm = get_node("/root/NetworkManager")
			if multiplayer.has_multiplayer_peer():
				nm.sync_campaign_state.rpc(serialize_state())
			emit_signal("campaign_state_updated")

func cancel_fleet_move(fleet: CampaignFleet):
	var idx = fleets.find(fleet)
	if idx != -1:
		if multiplayer.has_multiplayer_peer():
			rpc_cancel_fleet_move.rpc(idx)
		else:
			rpc_cancel_fleet_move(idx)

@rpc("any_peer", "call_local", "reliable")
func rpc_cancel_fleet_move(fleet_idx: int):
	if fleet_idx >= 0 and fleet_idx < fleets.size():
		fleets[fleet_idx].cancel_move()
		if (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()) and has_node("/root/NetworkManager"):
			var nm = get_node("/root/NetworkManager")
			if multiplayer.has_multiplayer_peer():
				nm.sync_campaign_state.rpc(serialize_state())
			emit_signal("campaign_state_updated")

@rpc("any_peer", "call_local", "reliable")
func request_end_turn(faction: String):
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		# Validate that no fleet is stuck needing to retreat
		for f in fleets:
			if f.faction == faction and f.must_retreat and not f.is_moving():
				var msg = "[color=red]Cannot end turn. %s must plot a retreat to a safe system![/color]" % f.fleet_name
				if multiplayer.has_multiplayer_peer():
					ConsoleManager.log_message.rpc(msg)
				else:
					ConsoleManager.log_message(msg)
				return
				
		if faction == "UPF": upf_ready = true
		elif faction == "Sathar": sathar_ready = true
		
		# Broadcast updated readiness to all clients
		if multiplayer.has_multiplayer_peer():
			update_turn_ready.rpc(upf_ready, sathar_ready)
		else:
			update_turn_ready(upf_ready, sathar_ready)
		
		ConsoleManager.log_message("[color=yellow]End Turn Requested: %s. Status - UPF:%s, Sathar:%s[/color]" % [faction, str(upf_ready), str(sathar_ready)])
		
		if upf_ready and sathar_ready:
			end_turn()

@rpc("authority", "call_local", "reliable")
func update_turn_ready(upf: bool, sathar: bool):
	upf_ready = upf
	sathar_ready = sathar
	emit_signal("turn_ready_changed", upf_ready, sathar_ready)

@rpc("any_peer", "call_local", "reliable")
func rpc_open_encounter_dialog(sys_name: String):
	ConsoleManager.log_message("Network requested open encounter dialog for: " + sys_name)
	emit_signal("campaign_encounter_triggered", sys_name, [], []) # This signal is just for logging now
	# Actually we need the CampaignMap to open it. We can emit a specific signal
	emit_signal("open_encounter_dialog", sys_name)

var encounter_ready_state = {}

@rpc("any_peer", "call_local", "reliable")
func set_encounter_ready(sys_name: String, faction: String, is_ready: bool):
	if not encounter_ready_state.has(sys_name):
		encounter_ready_state[sys_name] = {"UPF": false, "Sathar": false}
	encounter_ready_state[sys_name][faction] = is_ready
	
	ConsoleManager.log_message("[color=yellow]Encounter %s: %s is Ready[/color]" % [sys_name, faction])
	
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var attacker = encounter_attackers.get(sys_name, "Both")
		var should_start = false
		
		# If both sides arrived at the same time, we require both to be ready.
		# Otherwise, the attacker controls when the battle starts.
		if attacker == "Both":
			should_start = encounter_ready_state[sys_name]["UPF"] and encounter_ready_state[sys_name]["Sathar"]
		else:
			# If the attacker is ready, we start it (the UI ensures only the attacker can click "Ready")
			should_start = encounter_ready_state[sys_name][attacker]
			
		if should_start:
			if has_node("/root/NetworkManager"):
				var nm = get_node("/root/NetworkManager")
				nm.lobby_data["scenario"] = "campaign_encounter"
				nm.lobby_data["encounter_system"] = sys_name
				if multiplayer.has_multiplayer_peer():
					nm.update_lobby_data.rpc(nm.lobby_data)
					nm.start_game_rpc.rpc()

func _resupply_fleet(fleet: CampaignFleet):
	# "Ships resupplied restock items such as torpedoes, rocket battery ammunition, assault rockets, mines, seekers. 
	# Assault carriers re-stock to replenish up to x20 fighter re-armings."
	var restocked = false
	for ship in fleet.ships:
		if ship.has("weapons"):
			for w in ship["weapons"]:
				var max_val = w.get("max_ammo", 0)
				if max_val > 0 and w.get("ammo", 0) < max_val:
					w["ammo"] = max_val
					restocked = true
					
		# Only Assault Carriers have rearm_capacity natively
		if ship.get("class", "") == "Assault Carrier" and ship.has("rearm_capacity"):
			# Pull baseline from a dummy construction
			var dummy = Ship.new()
			dummy.configure_assault_carrier()
			if ship["rearm_capacity"] < dummy.rearm_capacity:
				ship["rearm_capacity"] = dummy.rearm_capacity
				restocked = true
				
	if restocked:
		ConsoleManager.log_message("[color=aqua]Fleet %s has been resupplied.[/color]" % fleet.fleet_name)

func end_turn():
	ConsoleManager.log_message("[color=green]Both factions ready. Advancing from Day %d to Day %d[/color]" % [current_day, current_day + 1])
	current_day += 1
	upf_ready = false
	sathar_ready = false
	var arriving_fleets: Array[CampaignFleet] = []
	
	# Track pre-resolution locations to check supply viability BEFORE combat occurs
	var system_occupants = _get_systems_with_fleets()
	
	var was_moving_flags = {}
	for fleet in fleets:
		was_moving_flags[fleet] = fleet.is_moving()
		if fleet.advance_day():
			arriving_fleets.append(fleet)
			emit_signal("fleet_arrived", fleet, fleet.current_system_id)
			was_moving_flags[fleet] = true
			
	_enforce_fighter_survival()
	_check_for_encounters(arriving_fleets)
			
	for fleet in fleets:
		# Rearm check: "Ships in supply will re-arm if they spend an entire day without moving or engaging in combat."
		if not was_moving_flags[fleet]:
			var can_supply = false
			if active_encounters.has(fleet.current_system_id):
				can_supply = false # Blocked by combat breaking out this turn
			elif fleet.faction == "UPF":
				can_supply = _check_upf_supply(fleet.current_system_id, system_occupants)
			else:
				can_supply = _check_sathar_supply(fleet.current_system_id, system_occupants)
				
			if can_supply:
				_resupply_fleet(fleet)
				
	# Reset UPF SCC Daily Capacity
	upf_scc_capacity_used.clear()
	
	# Process Sathar 6-Day Repair Queue
	for i in range(sathar_repair_queue.size() - 1, -1, -1):
		var repair_job = sathar_repair_queue[i]
		repair_job["days_remaining"] -= 1
		
		if repair_job["days_remaining"] <= 0:
			var s_dict = repair_job["ship"]
			var sys_id = repair_job["system_id"]
			
			ConsoleManager.log_message("[color=green]Sathar SCC at %s has completed repairs on %s.[/color]" % [sys_id, s_dict.get("name", "Ship")])
			
			# Spin up dummy ship to copy clean dictionary states
			var dummy = load("res://Scripts/Ship.gd").new()
			var cls = s_dict.get("class", "Fighter")
			match cls:
				"Fighter": dummy.configure_fighter()
				"Assault Scout": dummy.configure_assault_scout()
				"Frigate": dummy.configure_frigate()
				"Minelayer": dummy.configure_minelayer()
				"Destroyer": dummy.configure_destroyer()
				"Light Cruiser": dummy.configure_light_cruiser()
				"Heavy Cruiser": dummy.configure_heavy_cruiser()
				"Battleship": dummy.configure_battleship()
				"Assault Carrier": dummy.configure_assault_carrier()
				
			s_dict["hull"] = dummy.max_hull
			s_dict["max_hull"] = dummy.max_hull
			s_dict["current_adf_modifier"] = 0
			s_dict["unrepairable_adf_modifier"] = 0
			s_dict["current_mr_modifier"] = 0
			s_dict["unrepairable_mr_modifier"] = 0
			s_dict["has_electrical_fire"] = false
			s_dict["has_disastrous_fire"] = false
			s_dict["unrepairable_electrical_fire"] = false
			s_dict["unrepairable_disastrous_fire"] = false
			s_dict["ccs_damaged"] = false
			s_dict["unrepairable_ccs"] = false
			s_dict["icm_max"] = dummy.base_icm_max
			s_dict["icm_current"] = dummy.base_icm_max
			s_dict["unrepairable_icm"] = false
			s_dict["ms_max"] = dummy.base_ms_max
			s_dict["ms_current"] = dummy.base_ms_max
			s_dict["unrepairable_ms"] = false
			s_dict["unrepairable_hull"] = false
			
			if s_dict.has("weapons"):
				for i_w in range(min(dummy.weapons.size(), s_dict["weapons"].size())):
					var orig_w = dummy.weapons[i_w]
					var cur_w = s_dict["weapons"][i_w]
					cur_w["is_crippled"] = false
					cur_w["unrepairable"] = false
					cur_w["ammo"] = orig_w.get("max_ammo", 0)
					cur_w["max_ammo"] = orig_w.get("max_ammo", 0)
			
			dummy.free()
			
			# Append to an existing stationary Sathar fleet, or create a new one.
			var placed = false
			for f in fleets:
				if f.faction == "Sathar" and f.current_system_id == sys_id and not f.is_moving():
					f.ships.append(s_dict)
					placed = true
					break
					
			if not placed:
				var new_f = create_new_fleet("Sathar", sys_id, "Repaired Strike Group")
				new_f.ships.append(s_dict)
				
			sathar_repair_queue.remove_at(i)
			
	emit_signal("campaign_day_advanced", current_day)
	
	# After processing the turn, broadcast the new state and readiness
	if (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()) and has_node("/root/NetworkManager"):
		var nm = get_node("/root/NetworkManager")
		if multiplayer.has_multiplayer_peer():
			nm.sync_campaign_state.rpc(serialize_state())
			update_turn_ready.rpc(upf_ready, sathar_ready)
		else:
			update_turn_ready(upf_ready, sathar_ready)

func serialize_state() -> Dictionary:
	var state = {
		"current_day": current_day,
		"destroyed_stations": destroyed_stations_count,
		"destroyed_fortresses": destroyed_fortresses_count,
		"active_encounters": active_encounters,
		"encounter_attackers": encounter_attackers,
		"upf_fortresses": UPF_FORTRESSES,
		"upf_armed_stations": UPF_ARMED_STATIONS,
		"upf_scc_capacity_used": upf_scc_capacity_used,
		"sathar_repair_queue": sathar_repair_queue,
		"fleets": []
	}
	for f in fleets:
		state["fleets"].append(f.serialize())
	return state

func _enforce_fighter_survival():
	# Fighters in a system without a friendly assault carrier or space station are destroyed.
	var systems_with_forces = {}
	for f in fleets:
		if f.is_moving(): continue # Fighters moving with a fleet are assumed to be with their carrier
		var sys = f.current_system_id
		if not systems_with_forces.has(sys):
			systems_with_forces[sys] = {"UPF": [], "Sathar": []}
		systems_with_forces[sys][f.faction].append(f)
		
	for sys in systems_with_forces:
		for faction in ["UPF", "Sathar"]:
			var my_fleets = systems_with_forces[sys][faction]
			if my_fleets.is_empty(): continue
			
			var carrier_count = 0
			var station_present = false
			var fighters_list = []
			
			if faction == "UPF" and (sys in UPF_FORTRESSES or sys in UPF_ARMED_STATIONS):
				station_present = true
				
			for f in my_fleets:
				for ship in f.ships:
					var s_class = ship.get("class", "") if typeof(ship) == TYPE_DICTIONARY else ship.ship_class
					if s_class == "Assault Carrier":
						carrier_count += 1
					elif "Station" in s_class:
						station_present = true
					elif s_class == "Fighter":
						fighters_list.append({"fleet": f, "ship": ship})
						
			if not station_present:
				var supported_fighters = carrier_count * 8
				var excess = fighters_list.size() - supported_fighters
				if excess > 0:
					for i in range(excess):
						var to_destroy = fighters_list[i] # Just take the first 'excess' ones
						var df = to_destroy["fleet"]
						var ds = to_destroy["ship"]
						var ds_name = ds.get("name", "Fighter") if typeof(ds) == TYPE_DICTIONARY else ds.name
						ConsoleManager.log_message("[color=red]Unsupported Fighter Destroyed in %s: %s[/color]" % [sys, ds_name])
						df.remove_ship(ds)

func _check_for_encounters(arriving_fleets: Array[CampaignFleet] = []):
	active_encounters.clear()
	encounter_attackers.clear()
	# Group all stationary fleets by system
	var systems_with_fleets = {}
	for f in fleets:
		if not f.is_moving():
			var sys = f.current_system_id
			if not systems_with_fleets.has(sys):
				systems_with_fleets[sys] = {"UPF": [], "Sathar": []}
			systems_with_fleets[sys][f.faction].append(f)
			
	# Trigger encounters where both sides are present
	for sys in systems_with_fleets:
		var upf_forces = systems_with_fleets[sys].get("UPF", [])
		var sathar_forces = systems_with_fleets[sys].get("Sathar", [])
		
		# Encounter triggers if fleets co-exist OR if Sathar arrives at a UPF system with a station
		var has_station = (sys in UPF_FORTRESSES or sys in UPF_ARMED_STATIONS)
		
		if sathar_forces.size() > 0 and (upf_forces.size() > 0 or has_station):
			active_encounters.append(sys)
			
			var attacker = "Both"
			var upf_arrived = false
			var sathar_arrived = false
			for f in arriving_fleets:
				if f.current_system_id == sys:
					if f.faction == "UPF": upf_arrived = true
					elif f.faction == "Sathar": sathar_arrived = true
					
			if upf_arrived and not sathar_arrived: attacker = "UPF"
			elif sathar_arrived and not upf_arrived: attacker = "Sathar"
			elif not upf_arrived and not sathar_arrived:
				# This shouldn't normally happen (combat didn't resolve last turn),
				# but default to Both to ensure both must be ready.
				pass
				
			encounter_attackers[sys] = attacker
			
			emit_signal("campaign_encounter_triggered", sys, upf_forces, sathar_forces)

func create_new_fleet(faction: String, system_id: String, fleet_name: String) -> CampaignFleet:
	var new_fleet = CampaignFleet.new(fleet_name, faction, system_id)
	fleets.append(new_fleet)
	return new_fleet

@rpc("any_peer", "call_local", "reliable")
func rpc_rename_fleet(fleet_idx: int, new_name: String):
	if fleet_idx >= 0 and fleet_idx < fleets.size():
		fleets[fleet_idx].fleet_name = new_name
		emit_signal("campaign_state_updated")
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and has_node("/root/NetworkManager"):
			var nm = get_node("/root/NetworkManager")
			nm.sync_campaign_state.rpc(serialize_state())

@rpc("any_peer", "call_local", "reliable")
func rpc_rename_ship(fleet_idx: int, ship_idx: int, new_name: String):
	if fleet_idx >= 0 and fleet_idx < fleets.size():
		if ship_idx >= 0 and ship_idx < fleets[fleet_idx].ships.size():
			fleets[fleet_idx].ships[ship_idx]["name"] = new_name
			emit_signal("campaign_state_updated")
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and has_node("/root/NetworkManager"):
				var nm = get_node("/root/NetworkManager")
				nm.sync_campaign_state.rpc(serialize_state())

@rpc("any_peer", "call_local", "reliable")
func rpc_transfer_ships(source_fleet_idx: int, target_fleet_idx: int, ship_indices: Array):
	if source_fleet_idx >= 0 and source_fleet_idx < fleets.size() and target_fleet_idx >= 0 and target_fleet_idx < fleets.size():
		var source = fleets[source_fleet_idx]
		var target = fleets[target_fleet_idx]
		
		# Sort descending to safely remove from array without shifting subsequent indices
		ship_indices.sort()
		ship_indices.reverse()
		
		var ships_to_move = []
		for idx in ship_indices:
			if idx >= 0 and idx < source.ships.size():
				ships_to_move.append(source.ships[idx])
				source.ships.remove_at(idx)
				
		for ship in ships_to_move:
			target.ships.append(ship)
			
		if source.ships.is_empty():
			fleets.remove_at(source_fleet_idx)
			
		emit_signal("campaign_state_updated")
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and has_node("/root/NetworkManager"):
			var nm = get_node("/root/NetworkManager")
			nm.sync_campaign_state.rpc(serialize_state())

@rpc("any_peer", "call_local", "reliable")
func rpc_create_fleet_from_transfer(source_fleet_idx: int, ship_indices: Array, new_fleet_name: String):
	if source_fleet_idx >= 0 and source_fleet_idx < fleets.size():
		var source = fleets[source_fleet_idx]
		
		ship_indices.sort()
		ship_indices.reverse()
		
		var ships_to_move = []
		for idx in ship_indices:
			if idx >= 0 and idx < source.ships.size():
				ships_to_move.append(source.ships[idx])
				source.ships.remove_at(idx)
				
		if ships_to_move.size() > 0:
			var new_fleet = create_new_fleet(source.faction, source.current_system_id, new_fleet_name)
			new_fleet.ships = ships_to_move
			
		if source.ships.is_empty():
			fleets.remove_at(source_fleet_idx)
			
		emit_signal("campaign_state_updated")
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and has_node("/root/NetworkManager"):
			var nm = get_node("/root/NetworkManager")
			nm.sync_campaign_state.rpc(serialize_state())

func remove_fleet(fleet: CampaignFleet):
	fleets.erase(fleet)

func check_victory_conditions() -> int:
	# Returns 0 for ongoing, 1 for Sathar win, 2 for UPF win
	if destroyed_stations_count >= SATHAR_REQUIREMENT_STATIONS and destroyed_fortresses_count >= SATHAR_REQUIREMENT_FORTRESSES:
		return 1 # Sathar Victory
	
	# Check UPF victory (Sathar fleets depleted)
	var active_sathar = false
	for f in fleets:
		if f.faction == "Sathar" and f.get_ship_count() > 0:
			active_sathar = true
			break
			
	if not active_sathar:
		return 2 # UPF Victory
		
	return 0 # Ongoing
func save_campaign(file_path: String = "user://campaign_save.json") -> bool:
	var state = serialize_state()
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json = JSON.stringify(state, "\t")
		file.store_string(json)
		file.close()
		return true
	return false

func load_campaign(file_path: String = "user://campaign_save.json") -> bool:
	if not FileAccess.file_exists(file_path):
		return false
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			deserialize_state(json.data)
			file.close()
			
			if (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()) and has_node("/root/NetworkManager"):
				var nm = get_node("/root/NetworkManager")
				if multiplayer.has_multiplayer_peer():
					nm.sync_campaign_state.rpc(json.data)
			return true
	return false

func deserialize_state(state_data: Dictionary):
	current_day = state_data.get("current_day", 1)
	destroyed_stations_count = state_data.get("destroyed_stations", 0)
	destroyed_fortresses_count = state_data.get("destroyed_fortresses", 0)
	
	# Load station existence arrays or fallback to full initial if not present (backwards compatibility)
	var saved_fortresses = state_data.get("upf_fortresses", [])
	if saved_fortresses.size() > 0 or state_data.has("upf_fortresses"):
		UPF_FORTRESSES = saved_fortresses
	else:
		UPF_FORTRESSES = INIT_UPF_FORTRESSES.duplicate()
		
	var saved_stations = state_data.get("upf_armed_stations", [])
	if saved_stations.size() > 0 or state_data.has("upf_armed_stations"):
		UPF_ARMED_STATIONS = saved_stations
	else:
		UPF_ARMED_STATIONS = INIT_UPF_ARMED_STATIONS.duplicate()


	if state_data.has("upf_scc_capacity_used"):
		upf_scc_capacity_used = state_data["upf_scc_capacity_used"].duplicate(true)
	else:
		upf_scc_capacity_used.clear()
		
	if state_data.has("sathar_repair_queue"):
		sathar_repair_queue = state_data["sathar_repair_queue"].duplicate(true)
	else:
		sathar_repair_queue.clear()
	
	active_encounters.clear()
	for e in state_data.get("active_encounters", []):
		active_encounters.append(e)
		
	encounter_attackers.clear()
	var ea_data = state_data.get("encounter_attackers", {})
	for k in ea_data.keys():
		encounter_attackers[k] = ea_data[k]
		
	fleets.clear()
	var fleets_arr = state_data.get("fleets", [])
	for f_data in fleets_arr:
		var fleet = CampaignFleet.new("", "", "")
		fleet.deserialize(f_data)
		fleets.append(fleet)
		
	_initialize_ai_opponents()
