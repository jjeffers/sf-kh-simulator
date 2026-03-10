class_name Combat
extends Node

static var combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()

const BASE_HIT_CHANCE = 80
const RANGE_PENALTY = 5 # per hex
const MAX_RANGE = 10

# ICM Modifiers
const ICM_MODIFIER_TORPEDO = 10
const ICM_MODIFIER_ASSAULT_ROCKET = 5
const ICM_MODIFIER_ROCKET_BATTERY = 3
const ICM_MODIFIER_MINE = 8
const ICM_MODIFIER_SEEKER = 8

static func calculate_icm_reduction(weapon_type: String, icm_count: int) -> int:
	if icm_count <= 0: return 0
	
	var reduction_per_missile = 0
	match weapon_type:
		"Torpedo": reduction_per_missile = ICM_MODIFIER_TORPEDO
		"Rocket": reduction_per_missile = ICM_MODIFIER_ASSAULT_ROCKET
		"Rocket Battery": reduction_per_missile = ICM_MODIFIER_ROCKET_BATTERY
		"Mine": reduction_per_missile = ICM_MODIFIER_MINE
		"Seeker": reduction_per_missile = ICM_MODIFIER_SEEKER
		_: return 0
		
	return icm_count * reduction_per_missile

static func calculate_hit_chance(dist: int, weapon: Dictionary = {}, target: Ship = null, is_head_on: bool = false, icm_count: int = 0, source: Ship = null) -> int:
	var chance = 0
	var w_type = weapon.get("type")
	
	# Special Rule: Rockets are FLAT (Ignore Range Penalty)
	if w_type == "Rocket":
		chance = 80
		# VS Reflective Hull (RH)
		if target and target.defense == "RH":
			chance = 60
			
		if is_head_on: chance += 10
		if icm_count > 0: chance -= calculate_icm_reduction("Rocket", icm_count)
		return max(0, chance)

	# Special Rule: Torpedo (Flat 70%)
	# "70% chance to hit any target"
	if weapon.get("type") == "Torpedo":
		chance = 70
		if is_head_on: chance += 10
		if icm_count > 0: chance -= calculate_icm_reduction("Torpedo", icm_count)
		return max(0, chance)
	
	# Special Rule: Rocket Battery (Flat 40%)
	if weapon.get("type") == "Rocket Battery":
		chance = 40
		if is_head_on: chance += 10
		if icm_count > 0: chance -= calculate_icm_reduction("Rocket Battery", icm_count)
		return max(0, chance)
		
	# Special Rule: Mine (Flat 60%, 80% vs SS)
	if weapon.get("type") == "Mine":
		chance = 60
		# VS Stasis Screen (SS)
		if target and (target.get("active_screen") == "SS" or (target.defense == "SS" and target.get("active_screen") != "MS")):
			# Actually, RULES.md says SS = 80%. Let's check active defense logic.
			pass # We'll handle it below for clarity, or just do it here:
		var active_def = "None"
		if target:
			if target.get("is_ms_active"): active_def = "MS"
			elif target.get("active_screen") and target.get("active_screen") != "None": active_def = target.get("active_screen")
			elif target.defense == "RH": active_def = "RH"
		
		if active_def == "SS":
			chance = 80
			
		# Head-on does not apply to Mines per RULES.md (they are stationary/0 range)
		if icm_count > 0: chance -= calculate_icm_reduction("Mine", icm_count)
		return max(0, chance)
		
	# Special Rule: Seeker (Flat 75%, 90% vs SS)
	if weapon.get("type") == "Seeker":
		chance = 75
		# VS Stasis Screen (SS)
		var active_def = "None"
		if target:
			if target.get("is_ms_active"): active_def = "MS"
			elif target.get("active_screen") and target.get("active_screen") != "None": active_def = target.get("active_screen")
			elif target.defense == "RH": active_def = "RH"
		
		if active_def == "SS":
			chance = 90
			
		# Head-on does not apply to Seekers per RULES.md (they are autonomous missiles from random facings)
		if icm_count > 0: chance -= calculate_icm_reduction("Seeker", icm_count)
		return max(0, chance)
	
	# Base Chance Calculation and Target Defenses (RULES.md)
	var base = 65 # Default fallback
	var w_type_full = weapon.get("type", "")
	
	match w_type_full:
		"Laser":
			base = 65
		"Laser Canon":
			base = 75
		"Electron Beam Battery":
			base = 60
		"Proton Beam Battery":
			base = 60
		"Disruptor Cannon", "Disruptor Canon": # Handle string matching
			base = 60
			
	# Apply Defenses (Base modifier)
	var active_defense = "None"
	if target:
		if target.get("is_ms_active"):
			active_defense = "MS" # MS overrides others in practice
		elif target.get("active_screen") and target.get("active_screen") != "None":
			active_defense = target.get("active_screen")
		elif target.defense == "RH": # Fallback to RH if no active screen/MS
			active_defense = "RH"
			
	match active_defense:
		"RH":
			match w_type_full:
				"Laser": base = 50
				"Laser Canon": base = 60
				"Electron Beam Battery": base = 60
				"Proton Beam Battery": base = 60
				"Disruptor Cannon", "Disruptor Canon": base = 60
		"PS":
			match w_type_full:
				"Laser": base = 65
				"Laser Canon": base = 75
				"Electron Beam Battery": base = 25
				"Proton Beam Battery": base = 70
				"Disruptor Cannon", "Disruptor Canon": base = 50
		"ES":
			match w_type_full:
				"Laser": base = 65
				"Laser Canon": base = 75
				"Electron Beam Battery": base = 70
				"Proton Beam Battery": base = 26
				"Disruptor Cannon", "Disruptor Canon": base = 50
		"SS":
			match w_type_full:
				"Laser": base = 65
				"Laser Canon": base = 25
				"Electron Beam Battery": base = 40
				"Proton Beam Battery": base = 40
				"Disruptor Cannon", "Disruptor Canon": base = 40
		"MS":
			match w_type_full:
				"Laser": base = 20
				"Laser Canon": base = 0
				"Electron Beam Battery": base = 50
				"Proton Beam Battery": base = 50
				"Disruptor Cannon", "Disruptor Canon": base = 50

	
	# Standard / Laser / Laser Canon Rule: Range Diffusion (RD)
	# -5% per hex
	if w_type_full in ["Laser", "Laser Canon", "Electron Beam Battery", "Proton Beam Battery", "Disruptor Cannon", "Disruptor Canon"]:
		chance = base - (dist * RANGE_PENALTY)
	else:
		chance = base # Should not happen given early returns for Rockets/Torpedoes, but safe fallback
		
	if is_head_on: chance += 10
	
	# Apply ICM reduction for any falling-through weapons (e.g. Assault Rocket vs non-RH)
	# Apply ICM reduction for any falling-through weapons (e.g. Assault Rocket vs non-RH)
	if icm_count > 0:
		chance -= calculate_icm_reduction(weapon.get("type", ""), icm_count)
		
	# CCS / Disastrous Fire Penalty
	# "-10% on all attacks"
	if source:
		if source.get("ccs_damaged") or source.get("has_disastrous_fire"):
			chance -= 10
		
	return max(0, chance)

