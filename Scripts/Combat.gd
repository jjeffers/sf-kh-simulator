class_name Combat
extends Node

const BASE_HIT_CHANCE = 80
const RANGE_PENALTY = 5 # per hex
const MAX_RANGE = 10

static func calculate_hit_chance(dist: int) -> int:
	if dist > MAX_RANGE:
		return 0
	var chance = BASE_HIT_CHANCE - (dist * RANGE_PENALTY)
	return max(0, chance)

# Returns true if hit
static func roll_for_hit(dist: int) -> bool:
	var chance = calculate_hit_chance(dist)
	var roll = randi() % 100 + 1 # 1-100
	print("Combat Roll: Distance %d, Chance %d%%, Rolled %d" % [dist, chance, roll])
	return roll <= chance

# Returns damage amount 1-10
static func roll_damage() -> int:
	return randi() % 10 + 1
