extends Node

# Evaluates incoming attacks against AI ships and decides how many ICMs they should fire.
# Returns a dictionary mapping ship_name -> total_icms_to_fire
static func calculate_allocations(weapon_type: String, current_chance: int, target, eligible_ships: Array) -> Dictionary:
	var allocations = {}
	if current_chance <= 0: return allocations
	
	# Determine Threat Profile & Thresholds
	var reduction_per_icm = 0
	var threshold = 0
	
	# Priority 1: Torpedoes
	if "Torpedo" in weapon_type:
		reduction_per_icm = 10
		threshold = 15 # Try to get hit chance under 15%
		if current_chance <= 10: return allocations # Ignore low chance shots
		
	# Priority 2: Spatial Mines
	elif "Mine" in weapon_type:
		reduction_per_icm = 8
		threshold = 15 # Try to mitigate shrapnel heavily
		if current_chance <= 15: return allocations
		
	# Priority 3: Assault Rockets
	elif "Assault Rocket" in weapon_type or "Assault" in weapon_type:
		reduction_per_icm = 5
		threshold = 30
		# If health is good, accept some risk unless chance is very high
		var hull_ratio = float(target.hull) / max(1.0, float(target.max_hull))
		if hull_ratio > 0.5 and current_chance <= 30: return allocations
		
	# Priority 4: Rocket Batteries
	elif "Rocket Battery" in weapon_type or weapon_type == "Rocket":
		reduction_per_icm = 3
		threshold = 50
		# Terrible exchange rate. Only use if critically damaged.
		var hull_ratio = float(target.hull) / max(1.0, float(target.max_hull))
		if hull_ratio > 0.25: return allocations # Absorb the damage if hull > 25%
		if current_chance <= 50: return allocations # Ignore sub-50% shots
		
	else:
		# Unknown ballistic? 
		return allocations
		
	# Calculate how many ICMs we want total for the hex
	var desired_reduction = current_chance - threshold
	# If we just need to get it to 0, that's fine too
	var needed_icms = ceil(float(desired_reduction) / float(reduction_per_icm))
	if needed_icms <= 0: return allocations
	
	# Sort eligible defenders by who has the most ICMs
	var defenders = eligible_ships.duplicate()
	defenders.sort_custom(func(a, b): return a.icm_current > b.icm_current)
	
	var icms_allocated = 0
	
	for s in defenders:
		if icms_allocated >= needed_icms: break
		if s.icm_current <= 0: continue
		
		# How many does this ship need to contribute?
		var remaining_needed = needed_icms - icms_allocated
		var contribution = min(remaining_needed, s.icm_current)
		
		if contribution > 0:
			allocations[s.name] = int(contribution)
			icms_allocated += contribution
			
	return allocations