# Returns the best hex along a target's previous path for reactive fire { "chance": int, "hex": Vector3i, "distance": int, "is_head_on": bool }
static func get_best_defensive_fire_hex(source: Ship, target: Ship, weapon: Dictionary, icm_count: int = 0) -> Dictionary:
	var best_chance = -1
	var best_hex = target.grid_position
	# Fallback distance
	var best_dist = -1 # Will be set in loop, or safely defaults
	var best_head_on = false
	
	# The possible hexes are the current position AND all hexes in previous_path
	var possible_hexes = [target.grid_position]
	possible_hexes.append_array(target.previous_path)
	
	for hex in possible_hexes:
		# Assuming HexGrid is an Autoload or Globally accessible Class
		var dist = HexGrid.hex_distance(source.grid_position, hex)
		
		var is_head_on = false
		if weapon.get("arc") == "FF":
			if hex == source.grid_position:
				is_head_on = true
			else:
				var fwd_vec = HexGrid.get_direction_vec(source.facing)
				var check = source.grid_position + fwd_vec
				for i in range(weapon.get("range", 0)):
					if check == hex:
						is_head_on = true
						break
					check += fwd_vec
					
		var chance = calculate_hit_chance(dist, weapon, target, is_head_on, icm_count, source)
		
		# Better chance, or identical chance but closer (edge case) tie breaker? 
		# We'll just take the strictly better chance, or if chance is same, it doesn't matter much.
		# Let's say if chance is same, we might want the closest distance just for logic? 
		# Just strictly > best_chance is enough, it will take the first best spot chronologically (since path is ordered).
		if chance > best_chance:
			best_chance = chance
			best_hex = hex
			best_dist = dist
			best_head_on = is_head_on
			
	return {
		"chance": best_chance,
		"hex": best_hex,
		"distance": best_dist,
		"is_head_on": best_head_on
	}

# Returns result dict: {success: bool, chance: int, roll: int}
static func get_hit_roll_details(dist: int, weapon: Dictionary = {}, target: Ship = null, is_head_on: bool = false, icm_count: int = 0, source: Ship = null) -> Dictionary:
	var chance = calculate_hit_chance(dist, weapon, target, is_head_on, icm_count, source)
	var roll = combat_rng.randi() % 100 + 1 # 1-100
	print("Combat Roll: Distance %d, Chance %d%%, Rolled %d" % [dist, chance, roll])
	return {
		"success": roll <= chance,
		"chance": chance,
		"roll": roll
	}

