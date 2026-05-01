class_name Ship
extends Node2D


@export var side_id: int = 1
@export var adf: int = 5
@export var mr: int = 3
@export var color: Color = Color.WHITE

var texture_fighter = preload("res://Assets/upf_fighter.png")
var texture_assault_scout = preload("res://Assets/upf_assault_scout.png")
var texture_frigate = preload("res://Assets/upf_frigate.png")
var texture_upf_minelayer = preload("res://Assets/upf_minelayer.png")
var texture_space_station = preload("res://Assets/upf_space_station.png")
var texture_sathar_destroyer = preload("res://Assets/sathar_destroyer.png")
var texture_sathar_heavy_cruiser = preload("res://Assets/sathar_heavy_cruiser.png")
var texture_sathar_frigate = preload("res://Assets/sathar_frigate.png")
var texture_sathar_fighter = preload("res://Assets/sathar_fighter.png")
var texture_sathar_assault_carrier = preload("res://Assets/sathar_assault_carrier.png")
var texture_sathar_light_cruiser = preload("res://Assets/sathar_light_cruiser.png")

var texture_upf_destroyer = preload("res://Assets/upf_destroyer.png")
var texture_upf_heavy_cruiser = preload("res://Assets/upf_heavy_cruiser.png")
var texture_upf_battleship = preload("res://Assets/upf_battleship.png")
var texture_upf_assault_carrier = preload("res://Assets/upf_assault_carrier.png")
var texture_upf_light_cruiser = preload("res://Assets/upf_light_cruiser.png")

var texture_civilian_1 = preload("res://Assets/civilian1.png")
var texture_civilian_2 = preload("res://Assets/civilian2.png")
var texture_civilian_3 = preload("res://Assets/civilian3.png")
var texture_shuttle = preload("res://Assets/shuttle.png")


var faction: String = "UPF"
var agility: int = 1

# Multiplayer Ownership
var owner_peer_id: int = 0 # 0 = Server/AI, >0 = Player Peer ID

var max_hull: int = 15
var hull: int = 15
var icm_max: int = 0
var icm_current: int = 0
var base_icm_max: int = 0
var ms_max: int = 0
var ms_current: int = 0
var base_ms_max: int = 0
var is_ms_active: bool = false: set = _set_ms_active
var ms_orbit_start_hex: Vector3i = Vector3i.MAX # Sentinel for orbit MS logic

var equipped_screens: Array[String] = []
var active_screen: String = "None": set = _set_active_screen

var is_selected: bool = false: set = _set_is_selected

var ms_particles: CPUParticles2D = null

# Docking State
var is_docked: bool = false
var docked_host: Ship = null
var docked_guests: Array[Ship] = []
var rearm_count: int = 0
var turns_docked_since_action: int = 0
var rearm_capacity: int = 0

# Scenario Specific
var evacuation_turns: int = 0
var previous_path: Array[Vector3i] = []


var grid_position: Vector3i = Vector3i.ZERO: set = _set_grid_position
var is_deployed: bool = false
var facing: int = 0: set = _set_facing # 0 to 5, direction index
var speed: int = 0
var has_moved: bool = false
var has_fired: bool = false
var orbit_direction: int = 0 # 0=None, 1=CW, -1=CCW
var has_withdrawn: bool = false # Tracks if ship retreated from combat
var has_ever_fired: bool = false # Tracks if ship ever attacked in this battle
var is_militia: bool = false # Tracks if ship is localized planetary militia

# Undo State
var turn_start_state: Dictionary = {}

# Planned Movement State
var has_orders: bool = false
var planned_path: Array[Vector3i] = []
var planned_facing: int = 0
var planned_orbit_dir: int = 0
var planned_mines_to_drop: Array[Vector3i] = []
var planned_seekers_to_drop: Array[Vector3i] = []

func get_net_state() -> Dictionary:
	return {
		"hull": hull,
		"max_hull": max_hull,
		"icm_current": icm_current,
		"icm_max": icm_max,
		"base_icm_max": base_icm_max,
		"ms_current": ms_current,
		"ms_max": ms_max,
		"base_ms_max": base_ms_max,
		"is_ms_active": is_ms_active,
		"equipped_screens": equipped_screens,
		"active_screen": active_screen,
		"ccs_damaged": ccs_damaged,
		"has_electrical_fire": has_electrical_fire,
		"has_disastrous_fire": has_disastrous_fire,
		"fire_damage_stack": fire_damage_stack,
		"current_adf_modifier": current_adf_modifier,
		"current_mr_modifier": current_mr_modifier,
		"has_moved": has_moved,
		"has_fired": has_fired,
		"has_ever_fired": has_ever_fired,
		"has_withdrawn": has_withdrawn,
		"is_militia": is_militia,
		"is_docked": is_docked, # Sync Docking State
		"grid_position": grid_position,
		"facing": facing,
		"orbit_direction": orbit_direction,
		"speed": speed,
		"planned_mines_to_drop": planned_mines_to_drop,
		"planned_seekers_to_drop": planned_seekers_to_drop,
		"is_deployed": is_deployed,
		"is_destroyed": is_destroyed, # Important for sync
		"current_dcr": current_dcr,
		"max_dcr": max_dcr,
		"unrepairable_mr_modifier": unrepairable_mr_modifier,
		"unrepairable_adf_modifier": unrepairable_adf_modifier,
		"unrepairable_electrical_fire": unrepairable_electrical_fire,
		"unrepairable_disastrous_fire": unrepairable_disastrous_fire,
		"unrepairable_icm": unrepairable_icm,
		"unrepairable_ms": unrepairable_ms,
		"unrepairable_ccs": unrepairable_ccs,
		"rearm_capacity": rearm_capacity,
		"weapons": _get_weapon_states() # Needed for crippled/ammo
	}

