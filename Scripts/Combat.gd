class_name Combat
extends Node

const BASE_HIT_CHANCE = 80
const RANGE_PENALTY = 5 # per hex
const MAX_RANGE = 10

static func calculate_hit_chance(dist: int, weapon: Dictionary = {}, target: Ship = null, is_head_on: bool = false) -> int:
	if dist > MAX_RANGE:
		return 0
		
	var chance = 0
	
	# Special Rule: Assault Rocket vs Reflective Hull (RH)
	if target and target.defense == "RH" and weapon.get("type") == "Rocket":
		chance = 60
		if is_head_on: chance += 10
		return chance

	# Special Rule: Torpedo (Flat 70%)
	# "70% chance to hit any target"
	if weapon.get("type") == "Torpedo":
		chance = 70
		if is_head_on: chance += 10 # Assuming Head-on still applies as positional bonus?
		return chance
	
	# Base Chance Calculation
	var base = BASE_HIT_CHANCE # 80
	
	# Special Rule: Laser vs Reflective Hull (RH)
	if target and target.defense == "RH":
		if weapon.get("type") == "Laser":
			base = 50
		elif weapon.get("type") == "Laser Canon":
			base = 60 # "60% chance to hit a target with a reflective hull"

	
	# Standard / Laser / Laser Canon Rule: Range Diffusion (RD)
	# -5% per hex
	chance = base - (dist * RANGE_PENALTY)
	if is_head_on: chance += 10
	return max(0, chance)

# Returns true if hit
static func roll_for_hit(dist: int, weapon: Dictionary = {}, target: Ship = null, is_head_on: bool = false) -> bool:
	var chance = calculate_hit_chance(dist, weapon, target, is_head_on)
	var roll = randi() % 100 + 1 # 1-100
	print("Combat Roll: Distance %d, Chance %d%%, Rolled %d" % [dist, chance, roll])
	return roll <= chance

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
