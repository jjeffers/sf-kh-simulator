extends RefCounted
class_name CampaignFleet

# The faction that owns this fleet ("UPF" or "Sathar")
var faction: String = ""

# The name of the fleet (e.g., "Task Force Cassidine")
var fleet_name: String = ""

# Current location node ID
var current_system_id: String = ""

# Destination node ID (if moving)
var destination_system_id: String = ""

# Number of days until arrival at destination
var days_to_arrival: int = 0

# List of Ship objects or ship state dictionaries
var ships: Array = []

func _init(p_name: String, p_faction: String, p_system_id: String):
	fleet_name = p_name
	faction = p_faction
	current_system_id = p_system_id
	destination_system_id = ""
	days_to_arrival = 0
	ships = []

func add_ship(ship_data):
	ships.append(ship_data)

func remove_ship(ship_data):
	ships.erase(ship_data)

func is_moving() -> bool:
	return destination_system_id != ""

func start_move(dest_id: String, transit_days: int = 5):
	if is_moving():
		push_warning("Fleet %s is already moving!" % fleet_name)
		return
	
	destination_system_id = dest_id
	days_to_arrival = transit_days

func cancel_move():
	destination_system_id = ""
	days_to_arrival = 0

# Called by the CampaignManager at the end of each turn
func advance_day() -> bool:
	if not is_moving():
		return false
		
	days_to_arrival -= 1
	if days_to_arrival <= 0:
		# Arrived!
		current_system_id = destination_system_id
		destination_system_id = ""
		days_to_arrival = 0
		return true # Signal arrival
	
	return false # Still moving

func get_ship_count() -> int:
	return ships.size()

func serialize() -> Dictionary:
	var ship_data_list = []
	for s in ships:
		if s.has_method("serialize"):
			ship_data_list.append(s.serialize())
		else:
			# Assume it's already a dict if not an object with serialize
			ship_data_list.append(s)
			
	return {
		"fleet_name": fleet_name,
		"faction": faction,
		"current_system_id": current_system_id,
		"destination_system_id": destination_system_id,
		"days_to_arrival": days_to_arrival,
		"ships": ship_data_list
	}

func deserialize(data: Dictionary):
	fleet_name = data.get("fleet_name", "Unknown Fleet")
	faction = data.get("faction", "Unknown")
	current_system_id = data.get("current_system_id", "")
	destination_system_id = data.get("destination_system_id", "")
	days_to_arrival = data.get("days_to_arrival", 0)
	
	ships.clear()
	# Note: Deserializing ships back into full objects will likely happen 
	# at the CampaignManager level, passing dicts or Ship instantiations here.
	var saved_ships = data.get("ships", [])
	ships.append_array(saved_ships)