func apply_net_state(data: Dictionary):
	hull = data.get("hull", hull)
	max_hull = data.get("max_hull", max_hull)
	icm_current = data.get("icm_current", icm_current)
	icm_max = data.get("icm_max", icm_max)
	base_icm_max = data.get("base_icm_max", base_icm_max)
	ms_current = data.get("ms_current", ms_current)
	ms_max = data.get("ms_max", ms_max)
	base_ms_max = data.get("base_ms_max", base_ms_max)
	is_ms_active = data.get("is_ms_active", is_ms_active)
	equipped_screens = data.get("equipped_screens", equipped_screens)
	active_screen = data.get("active_screen", active_screen)
	
	ccs_damaged = data.get("ccs_damaged", ccs_damaged)
	has_electrical_fire = data.get("has_electrical_fire", has_electrical_fire)
	has_disastrous_fire = data.get("has_disastrous_fire", has_disastrous_fire)
	fire_damage_stack = data.get("fire_damage_stack", fire_damage_stack)
	
	current_adf_modifier = data.get("current_adf_modifier", current_adf_modifier)
	current_mr_modifier = data.get("current_mr_modifier", current_mr_modifier)
	
	current_dcr = data.get("current_dcr", current_dcr)
	max_dcr = data.get("max_dcr", max_dcr)
	unrepairable_mr_modifier = data.get("unrepairable_mr_modifier", unrepairable_mr_modifier)
	unrepairable_adf_modifier = data.get("unrepairable_adf_modifier", unrepairable_adf_modifier)
	unrepairable_electrical_fire = data.get("unrepairable_electrical_fire", unrepairable_electrical_fire)
	unrepairable_disastrous_fire = data.get("unrepairable_disastrous_fire", unrepairable_disastrous_fire)
	unrepairable_icm = data.get("unrepairable_icm", unrepairable_icm)
	unrepairable_ms = data.get("unrepairable_ms", unrepairable_ms)
	unrepairable_ccs = data.get("unrepairable_ccs", unrepairable_ccs)
	rearm_capacity = data.get("rearm_capacity", rearm_capacity)
	
	is_deployed = data.get("is_deployed", is_deployed)
	has_moved = data.get("has_moved", has_moved)
	has_fired = data.get("has_fired", has_fired)
	has_ever_fired = data.get("has_ever_fired", has_ever_fired)
	has_withdrawn = data.get("has_withdrawn", has_withdrawn)
	is_militia = data.get("is_militia", is_militia)
	
	# Docking Sync
	var net_is_docked = data.get("is_docked", is_docked)
	if is_docked and not net_is_docked:
		undock() # Helper clears host and state
	elif not is_docked and net_is_docked:
		is_docked = true # Force state, though host ref might be missing (Client logic likely handles dock_at separately or assumes persistent setup)
		if ship_class in ["Fighter", "Assault Scout"]:
			visible = false
	
	# Position/Movement
	_set_grid_position(data.get("grid_position", grid_position))
	_set_facing(data.get("facing", facing))
	orbit_direction = data.get("orbit_direction", orbit_direction)
	speed = data.get("speed", speed)
	
	if data.has("planned_mines_to_drop"):
		planned_mines_to_drop.assign(data["planned_mines_to_drop"])
	else:
		planned_mines_to_drop.clear()
		
	if data.has("planned_seekers_to_drop"):
		planned_seekers_to_drop.assign(data["planned_seekers_to_drop"])
	else:
		planned_seekers_to_drop.clear()
	
	var net_is_destroyed = data.get("is_destroyed", is_destroyed)
	if net_is_destroyed and not is_destroyed:
		trigger_explosion()
	elif net_is_destroyed:
		is_destroyed = true
	elif not net_is_destroyed and is_destroyed:
		# Resurrect based on authoritative host state
		is_destroyed = false
		is_exploding = false
		visible = true
		
	if is_destroyed and hull > 0: hull = 0 # Safety
	
	if data.has("weapons"):
		_apply_weapon_states(data["weapons"])
		
	# Trigger visual updates
	queue_redraw()
	binding_pos_update()
	if is_destroyed and not is_exploding:
		visible = false

func _get_weapon_states() -> Array:
	var states = []
	for w in weapons:
		states.append({
			"name": w.get("name", "Unknown"),
			"type": w.get("type", "Unknown"),
			"range": w.get("range", 0),
			"ammo": w.get("ammo", 0),
			"max_ammo": w.get("max_ammo", 0),
			"damage_dice": w.get("damage_dice", "1d10"),
			"damage_bonus": w.get("damage_bonus", 0),
			"is_crippled": w.get("is_crippled", false),
			"unrepairable": w.get("unrepairable", false),
			"fired": w.get("fired", false)
		})
	return states

func get_active_weapon_groups() -> Dictionary:
	var groups = {}
	for w in weapons:
		if w.get("is_crippled", false): continue
		if w.get("ammo", 0) <= 0: continue
		
		var t = w.get("type", "Unknown")
		var r = w.get("range", 0)
		# Use type + range as key to group identical weapons
		var key = "%s_%d" % [t, r]
		
		if not groups.has(key):
			# Map type to display name
			var display_name = t
			# Simple heuristics for nicer names based on type
			if t == "Laser": display_name = "Laser Battery"
			elif t == "Rocket": display_name = "Assault Rocket"
			elif t == "Rocket Battery": display_name = "Rocket Battery"
			elif t == "Torpedo": display_name = "Torpedo"
			elif t == "Laser Canon": display_name = "Laser Canon"
			
			groups[key] = {
				"count": 0,
				"range": r,
				"name": display_name
			}
		
		groups[key]["count"] += 1
		
	return groups

func _apply_weapon_states(states: Array):
	if states.size() != weapons.size():
		# Weapon count mismatch? 
		# This can happen if scenario loaded wrong, but we fixed that.
		# Just try to map by index.
		pass
		
	for i in range(min(states.size(), weapons.size())):
		var s = states[i]
		var w = weapons[i]
		w["name"] = s.get("name", w.get("name", "Unknown"))
		w["type"] = s.get("type", w.get("type", "Unknown"))
		w["range"] = s.get("range", w.get("range", 0))
		w["ammo"] = s.get("ammo", w.get("ammo", 0))
		w["max_ammo"] = s.get("max_ammo", w.get("max_ammo", 0))
		w["damage_dice"] = s.get("damage_dice", w.get("damage_dice", "1d10"))
		w["damage_bonus"] = s.get("damage_bonus", w.get("damage_bonus", 0))
		w["is_crippled"] = s.get("is_crippled", w.get("is_crippled", false))
		w["unrepairable"] = s.get("unrepairable", w.get("unrepairable", false))
		w["fired"] = s.get("fired", w.get("fired", false))


func get_effective_adf() -> int:
	return max(0, adf - current_adf_modifier)

func get_effective_mr() -> int:
	return max(0, mr - current_mr_modifier)

# Hull Integrity Rule Integration
func get_hull_integrity_risk(adf_used: int, mr_used: int) -> int:
	var threshold = floor(max_hull / 2.0)
	if hull > threshold:
		return 0 # Safe
		
	var damage_taken = max_hull - hull
	var base_risk = damage_taken - threshold
	return int(base_risk * (adf_used + mr_used))


# Class and Weapons
var ship_class: String = "Scout"
var defense: String = "None"
# Weapon Dictionary: {name, type, range, arc, ammo, max_ammo, damage_dice, damage_bonus, dtm, is_crippled}
var weapons: Array = []
var current_weapon_index: int = 0

# Damage State
var current_adf_modifier: int = 0
var current_mr_modifier: int = 0
var fire_damage_stack: int = 0 # 20, 40 etc.
var ccs_damaged: bool = false
var has_electrical_fire: bool = false
var has_disastrous_fire: bool = false

# Repair State (DCR)
var current_dcr: int = 0
var max_dcr: int = 0
var unrepairable_mr_modifier: int = 0
var unrepairable_adf_modifier: int = 0
var unrepairable_electrical_fire: bool = false
var unrepairable_disastrous_fire: bool = false
var unrepairable_icm: bool = false
var unrepairable_ms: bool = false
var unrepairable_ccs: bool = false

func finalize_configuration():
	# Maps starting constants to track irreversible mechanical failure UI
	base_icm_max = icm_max
	base_ms_max = ms_max