# Returns true if hit (Legacy wrapper)
static func roll_for_hit(dist: int, weapon: Dictionary = {}, target: Ship = null, is_head_on: bool = false, icm_count: int = 0, source: Ship = null) -> bool:
	var res = get_hit_roll_details(dist, weapon, target, is_head_on, icm_count, source)
	return res["success"]

# Returns damage amount from string "2d10+4" or simple int
static func roll_damage(damage_str: Variant = "1d10") -> int:
	if typeof(damage_str) == TYPE_INT:
		return damage_str
		
	if typeof(damage_str) == TYPE_STRING:
		# Parse "2d10+4"
		var parts = damage_str.split("+")
		var bonus = 0
		if parts.size() > 1:
			bonus = int(parts[1])
			
		var dice_part = parts[0].split("d")
		if dice_part.size() == 2:
			var count = int(dice_part[0])
			var sides = int(dice_part[1])
			var total = 0
			for i in range(count):
				total += combat_rng.randi() % sides + 1
			print("Damage Roll: %s -> %d" % [damage_str, total + bonus])
			return total + bonus
			
	return 1 # Fallback

# --- Damage System ---

static func calculate_damage_roll(dtm: int) -> int:
	var roll = (combat_rng.randi() % 100) + 1
	var total = roll + dtm
	print("Damage Roll: d100(%d) + DTM(%d) = %d" % [roll, dtm, total])
	return total

static func get_damage_effect(roll: int) -> Dictionary:
	if roll <= 10: return {"type": "Hull", "mult": 2.0, "text": "CRITICAL HULL HIT (x2)"}
	if roll <= 45: return {"type": "Hull", "mult": 1.0, "text": "Hull Hit"}
	if roll <= 49: return {"type": "ADF", "val": - 1, "text": "Drive Hit (-1 ADF)"}
	if roll <= 52: return {"type": "ADF", "val": - 0.5, "text": "Drive Hit (-1/2 ADF)"}
	if roll <= 53: return {"type": "ADF", "val": - 99, "text": "Drive Hit (All ADF)"}
	if roll <= 58: return {"type": "MR", "val": - 1, "text": "Steering Hit (-1 MR)"}
	if roll <= 60: return {"type": "MR", "val": - 99, "text": "Steering Hit (All MR)"}
	
	# Weapon Hits
	if roll <= 62: return {"type": "Weapon", "list": ["Laser Canon", "Laser", "Proton Beam Battery", "Electron Beam Battery", "Rocket", "Rocket Battery"], "text": "Weapon Hit"}
	if roll <= 64: return {"type": "Weapon", "list": ["Proton Beam Battery", "Electron Beam Battery", "Laser", "Rocket Battery", "Torpedo", "Rocket"], "text": "Weapon Hit"}
	if roll <= 66: return {"type": "Weapon", "list": ["Disruptor Canon", "Laser Canon", "Rocket", "Torpedo", "Laser"], "text": "Weapon Hit"}
	if roll <= 68: return {"type": "Weapon", "list": ["Torpedo", "Rocket", "Electron Beam Battery", "Proton Beam Battery", "Laser", "Rocket Battery"], "text": "Weapon Hit"}
	if roll <= 70: return {"type": "Weapon", "list": ["Laser", "Rocket Battery", "Torpedo", "Rocket", "Proton Beam Battery", "Electron Beam Battery", "Laser Canon", "Disruptor Canon"], "text": "Weapon Hit"}
	
	if roll <= 74: return {"type": "System", "key": "ICM", "text": "Power Short Circuit (Lose ICMs)"}
	if roll <= 77: return {"type": "Defense", "list": ["PS", "ES", "SS", "MS", "ICM"], "text": "Defense Hit (PS, ES, SS, MS, ICM)"}
	if roll <= 80: return {"type": "Defense", "list": ["MS", "ICM", "SS", "PS", "ES"], "text": "Defense Hit (MS, ICM, SS, PS, ES)"}
	if roll <= 84: return {"type": "Defense", "list": ["ICM", "SS", "PS", "ES", "MS"], "text": "Defense Hit (ICM, SS, PS, ES, MS)"}
	
	if roll <= 91: return {"type": "System", "key": "CCS", "text": "Combat Control System Hit (-10% Hit Chance)"}
	if roll <= 97: return {"type": "Navigation", "text": "Navigation Hit (ADF=0, MR=0)"}
	if roll <= 116: return {"type": "Fire", "key": "Electrical", "text": "ELECTRICAL FIRE! (+20 Dmg/Turn)"}
	return {"type": "Fire", "key": "Disastrous", "text": "DISASTROUS FIRE! (+20 Dmg/Turn, Crippled)"}
