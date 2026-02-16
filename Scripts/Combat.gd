class_name Combat
extends Node

const BASE_HIT_CHANCE = 80
const RANGE_PENALTY = 5 # per hex
const MAX_RANGE = 10

# ICM Modifiers
const ICM_MODIFIER_TORPEDO = 10
const ICM_MODIFIER_ASSAULT_ROCKET = 5
const ICM_MODIFIER_ROCKET_BATTERY = 3

static func calculate_icm_reduction(weapon_type: String, icm_count: int) -> int:
	if icm_count <= 0: return 0
	
	var reduction_per_missile = 0
	match weapon_type:
		"Torpedo": reduction_per_missile = ICM_MODIFIER_TORPEDO
		"Rocket": reduction_per_missile = ICM_MODIFIER_ASSAULT_ROCKET
		"Rocket Battery": reduction_per_missile = ICM_MODIFIER_ROCKET_BATTERY
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
	
	# Base Chance Calculation
	var base = BASE_HIT_CHANCE # 80
	
	# Masking Screen Logic (Defense & Reciprocal)
	var target_has_ms = (target and target.get("is_ms_active"))
	var source_has_ms = (source and source.get("is_ms_active"))
	
	if (target_has_ms or source_has_ms) and (weapon.get("type") == "Laser" or weapon.get("type") == "Laser Canon"):
		# Override Base for Laser weapons
		if weapon.get("type") == "Laser Canon":
			base = 20
		else:
			base = 10 # Battery
	else:
		# Standard Laser vs Reflective Hull (RH) only if NO Screen (Screen overrides RH?)
		# Usually defensive systems don't stack poorly, but Prompt says "reduce the base chance... to 20%".
		# This strongly implies replacement.
		if target and target.defense == "RH":
			if weapon.get("type") == "Laser":
				base = 50
			elif weapon.get("type") == "Laser Canon":
				base = 60 # "60% chance to hit a target with a reflective hull"

	
	# Standard / Laser / Laser Canon Rule: Range Diffusion (RD)
	# -5% per hex
	# ONLY if type is Laser or Laser Canon
	if w_type == "Laser" or w_type == "Laser Canon":
		chance = base - (dist * RANGE_PENALTY)
	else:
		chance = base # Should not happen given early returns for Rockets/Torpedoes, but safe fallback
		
	if is_head_on: chance += 10
	
	# Apply ICM reduction for any falling-through weapons (e.g. Assault Rocket vs non-RH)
	if icm_count > 0:
		chance -= calculate_icm_reduction(weapon.get("type", ""), icm_count)
		
	return max(0, chance)

# Returns result dict: {success: bool, chance: int, roll: int}
static func get_hit_roll_details(dist: int, weapon: Dictionary = {}, target: Ship = null, is_head_on: bool = false, icm_count: int = 0, source: Ship = null) -> Dictionary:
	var chance = calculate_hit_chance(dist, weapon, target, is_head_on, icm_count, source)
	var roll = randi() % 100 + 1 # 1-100
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
				total += randi() % sides + 1
			print("Damage Roll: %s -> %d" % [damage_str, total + bonus])
			return total + bonus
			
	return 1 # Fallback

# --- Damage System ---

static func calculate_damage_roll(dtm: int) -> int:
	var roll = (randi() % 100) + 1
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
	if roll <= 62: return {"type": "Weapon", "list": ["Laser Canon", "Laser", "Rocket", "Rocket Battery"], "text": "Weapon Hit"}
	if roll <= 64: return {"type": "Weapon", "list": ["Laser", "Rocket Battery", "Torpedo", "Rocket"], "text": "Weapon Hit"}
	if roll <= 66: return {"type": "Weapon", "list": ["Laser Canon", "Rocket", "Torpedo", "Laser"], "text": "Weapon Hit"}
	if roll <= 68: return {"type": "Weapon", "list": ["Torpedo", "Rocket", "Laser", "Rocket Battery"], "text": "Weapon Hit"}
	if roll <= 70: return {"type": "Weapon", "list": ["Laser", "Rocket Battery", "Torpedo", "Rocket", "Laser Canon"], "text": "Weapon Hit"}
	
	if roll <= 74: return {"type": "System", "key": "ICM", "text": "Power Short Circuit (Lose ICMs)"}
	if roll <= 80: return {"type": "Defense", "list": ["MS", "ICM"], "text": "Defense Hit (MS, ICM)"}
	if roll <= 84: return {"type": "Defense", "list": ["ICM", "MS"], "text": "Defense Hit (ICM, MS)"}
	
	if roll <= 91: return {"type": "System", "key": "CCS", "text": "Combat Control System Hit (-10% Hit Chance)"}
	if roll <= 97: return {"type": "Navigation", "text": "Navigation Hit (ADF=0, MR=0)"}
	if roll <= 116: return {"type": "Fire", "key": "Electrical", "text": "ELECTRICAL FIRE! (+20 Dmg/Turn)"}
	return {"type": "Fire", "key": "Disastrous", "text": "DISASTROUS FIRE! (+20 Dmg/Turn, Crippled)"}