signal ship_moved(new_pos)
signal ship_destroyed
signal hull_changed(new_value)
signal state_changed # Warning: New signal for non-hull state changes

func take_hull_damage(amount: int):
	hull = max(0, hull - amount)
	hull_changed.emit(hull)
	queue_redraw() # Immediate visual update
	
	if hull <= 0:
		trigger_explosion()

func apply_damage_effect(effect: Dictionary, roll_damage_amount: int) -> Dictionary:
	var log_msg = effect.get("text", "Unknown Effect")
	var type = effect.get("type")
	var fallback_needed = false
	
	if type == "Hull":
		var mult = effect.get("mult", 1.0)
		var dmg = int(roll_damage_amount * mult)
		take_hull_damage(dmg)
		log_msg += " (%d Damage)" % dmg
		
	elif type == "ADF":
		var val = effect.get("val", 0)
		if get_effective_adf() == 0:
			fallback_needed = true
		elif val == -99: # All
			current_adf_modifier = adf
		elif val == -0.5: # Half
			current_adf_modifier += ceil(adf / 2.0)
		else:
			current_adf_modifier += abs(val)
		
	elif type == "MR":
		var val = effect.get("val", 0)
		if get_effective_mr() == 0:
			fallback_needed = true
		elif val == -99:
			current_mr_modifier = mr
		else:
			current_mr_modifier += abs(val)
			
	elif type == "Weapon":
		# list: ["Laser", "Rocket"]
		var priority_list = effect.get("list", [])
		var crippled_weapon = null
		
		# Find first available weapon type to cripple
		for target_type in priority_list:
			# Find a weapon of this type that is NOT already crippled
			for w in weapons:
				var w_type = w.get("type", "")
				var match_found = false
				
				if target_type == "Laser" and w_type == "Laser": match_found = true
				elif target_type == "Laser Canon" and w_type == "Laser Canon": match_found = true
				elif target_type == "Rocket" and w_type == "Rocket": match_found = true # Assault Rocket type is "Rocket"
				elif target_type == "Rocket Battery" and w_type == "Rocket Battery": match_found = true
				elif target_type == "Torpedo" and w_type == "Torpedo": match_found = true
				
				if match_found and not w.get("is_crippled", false):
					w["is_crippled"] = true
					crippled_weapon = w
					break
			if crippled_weapon: break
			
		if crippled_weapon:
			log_msg += ": %s Crippled!" % crippled_weapon["name"]
		else:
			fallback_needed = true
			log_msg += " (No matching weapons to cripple)"

	elif type == "System":
		var key = effect.get("key")
		if key == "ICM":
			if icm_max == 0:
				fallback_needed = true
			else:
				icm_current = 0
				icm_max = 0
		elif key == "CCS":
			if ccs_damaged:
				fallback_needed = true
			else:
				ccs_damaged = true

	elif type == "Defense":
		var list = effect.get("list", [])
		var affected = false
		for sys in list:
			if sys == "MS":
				if ms_max > 0:
					ms_current = 0
					ms_max = 0
					affected = true
			elif sys == "ICM":
				if icm_max > 0:
					icm_current = 0
					icm_max = 0
					affected = true
		
		# If neither system existed to be damaged?
		# Rule says "does not have the system indicated". 
		# Prior logic didn't check. Now let's assume if NO system was affected, fallback?
		# "Defense hit: masking screens, ICMs". If I have neither, fallback.
		if not affected:
			fallback_needed = true

	elif type == "Navigation":
		if get_effective_adf() == 0 and get_effective_mr() == 0:
			fallback_needed = true
		else:
			current_adf_modifier = adf
			current_mr_modifier = mr
		
	elif type == "Fire":
		var key = effect.get("key")
		if key == "Electrical":
			if not has_disastrous_fire and has_electrical_fire:
				fallback_needed = true # Duplicate Electrical
			elif has_disastrous_fire:
				fallback_needed = true # Cannot downgrade or stack
			else:
				has_electrical_fire = true
				fire_damage_stack = 20
		elif key == "Disastrous":
			if has_disastrous_fire:
				fallback_needed = true # Duplicate Disastrous
			else:
				has_disastrous_fire = true
				has_electrical_fire = false
				fire_damage_stack = 20
				current_adf_modifier = adf
				current_mr_modifier = mr
				ccs_damaged = true

	state_changed.emit()
	return {"text": log_msg, "fallback": fallback_needed}

func configure_fighter():
	ship_class = "Fighter"
	defense = "RH" # Reflective Hull
	max_hull = 8
	hull = max_hull
	adf = 5
	mr = 5
	icm_max = 0
	icm_current = 0
	ms_max = 0
	ms_current = 0
	max_dcr = 30
	current_dcr = max_dcr
	
	weapons.clear()
	weapons.append({
		"name": "Assault Rockets",
		"type": "Rocket",
		"range": 4,
		"arc": "FF",
		"ammo": 3,
		"max_ammo": 3,
		"damage_dice": "2d10",
		"damage_bonus": 4,
		"dtm": - 10,
		"fired": false
	})
	current_weapon_index = 0

func configure_assault_scout():
	ship_class = "Assault Scout"
	defense = "RH"
	max_hull = 15
	hull = max_hull
	adf = 5
	mr = 4
	ms_max = 0
	ms_current = 0
	max_dcr = 50
	current_dcr = max_dcr
	
	weapons.clear()
	# Laser Battery: Range 9, 360 Arc, 1d10
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 9,
		"arc": "360",
		"ammo": 999, # Infinite
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"dtm": 0,
		"fired": false
	})
	
	# Assault Rockets: Range 4, FF, Ammo 4, 2d10+4
	weapons.append({
		"name": "Assault Rockets",
		"type": "Rocket",
		"range": 4,
		"arc": "FF",
		"ammo": 4,
		"max_ammo": 4,
		"damage_dice": "2d10",
		"damage_bonus": 4,
		"dtm": - 10,
		"fired": false
	})
	current_weapon_index = 0 # Default to Laser

func configure_frigate():
	ship_class = "Frigate"
	defense = "RH"
	max_hull = 40
	hull = max_hull
	adf = 3
	mr = 3
	icm_max = 4
	icm_current = 4
	ms_max = 1
	ms_current = 1
	max_dcr = 70
	current_dcr = max_dcr
	equipped_screens = ["ICMs (x4)"] # Note: Frigate doesn't actually have screens per table, just ICMs. Storing literal if needed, but keeping empty for Energy Screens.
	equipped_screens.clear()
	
	weapons.clear()
	# Laser Battery: Range 9
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 9,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Laser Canon: Range 10, FF, 2d10. 
	weapons.append({
		"name": "Laser Canon",
		"type": "Laser Canon",
		"range": 10,
		"arc": "FF",
		"ammo": 999, # Canons usually infinite? Or limited? Assuming infinite unless specified.
		"max_ammo": 999,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"dtm": 0,
		"fired": false
	})
	
	# Rocket Batteries: 4 Batteries total
	# Consolidated into one entry for UI clarity and "1 per turn" enforcement.
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": 4,
		"max_ammo": 4,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"dtm": - 10,
		"fired": false
	})
	
	# Torpedoes: 2 Torpedoes
	weapons.append({
		"name": "Torpedoes",
		"type": "Torpedo",
		"range": 4,
		"arc": "360",
		"ammo": 2,
		"max_ammo": 2,
		"damage_dice": "4d10",
		"damage_bonus": 0,
		"dtm": 20,
		"fired": false
	})
	
	current_weapon_index = 0
	
