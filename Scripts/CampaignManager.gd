extends Node

signal campaign_day_advanced(new_day: int)
signal fleet_arrived(fleet: CampaignFleet, system_id: String)
signal campaign_encounter_triggered(system_id: String, upf_fleets: Array, sathar_fleets: Array)
signal map_data_loaded()

var map_data: Dictionary = {}
var systems: Dictionary = {} # system_name -> data
var routes: Array = []
var start_circles: Array = []

var fleets: Array[CampaignFleet] = []
var current_day: int = 1

# Tracks destroyed stations for win/loss conditions
var destroyed_stations_count: int = 0
var destroyed_fortresses_count: int = 0

const TRANSIT_DAYS = 5
const SATHAR_REQUIREMENT_STATIONS = 12
const SATHAR_REQUIREMENT_FORTRESSES = 4

const UPF_FORTRESSES = ["Theseus", "K'aken-Kar", "Araks", "Prenglar"]
const UPF_ARMED_STATIONS = [
	"K'tsa-Kar", "Kizk-Kar", "Fromeltar", "Truane's Star", "Dramune", # Inner Reach
	"Dramune", # Outer Reach - NOTE: Dramune has two! Need to handle multiple stations per system or specific names.
	"Cassidine", # Rupert's Hole
	"Cassidine", # Triad
	"Gruna Garu", "Timeon"
]

func _ready():
	_load_map_data()

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
	
	_initialize_upf_forces()
	_initialize_sathar_forces()

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
	_add_ships_to_fleet(tf_nova, {"Battleship": 1, "Assault Carrier": 1, "Light Cruiser": 2, "Destroyer": 1, "Frigate": 2, "Assault Scout": 3, "Fighter": 6})
	
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
		"Fighter", "Fighter", "Fighter", "Fighter", 
		"Assault Scout", "Assault Scout", "Assault Scout", 
		"Minelayer", 
		"Destroyer", "Destroyer", 
		"Light Cruiser", "Light Cruiser"
	]
	
	var upf_fleets = []
	for f in fleets:
		if f.faction == "UPF": upf_fleets.append(f)
		
	for ship_type in unattached:
		if upf_fleets.size() > 0:
			var target = upf_fleets[randi() % upf_fleets.size()]
			_add_ships_to_fleet(target, {ship_type: 1})

func _initialize_sathar_forces():
	var sathar_pool = []
	var sathar_composition = {
		"Fighter": 25,
		"Frigate": 8,
		"Destroyer": 2,
		"Light Cruiser": 3,
		"Battleship": 1,
		"Assault Carrier": 1
	}
	
	for type in sathar_composition.keys():
		for i in range(sathar_composition[type]):
			sathar_pool.append(type)
			
	sathar_pool.shuffle()
	
	var num_fleets = 3
	if start_circles.size() == 0: return # Fallback if map not loaded properly
	
	var chosen_circles = []
	var available_circles = start_circles.duplicate()
	available_circles.shuffle()
	
	for i in range(min(num_fleets, available_circles.size())):
		chosen_circles.append(available_circles[i])
	
	var sathar_fleets = []
	for i in range(chosen_circles.size()):
		var circle_name = "Start Circle " + str(chosen_circles[i]["id"])
		sathar_fleets.append(create_new_fleet("Sathar", circle_name, "Sathar Fleet " + str(i+1)))
		
	var idx = 0
	for ship in sathar_pool:
		var target_fleet = sathar_fleets[idx % num_fleets]
		_add_ships_to_fleet(target_fleet, {ship: 1})
		idx += 1

func _add_ships_to_fleet(fleet: CampaignFleet, composition: Dictionary):
	for ship_class in composition.keys():
		var count = composition[ship_class]
		for i in range(count):
			var data = {
				"name": "%s %s %d" % [fleet.faction, ship_class, fleet.ships.size() + 1],
				"class": ship_class,
				"hull": 100 # Percentage or full max hull logic can be applied later when moving to tactical
			}
			fleet.ships.append(data)

func get_fleets_at_system(system_id: String) -> Array[CampaignFleet]:
	var result: Array[CampaignFleet] = []
	for f in fleets:
		if f.current_system_id == system_id and not f.is_moving():
			result.append(f)
	return result

func are_systems_connected(sys_a: String, sys_b: String) -> bool:
	for route in routes:
		if (route["origin"] == sys_a and route["destination"] == sys_b) or \
		   (route["origin"] == sys_b and route["destination"] == sys_a):
			return true
	
	# Also check Sathar start circles
	for circle in start_circles:
		var circle_name = "Start Circle %d" % circle["id"]
		if (sys_a == circle_name and sys_b == circle["connected_system"]) or \
		   (sys_b == circle_name and sys_a == circle["connected_system"]):
			return true
			
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
		
	fleet.start_move(destination_id, TRANSIT_DAYS)
	return true

func end_turn():
	current_day += 1
	var arriving_fleets: Array[CampaignFleet] = []
	
	for fleet in fleets:
		if fleet.advance_day():
			arriving_fleets.append(fleet)
			emit_signal("fleet_arrived", fleet, fleet.current_system_id)
			
	emit_signal("campaign_day_advanced", current_day)
	
	_check_for_encounters()

func _check_for_encounters():
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
		var upf_forces = systems_with_fleets[sys]["UPF"]
		var sathar_forces = systems_with_fleets[sys]["Sathar"]
		
		# Encounter triggers if fleets co-exist OR if Sathar arrives at a UPF system with a station
		var has_station = (sys in UPF_FORTRESSES or sys in UPF_ARMED_STATIONS)
		
		if sathar_forces.size() > 0 and (upf_forces.size() > 0 or has_station):
			emit_signal("campaign_encounter_triggered", sys, upf_forces, sathar_forces)

func create_new_fleet(faction: String, system_id: String, fleet_name: String) -> CampaignFleet:
	var new_fleet = CampaignFleet.new(fleet_name, faction, system_id)
	fleets.append(new_fleet)
	return new_fleet

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