func configure_minelayer():
	ship_class = "Minelayer"
	defense = "RH"
	max_hull = 40
	hull = max_hull
	adf = 1
	mr = 2
	icm_max = 4
	icm_current = 4
	ms_max = 4
	ms_current = 4
	max_dcr = 75
	current_dcr = max_dcr
	equipped_screens.clear()
	
	weapons.clear()
	# Laser Batteries (x2), Mines, Seekers
	weapons = [
		{
			"name": "Laser Battery A",
			"type": "Laser",
			"range": 9,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"fired": false
		},
		{
			"name": "Laser Battery B",
			"type": "Laser",
			"range": 9,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"fired": false
		},
		{
			"name": "Mines",
			"type": "Mine",
			"range": 0,
			"arc": "360",
			"ammo": 20,
			"max_ammo": 20,
			"damage_dice": "3d10",
			"damage_bonus": 5,
			"dtm": -20,
			"fired": false
		},
		{
			"name": "Seekers",
			"type": "Seeker",
			"range": 0,
			"arc": "360",
			"ammo": 4,
			"max_ammo": 4,
			"damage_dice": "5d10",
			"damage_bonus": 0,
			"dtm": -20,
			"fired": false
		}
	]
	current_weapon_index = 0

func configure_destroyer():
	ship_class = "Destroyer"
	defense = "RH"
	max_hull = 50
	hull = max_hull
	adf = 3
	mr = 2
	icm_max = 4
	icm_current = 4
	ms_max = 2
	ms_current = 2
	max_dcr = 75
	current_dcr = max_dcr
	
	weapons.clear()
	# Laser Battery: Range 9, 360 Arc, 1d10
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 9,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Laser Canon: Range 10, FF, 2d10
	weapons.append({
		"name": "Laser Canon",
		"type": "Laser Canon",
		"range": 10,
		"arc": "FF",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"dtm": 0,
		"fired": false
	})
	
	weapons.append({
		"name": "Electron Battery",
		"type": "Electron Beam Battery",
		"range": 10,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"dtm": 10,
		"fired": false
	})
	
	# Rocket Batteries (x6)
	# Consolidated: Ammo 6
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": 6,
		"max_ammo": 6,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Torpedoes (x2)
	# Consolidated: Ammo 2
	weapons.append({
		"name": "Torpedoes",
		"type": "Torpedo",
		"range": 4,
		"arc": "360",
		"ammo": 2, # Standard?
		"max_ammo": 2,
		"damage_dice": "4d10",
		"damage_bonus": 0,
		"dtm": 20,
		"fired": false
	})
		
	current_weapon_index = 0
	
func configure_light_cruiser():
	ship_class = "Light Cruiser"
	defense = "RH"
	max_hull = 70
	hull = max_hull
	adf = 3
	mr = 2
	icm_max = 8
	icm_current = 8
	ms_max = 1
	ms_current = 1
	equipped_screens = ["ES", "SS"]
	max_dcr = 100
	current_dcr = max_dcr
	
	weapons.clear()
	weapons.append({
		"name": "Disruptor Canon",
		"type": "Disruptor Cannon",
		"range": 9,
		"arc": "FF",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "3d10",
		"damage_bonus": 0,
		"dtm": 20,
		"fired": false
	})
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 9,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"dtm": 0,
		"fired": false
	})
	weapons.append({
		"name": "Electron Battery",
		"type": "Electron Beam Battery",
		"range": 10,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"dtm": 10,
		"fired": false
	})
	weapons.append({
		"name": "Proton Battery",
		"type": "Proton Beam Battery",
		"range": 12,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"dtm": 10,
		"fired": false
	})
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": 6,
		"max_ammo": 6,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"dtm": -10,
		"fired": false
	})
	weapons.append({
		"name": "Torpedoes",
		"type": "Torpedo",
		"range": 4,
		"arc": "360",
		"ammo": 4,
		"max_ammo": 4,
		"damage_dice": "4d10",
		"damage_bonus": 0,
		"dtm": 20,
		"fired": false
	})

func configure_shuttle():
	ship_class = "Shuttle"
	defense = "None"
	max_hull = 5
	hull = max_hull
	adf = 2
	mr = 2
	icm_max = 0
	icm_current = 0
	ms_max = 0
	ms_current = 0
	max_dcr = 10
	current_dcr = max_dcr
	weapons.clear()

func configure_civilian_ship(variant: int = 1):
	ship_class = "Civilian"
	defense = "None"
	max_hull = 10 * variant
	hull = max_hull
	adf = 2
	mr = 1
	icm_max = 0
	icm_current = 0
	ms_max = 0
	ms_current = 0
	max_dcr = 20
	current_dcr = max_dcr
	weapons.clear()
	
	current_weapon_index = 0

func configure_heavy_cruiser():
	ship_class = "Heavy Cruiser"
	defense = "RH"
	max_hull = 80
	hull = max_hull
	adf = 1
	mr = 1
	icm_max = 8
	icm_current = 8
	ms_max = 1
	ms_current = 1
	equipped_screens = ["PS", "SS"]
	max_dcr = 120
	current_dcr = max_dcr
	
	weapons.clear()
	# Laser Batteries (x2)
	for i in range(2):
		weapons.append({
			"name": "Laser Battery %d" % (i + 1),
			"type": "Laser",
			"range": 9,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"fired": false
		})
		
	# Disruptor Canon
	weapons.append({
		"name": "Disruptor Canon",
		"type": "Disruptor Canon",
		"range": 9,
		"arc": "FF",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "3d10",
		"damage_bonus": 0,
		"dtm": 20,
		"fired": false
	})
	
	weapons.append({
		"name": "Proton Battery",
		"type": "Proton Beam Battery",
		"range": 12,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"dtm": 10,
		"fired": false
	})
	
	weapons.append({
		"name": "Electron Battery",
		"type": "Electron Beam Battery",
		"range": 10,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"dtm": 10,
		"fired": false
	})
	
	# Rocket Batteries (x8 - Consolidated)
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": 8,
		"max_ammo": 8,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"dtm": - 10,
		"fired": false
	})
	
	# Torpedoes (x4 - Consolidated)
	weapons.append({
		"name": "Torpedoes",
		"type": "Torpedo",
		"range": 4,
		"arc": "360",
		"ammo": 4,
		"max_ammo": 4,
		"damage_dice": "4d10",
		"damage_bonus": 0,
		"dtm": 20,
		"fired": false
	})
	
	current_weapon_index = 0
	
func configure_battleship():
	ship_class = "Battleship"
	defense = "RH"
	max_hull = 120
	hull = max_hull
	adf = 2
	mr = 2
	icm_max = 12
	icm_current = 12
	ms_max = 4
	ms_current = 4
	equipped_screens = ["PS", "ES", "SS"]
	max_dcr = 200
	current_dcr = max_dcr
	
	weapons.clear()
	# Disruptor Canon
	weapons.append({
		"name": "Disruptor Canon",
		"type": "Disruptor Canon",
		"range": 9,
		"arc": "FF",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "3d10",
		"damage_bonus": 0,
		"dtm": 20,
		"fired": false
	})
		
	# Laser Batteries (x4)
	for i in range(4):
		weapons.append({
			"name": "Laser Battery %d" % (i + 1),
			"type": "Laser",
			"range": 9,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"dtm": 0,
			"fired": false
		})
		
	weapons.append({
		"name": "Proton Battery",
		"type": "Proton Beam Battery",
		"range": 12,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"dtm": 10,
		"fired": false
	})

	for i in range(2):
		weapons.append({
			"name": "Electron Battery %d" % (i + 1),
			"type": "Electron Beam Battery",
			"range": 10,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"dtm": 10,
			"fired": false
		})
		
	# Rocket Batteries (x10)
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": 10,
		"max_ammo": 10,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"dtm": - 10,
		"fired": false
	})
	
	# Torpedoes (x8)
	weapons.append({
		"name": "Torpedoes",
		"type": "Torpedo",
		"range": 4, # Standard Range?
		"arc": "360",
		"ammo": 8,
		"max_ammo": 8,
		"damage_dice": "4d10",
		"damage_bonus": 0,
		"dtm": 20,
		"fired": false
	})
	
	current_weapon_index = 0
	
func configure_assault_carrier():
	ship_class = "Assault Carrier"
	defense = "RH"
	max_hull = 75
	hull = max_hull
	adf = 2
	mr = 1
	icm_max = 10
	icm_current = 10
	ms_max = 4
	ms_current = 4
	max_dcr = 150
	current_dcr = max_dcr
	rearm_capacity = 20
	
	weapons.clear()
	# Laser Battery
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 9,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"dtm": 0,
		"fired": false
	})
		
	# Rocket Batteries (x8)
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": 8,
		"max_ammo": 8,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"dtm": - 10,
		"fired": false
	})
	
	current_weapon_index = 0

func configure_space_station(force_hull: int = -1):
	ship_class = "Space Station"
	defense = "RH"
	
	if force_hull > 0:
		hull = force_hull
	else:
		# Random Hull 20-200, Normal Distribution around 100
		# randfn(mean, deviation). 
		# Range 20-200 is roughly +/- 2.5 sigma if sigma is 30?
		var h = randfn(100.0, 40.0)
		hull = int(clamp(h, 20, 200))
		
	max_hull = hull
	max_dcr = max_hull / 2
	current_dcr = max_dcr
	adf = 0
	mr = 0
	
	# ICM Scaling: floor(H / 25), clmap 2-8
	icm_max = int(clamp(floor(hull / 25.0), 2, 8))
	icm_current = icm_max
	
	# MS Scaling: 1-4. floor(H/50)?
	# Prompt: "1 to 4".
	# 20 -> 1. 200 -> 4.
	# H/60? 20/60 = 0 -> 1. 200/60 = 3 -> 4.
	ms_max = int(clamp(floor(hull / 50.0) + 1, 1, 4))
	ms_current = ms_max
	
	equipped_screens = ["ES", "SS", "PS"]
	
	weapons.clear()
	
	# Laser Batteries: floor(H / 60) + 1, clamp 1-3
	var lb_count = int(clamp(floor(hull / 60.0) + 1, 1, 3))
	for i in range(lb_count):
		weapons.append({
			"name": "Laser Battery %d" % (i + 1),
			"type": "Laser",
			"range": 9, # Station batteries might have better range? keeping standard 10 -> Now 9
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"dtm": 0,
			"fired": false
		})
		
	# Space Station gets 1 electron, proton, or laser per 50 hp. 
	# Given standard simplicity let's configure 1 of each for a 150HP station, or random.
	# Let's add 1 of each to make it balanced, scaled.
	var special_beams = int(floor(hull / 50.0))
	if special_beams > 0:
		weapons.append({
			"name": "Electron Battery",
			"type": "Electron Beam Battery",
			"range": 10,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"dtm": 10,
			"fired": false
		})
	if special_beams > 1:
		weapons.append({
			"name": "Proton Battery",
			"type": "Proton Beam Battery",
			"range": 12,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"dtm": 10,
			"fired": false
		})
		
	# Rocket Batteries: floor(H / 15), clamp 2-12
	var rb_count = int(clamp(floor(hull / 15.0), 2, 12))
	weapons.append({
		"name": "Rocket Battery Swarm",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": rb_count,
		"max_ammo": rb_count,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"dtm": -10,
		"fired": false
	})
	
	current_weapon_index = 0

func configure_armed_station():
	ship_class = "Armed Station"
	defense = "RH"
	hull = 80
	max_hull = 80
	max_dcr = 75
	current_dcr = 75
	adf = 0
	mr = 0
	icm_max = 6
	icm_current = 6
	ms_max = 2
	ms_current = 2
	equipped_screens = ["ES", "SS", "PS"]
	
	weapons.clear()
	weapons.append({"name": "Laser Battery", "type": "Laser", "range": 9, "arc": "360", "ammo": 999, "max_ammo": 999, "damage_dice": "1d10", "damage_bonus": 0, "dtm": 0, "fired": false})
	weapons.append({"name": "Rocket Battery Swarm", "type": "Rocket Battery", "range": 3, "arc": "360", "ammo": 6, "max_ammo": 6, "damage_dice": "2d10", "damage_bonus": 0, "dtm": -10, "fired": false})
	current_weapon_index = 0

func configure_fortified_station():
	ship_class = "Fortified Station"
	defense = "RH"
	hull = 140
	max_hull = 140
	max_dcr = 100
	current_dcr = 100
	adf = 0
	mr = 0
	icm_max = 10
	icm_current = 10
	ms_max = 2
	ms_current = 2
	equipped_screens = ["ES", "SS", "PS"]
	
	weapons.clear()
	for i in range(2):
		weapons.append({"name": "Laser Battery %d" % (i+1), "type": "Laser", "range": 9, "arc": "360", "ammo": 999, "max_ammo": 999, "damage_dice": "1d10", "damage_bonus": 0, "dtm": 0, "fired": false})
	weapons.append({"name": "Rocket Battery Swarm", "type": "Rocket Battery", "range": 3, "arc": "360", "ammo": 8, "max_ammo": 8, "damage_dice": "2d10", "damage_bonus": 0, "dtm": -10, "fired": false})
	current_weapon_index = 0

func reset_weapons():
	has_fired = false
	for w in weapons:
		w["fired"] = false
		
	# MS maintenance handled in GM (if constraints broken), but here we can just ensure persistence?
	# "A masking screen remains in place once activated as long as the ship remains moving in a straight line at its current speed."
	# So we don't reset it here manually unless we want to clear it on turn start?
	# Actually, if it remains "once activated", we shouldn't clear it.
	
	state_changed.emit()
	queue_redraw()

func _ready():
	_setup_particles()
	queue_redraw()

func _setup_particles():
	ms_particles = CPUParticles2D.new()
	ms_particles.name = "MSParticles"
	ms_particles.emitting = false
	ms_particles.amount = 32
	ms_particles.lifetime = 1.5
	# Emission Shape: Sphere
	ms_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	ms_particles.emission_sphere_radius = HexGrid.TILE_SIZE * 0.7
	
	# Physics
	ms_particles.gravity = Vector2.ZERO
	ms_particles.direction = Vector2(0, -1)
	ms_particles.spread = 180.0
	ms_particles.initial_velocity_min = 5.0
	ms_particles.initial_velocity_max = 15.0
	ms_particles.damping_min = 5.0
	ms_particles.damping_max = 10.0
	
	# Visuals
	ms_particles.scale_amount_min = 2.0
	ms_particles.scale_amount_max = 4.0
	ms_particles.color = Color(0.4, 0.7, 1.0, 0.6) # Light Blue Vapor
	ms_particles.local_coords = true # Ensure they stick to the ship during "camera" (GameManager) movement
	
	add_child(ms_particles)
	# Ensure it draws behind the ship? 
	# Z-index is relative. Ship is parent. 
	# To draw behind, we can specific z_index or just order?
	# CanvasItems draw children on top.
	# We want particles BEHIND? Then use show_behind_parent = true
	ms_particles.show_behind_parent = true

func _set_ms_active(val: bool):
	is_ms_active = val
	if ms_particles:
		ms_particles.emitting = val
	state_changed.emit()
	queue_redraw()

func _set_is_selected(val: bool):
	is_selected = val
	queue_redraw()

func _set_facing(v: int):
	facing = v
	queue_redraw()

func _set_grid_position(v: Vector3i):
	grid_position = v
	# Position update is now handled by GameManager's stack update or explicit call
	# But we set a default here just in case, though it might be overridden immediately
	position = HexGrid.hex_to_pixel(v)
	for guest in docked_guests:
		if is_instance_valid(guest):
			guest.grid_position = v
	ship_moved.emit(v)

func _set_active_screen(val: String):
	active_screen = val
	state_changed.emit()

var is_ghost: bool = false
var is_exploding: bool = false
var is_destroyed: bool = false
var show_info: bool = true

func set_ghost(val: bool):
	is_ghost = val
	if is_ghost:
		modulate.a = 0.5
		z_index = 10 # Draw on top
	else:
		modulate.a = 1.0
		z_index = 0
	queue_redraw()

func binding_pos_update():
	position = HexGrid.hex_to_pixel(grid_position)

func _draw():
	if is_exploding: return

	# If Masking Screen active, we rely on particles now.
	# But maybe a faint outline is still good?
	if is_ms_active:
		# Draw a very faint outline to define the "screen" boundary
		draw_arc(Vector2.ZERO, HexGrid.TILE_SIZE * 0.8, 0, TAU, 32, Color(0.4, 0.7, 1.0, 0.3), 1.0)

	if is_selected:
		# Draw bright selection ring
		# Pulse width or brightness? Simple bright outline for now.
		draw_arc(Vector2.ZERO, HexGrid.TILE_SIZE * 0.9, 0, TAU, 32, Color(1.0, 1.0, 0.0, 0.8), 3.0)

	var color_to_use = color
	if is_exploding:
		color_to_use = Color.ORANGE
	elif is_destroyed:
		color_to_use = Color.WEB_GRAY

	# Draw simple representation based on class
	var size = HexGrid.TILE_SIZE * 0.6
	var points = PackedVector2Array()
	
	match ship_class:
		"Assault Scout":
			# Sprite Rendering
			var target_size = HexGrid.TILE_SIZE * 0.7 # 0.7x Tile Size (28px)
			
			var ref_size = max(texture_assault_scout.get_width(), texture_assault_scout.get_height())
			var scale_factor = target_size / ref_size
			
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = texture_assault_scout.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(texture_assault_scout, rect, false, Color.WHITE)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			points = PackedVector2Array()
			points = PackedVector2Array()
		"Frigate":
			# Sprite Rendering
			var target_size = HexGrid.TILE_SIZE * 0.9
			
			var tex = texture_frigate # UPF Default
			if faction == "Sathar":
				tex = texture_sathar_frigate
				target_size = HexGrid.TILE_SIZE * 0.9 # Adjust if needed
			
			var ref_size = max(tex.get_width(), tex.get_height())
			var scale_factor = target_size / ref_size
			
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = tex.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(tex, rect, false, Color.WHITE)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			points = PackedVector2Array()
		"Minelayer":
			# Sprite Rendering
			var target_size = HexGrid.TILE_SIZE * 0.9
			
			var tex = texture_upf_minelayer # UPF Default for Minelayer
			if faction == "Sathar":
				tex = texture_sathar_frigate # Fallback to Sathar Frigate since no asset explicitly exists yet
				target_size = HexGrid.TILE_SIZE * 0.9
			
			var ref_size = max(tex.get_width(), tex.get_height())
			var scale_factor = target_size / ref_size
			
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = tex.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(tex, rect, false, Color.WHITE)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			points = PackedVector2Array()
		"Destroyer":
			if faction == "Sathar":
				# Sathar Destroyer Sprite
				var target_size = HexGrid.TILE_SIZE * 1.1 # 1.1x Tile Size (44px)
				var ref_size = max(texture_sathar_destroyer.get_width(), texture_sathar_destroyer.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_sathar_destroyer.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_sathar_destroyer, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
			else:
				# UPF Destroyer Sprite
				var target_size = HexGrid.TILE_SIZE * 1.1
				var ref_size = max(texture_upf_destroyer.get_width(), texture_upf_destroyer.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_upf_destroyer.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_upf_destroyer, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
		"Heavy Cruiser":
			if faction == "Sathar":
				# Sathar Heavy Cruiser Sprite
				var target_size = HexGrid.TILE_SIZE * 1.4 # 1.4x Tile Size (56px)
				var ref_size = max(texture_sathar_heavy_cruiser.get_width(), texture_sathar_heavy_cruiser.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_sathar_heavy_cruiser.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_sathar_heavy_cruiser, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
			else:
				# UPF Heavy Cruiser Sprite
				var target_size = HexGrid.TILE_SIZE * 1.4
				var ref_size = max(texture_upf_heavy_cruiser.get_width(), texture_upf_heavy_cruiser.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_upf_heavy_cruiser.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_upf_heavy_cruiser, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
		"Light Cruiser":
			if faction == "Sathar":
				# Sathar Light Cruiser Sprite
				var target_size = HexGrid.TILE_SIZE * 1.25 # 1.25x Tile Size
				var ref_size = max(texture_sathar_light_cruiser.get_width(), texture_sathar_light_cruiser.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_sathar_light_cruiser.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_sathar_light_cruiser, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
			else:
				# UPF Light Cruiser Sprite
				var target_size = HexGrid.TILE_SIZE * 1.25
				var ref_size = max(texture_upf_light_cruiser.get_width(), texture_upf_light_cruiser.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_upf_light_cruiser.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_upf_light_cruiser, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
		"Battleship":
			if faction == "Sathar":
				# No Sathar BB asset? Use fallback vector for now.
				size = HexGrid.TILE_SIZE * 0.85
				points = PackedVector2Array([
					Vector2(size, 0),
					Vector2(-size * 0.8, -size * 0.4),
					Vector2(-size * 0.5, 0),
					Vector2(-size * 0.8, size * 0.4)
				])
			else:
				# UPF Battleship Sprite
				var target_size = HexGrid.TILE_SIZE * 1.7 # Massive
				var ref_size = max(texture_upf_battleship.get_width(), texture_upf_battleship.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_upf_battleship.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_upf_battleship, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
		"Space Station", "Armed Station", "Fortified Station", "Space Station (Fortress)":
			# Sprite Rendering
			# Scale based on Hull Points: 1.0 + (max_hull / 200.0) -> Max ~2.0x
			# Examples: 100 HP -> 1.5x, 200 HP -> 2.0x relative to Tile Size
			var hp_scale_bonus = float(max_hull) / 200.0
			var target_size = HexGrid.TILE_SIZE * (1.0 + hp_scale_bonus)
			
			var ref_size = max(texture_space_station.get_width(), texture_space_station.get_height())
			var scale_factor = target_size / ref_size
			
			# Rotation: Stations might rotate or be fixed. 
			# Let's align with facing for now (it has a facing index).
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = texture_space_station.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(texture_space_station, rect, false, Color.WHITE)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			points = PackedVector2Array()
		"Assault Carrier":
			var target_size = HexGrid.TILE_SIZE * 2.0 # Huge
			
			var tex = texture_upf_assault_carrier # Default
			if faction == "Sathar":
				tex = texture_sathar_assault_carrier
				
			var ref_size = max(tex.get_width(), tex.get_height())
			var scale_factor = target_size / ref_size
			
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = tex.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(tex, rect, false, Color.WHITE)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			points = PackedVector2Array()
		"Fighter":
			# Sprite Rendering
			var target_size = HexGrid.TILE_SIZE * 0.5 # 0.5x Tile Size (20px)
			
			var tex = texture_fighter # Default UPF
			if faction == "Sathar":
				tex = texture_sathar_fighter
			
			var ref_size = max(tex.get_width(), tex.get_height())
			var scale_factor = target_size / ref_size
			
			# Rotation: Facing 0 = East?
			# If Sprite points UP (-Y), we need +90 deg to face East (0).
			# hex angle = facing * 60 deg.
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			# Draw centered
			var tex_size = texture_fighter.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			# Draw with color modulation? 
			# User didn't specify, but usually team color is good.
			# Or keep original? white modulation = original colors.
			# Let's use slight tint of team color + white? 
			# Or just color?
			# If sprite is colored, modulate mixes.
			# Let's assume white sprite or user wants team color.
			# Let's assume white sprite or user wants team color.
			draw_texture_rect(tex, rect, false, Color.WHITE)
			
			# Reset transform
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			# Skip polygon
			points = PackedVector2Array()
		"Civilian":
			# Sprite Rendering
			var target_size = HexGrid.TILE_SIZE * 1.0 # 1.0x Tile Size
			
			var tex = texture_civilian_1
			# Very primitive seeded variety check
			var hash_val = self.name.hash() % 3
			if hash_val == 1: tex = texture_civilian_2
			elif hash_val == 2: tex = texture_civilian_3
			
			var ref_size = max(tex.get_width(), tex.get_height())
			var scale_factor = target_size / ref_size
			
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = tex.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(tex, rect, false, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			points = PackedVector2Array()
		"Shuttle":
			# Sprite Rendering
			var target_size = HexGrid.TILE_SIZE * 0.4 # 0.4x Tile Size (Small)
			
			var tex = texture_shuttle
			var ref_size = max(tex.get_width(), tex.get_height())
			var scale_factor = target_size / ref_size
			
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = tex.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(tex, rect, false, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			points = PackedVector2Array()
		_:
			# Default / Fallback (Sleek Delta / Dart)
			points = PackedVector2Array([
				Vector2(size, 0),
				Vector2(-size * 0.5, -size * 0.5),
				Vector2(-size * 0.2, 0),
				Vector2(-size * 0.5, size * 0.5)
			])
	# Rotate points based on facing (each facing is 60 degrees = PI/3)
	if not points.is_empty():
		var angle = facing * (PI / 3.0)
		var rotated_points = PackedVector2Array()
		for p in points:
			rotated_points.append(p.rotated(angle))
			
		draw_colored_polygon(rotated_points, color)
		# Draw outline
		var outline = rotated_points.duplicate()
		outline.append(rotated_points[0]) # Close the loop
		draw_polyline(outline, Color.BLACK, 2.0)
	
	# Draw Info (Name and Health) - Only for real ships AND if show_info is true
	if not is_ghost and show_info:
		# Draw Name
		var default_font = ThemeDB.fallback_font
		var font_size = 14
		var name_pos = Vector2(-size, -size - 10)
		draw_string(default_font, name_pos, get_display_name(), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
		
		# Draw Health Bar
		var bar_width = HexGrid.TILE_SIZE * 0.8
		var bar_height = 6.0
		var bar_pos = Vector2(-bar_width / 2, size / 2 + 10)
		
		# Background/Border (Black)
		var bg_rect = Rect2(bar_pos, Vector2(bar_width, bar_height))
		draw_rect(bg_rect, Color.BLACK, false, 2.0) # Border
		
		# Health Fill
		var pct = float(hull) / float(max_hull)
		var fill_width = bar_width * pct
		var fill_rect = Rect2(bar_pos, Vector2(fill_width, bar_height))
		var health_color = Color.DARK_RED.lerp(Color.GREEN, pct)
		draw_rect(fill_rect, health_color, true)

func trigger_explosion():
	if is_exploding: return # Prevent double explosion
	
	is_ms_active = false # Kill systems
	is_exploding = true
	
	if not is_destroyed:
		is_destroyed = true
		hull = 0
		ship_destroyed.emit()
		
	queue_redraw()
	
	var particles = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 100
	particles.lifetime = 1.5
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 12.0 # Much larger particles
	particles.color = Color.ORANGE
	
	# Color gradient for fire effect
	var gradient = Gradient.new()
	gradient.set_color(0, Color.YELLOW)
	gradient.set_color(1, Color(1, 0, 0, 0)) # Fade to red transparent
	particles.color_ramp = gradient
	
	add_child(particles)
	particles.emitting = true
	
	# Wait for particles to finish before hiding (do not free, GameManager needs pointer for aftermath)
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func(): visible = false)

func reset_turn_state():
	has_moved = false
	has_fired = false
	turn_start_state.clear()
	# Don't reset movement points here, they are reset when phase starts
	# But we should reset energy or other per-turn counters if any
	reset_weapons()
	if is_docked:
		turns_docked_since_action += 1
	else:
		turns_docked_since_action = 0

func get_docking_capacity() -> int:
	if ship_class in ["Space Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]: return 999
	if ship_class == "Assault Carrier": return 10
	return 0

func replenish_ammo():
	for w in weapons:
		w["ammo"] = w["max_ammo"]
	# Also refill ICM/MS? Prompt says "replenishment of ammuniation". 
	# Usually implies weapons. Let's stick to weapons for now.


func get_display_name() -> String:
	var abbrev = ""
	match ship_class:
		"Fighter": abbrev = "F"
		"Frigate": abbrev = "FG"
		"Minelayer": abbrev = "ML"
		"Destroyer": abbrev = "DD"
		"Light Cruiser": abbrev = "CL"
		"Heavy Cruiser": abbrev = "CA"
		"Battleship": abbrev = "BB"
		"Civilian": abbrev = "SS"
		"Space Station", "Armed Station", "Fortified Station", "Space Station (Fortress)": abbrev = "ST"
		"Assault Scout": abbrev = "AS"
		"Assault Carrier": abbrev = "AC"
		_: abbrev = "?"
	
	return "%s %s" % [abbrev, name]

func can_dock_with(station: Ship) -> bool:
	if not is_instance_valid(station) or station == self:
		return false
	if station.ship_class not in ["Space Station", "Armed Station", "Fortified Station", "Space Station (Fortress)", "Assault Carrier"]:
		return false
	if station.docked_guests.size() >= station.get_docking_capacity():
		return false
	# If not deployed yet (AutoDeploy phase), allow docking anywhere
	if is_deployed and grid_position != station.grid_position:
		return false
	return speed == 0 or get_effective_adf() > speed

func dock_at(station: Ship) -> bool:
	if can_dock_with(station):
		is_docked = true
		docked_host = station
		if not station.docked_guests.has(self):
			station.docked_guests.append(self)
		
		if ship_class in ["Fighter", "Assault Scout"]:
			visible = false
			
		# Align position purely for visuals/logic consistency
		grid_position = station.grid_position
		speed = 0 # FIX: Ensure speed is reset to 0 when docked
		turns_docked_since_action = 0
		return true
	return false
		
func undock():
	if is_instance_valid(docked_host):
		docked_host.docked_guests.erase(self)
	
	is_docked = false
	docked_host = null
	turns_docked_since_action = 0
	
	if ship_class in ["Fighter", "Assault Scout"] and not is_destroyed:
		visible = true

func rearm_assault_rockets() -> bool:
	if not is_docked or not is_instance_valid(docked_host) or turns_docked_since_action < 1:
		return false
	if ship_class not in ["Fighter", "Assault Scout"]:
		return false
	if docked_host.rearm_capacity <= 0:
		return false

	var rearmed = false
	for w in weapons:
		if w["type"] == "Rocket":
			w["ammo"] = w["max_ammo"]
			rearmed = true
	
	if rearmed:
		docked_host.rearm_capacity -= 1
		turns_docked_since_action = 0 # Reset the timer if another action is needed
		return true
	return false

func get_texture() -> Texture2D:
	match ship_class:
		"Fighter":
			if faction == "Sathar": return texture_sathar_fighter
			return texture_fighter
		"Assault Scout":
			# if faction == "Sathar": return texture_sathar_assault_scout # Missing asset?
			return texture_assault_scout
		"Frigate":
			if faction == "Sathar": return texture_sathar_frigate
			return texture_frigate
		"Minelayer":
			if faction == "Sathar": return texture_sathar_frigate
			return texture_upf_minelayer
		"Destroyer":
			if faction == "Sathar": return texture_sathar_destroyer
			return texture_upf_destroyer
		"Light Cruiser":
			if faction == "Sathar": return texture_sathar_light_cruiser
			return texture_upf_light_cruiser
		"Heavy Cruiser":
			if faction == "Sathar": return texture_sathar_heavy_cruiser
			return texture_upf_heavy_cruiser
		"Battleship":
			if faction == "Sathar": return null # No asset yet
			return texture_upf_battleship
		"Assault Carrier":
			if faction == "Sathar": return texture_sathar_assault_carrier
			return texture_upf_assault_carrier
		"Civilian":
			var hash_val = self.name.hash() % 3
			if hash_val == 1: return texture_civilian_2
			elif hash_val == 2: return texture_civilian_3
			return texture_civilian_1
		"Shuttle":
			return texture_shuttle
		"Space Station", "Armed Station", "Fortified Station", "Space Station (Fortress)":
			return texture_space_station
	return texture_fighter # Fallback

func draw_sprite_custom(canvas: CanvasItem, pos: Vector2, facing_dir: int, alpha: float):
	var tex = get_texture()
	if not tex and ship_class == "Battleship" and faction == "Sathar":
		# Fallback vector for Sathar BB
		var size = HexGrid.TILE_SIZE * 0.85
		var points = PackedVector2Array([
			Vector2(size, 0),
			Vector2(-size * 0.8, -size * 0.4),
			Vector2(-size * 0.5, 0),
			Vector2(-size * 0.8, size * 0.4)
		])
		var color_mod = Color.WEB_GRAY if (max_hull > 0 and hull <= 0) else color
		color_mod.a = alpha
		
		var draw_angle = facing_dir * (PI / 3.0) + (PI / 2.0)
		canvas.draw_set_transform(pos, draw_angle, Vector2.ONE)
		canvas.draw_colored_polygon(points, color_mod)
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return

	if not tex: return

	var target_size = HexGrid.TILE_SIZE
	match ship_class:
		"Shuttle": target_size = HexGrid.TILE_SIZE * 0.4
		"Fighter": target_size = HexGrid.TILE_SIZE * 0.6
		"Assault Scout": target_size = HexGrid.TILE_SIZE * 0.7
		"Frigate", "Minelayer": target_size = HexGrid.TILE_SIZE * 0.9
		"Civilian": target_size = HexGrid.TILE_SIZE * 1.0
		"Destroyer": target_size = HexGrid.TILE_SIZE * 1.1
		"Light Cruiser": target_size = HexGrid.TILE_SIZE * 1.25
		"Heavy Cruiser": target_size = HexGrid.TILE_SIZE * 1.4
		"Battleship": target_size = HexGrid.TILE_SIZE * 1.7
		"Assault Carrier": target_size = HexGrid.TILE_SIZE * 2.0
		"Space Station", "Armed Station", "Fortified Station", "Space Station (Fortress)":
			var hp_scale_bonus = float(max_hull) / 200.0
			target_size = HexGrid.TILE_SIZE * (1.0 + hp_scale_bonus)

	var ref_size = max(tex.get_width(), tex.get_height())
	var s = target_size / ref_size
	var scale_vec = Vector2(s, s)
	
	var draw_angle = facing_dir * (PI / 3.0) + (PI / 2.0)
	var tex_size = tex.get_size()
	var rect = Rect2(-tex_size / 2, tex_size)
	
	var color_mod = Color(1, 1, 1, alpha)
	
	canvas.draw_set_transform(pos, draw_angle, scale_vec)
	canvas.draw_texture_rect(tex, rect, false, color_mod)
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
