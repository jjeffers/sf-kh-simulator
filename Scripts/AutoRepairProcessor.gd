class_name AutoRepairProcessor
extends RefCounted

static func execute_repairs(game_manager, side_id: int):
	var allocations = {}
	
	game_manager.log_message("[color=gray]AI Auto-Repair processing for side %d[/color]" % side_id)
	
	for s in game_manager.ships:
		if not is_instance_valid(s) or s.side_id != side_id or s.is_exploding or s.hull <= 0:
			continue
			
		var dcr_avail = s.current_dcr
		if dcr_avail <= 0:
			continue
			
		var ship_allocs = {}
		
		# Gather all repairable damage keys (ignoring unrepairable)
		var damage_keys = _get_repairable_keys(s)
		if damage_keys.is_empty():
			continue
			
		# Count Fires
		var fire_count = 0
		if "fire_elec" in damage_keys: fire_count += 1
		if "fire_dis" in damage_keys: fire_count += 1
		
		# Triage Check
		var is_unsalvageable = false
		if fire_count >= s.hull and fire_count > 0:
			is_unsalvageable = true
			game_manager.log_message("[color=red]AI Triage Protocol: %s is deemed unsalvageable! Prioritizing weapon repairs.[/color]" % s.get_display_name())
			
		if is_unsalvageable:
			# Dump all DCR into weapons
			var w_keys = damage_keys.filter(func(k): return k.begins_with("wpn_"))
			w_keys.sort_custom(func(a, b): return _sort_weapons_by_utility(s, a, b))
			
			for wk in w_keys:
				if dcr_avail <= 0: break
				var alloc = min(dcr_avail, 90)
				ship_allocs[wk] = alloc
				dcr_avail -= alloc
		else:
			# Priority 1: Prevent Imminent Destruction (Fires)
			var fire_keys = ["fire_elec", "fire_dis"]
			for fk in fire_keys:
				if fk in damage_keys and dcr_avail > 0:
					var alloc = min(dcr_avail, 90)
					ship_allocs[fk] = alloc
					dcr_avail -= alloc
					
			# Priority 2: Restore Core Mobility (Engines)
			var eng_keys = damage_keys.filter(func(k): return k.begins_with("adf_") or k.begins_with("mr_"))
			for ek in eng_keys:
				if dcr_avail > 0:
					var alloc = min(dcr_avail, 90)
					ship_allocs[ek] = alloc
					dcr_avail -= alloc
					
			# Priority 3: Restore Primary Offense (Weapons)
			var w_keys = damage_keys.filter(func(k): return k.begins_with("wpn_"))
			w_keys.sort_custom(func(a, b): return _sort_weapons_by_utility(s, a, b))
			
			for wk in w_keys:
				var w_idx = int(wk.split("_")[1])
				var wpn = s.weapons[w_idx]
				
				# Check ammo for seekers
				if wpn.has("ammo") and wpn["ammo"] <= 0:
					continue
					
				if dcr_avail > 0:
					var alloc = min(dcr_avail, 90)
					ship_allocs[wk] = alloc
					dcr_avail -= alloc
					
			# Priority 4: Restore Defenses (Screens)
			var def_keys = ["ccs", "icm", "ms"]
			for dk in def_keys:
				if dk in damage_keys and dcr_avail > 0:
					var alloc = min(dcr_avail, 90)
					ship_allocs[dk] = alloc
					dcr_avail -= alloc
					
			# Priority 5: Hull patching
			if "hull" in damage_keys and dcr_avail > 0:
				var hp_needed = s.max_hull - s.hull
				var max_hull_dcr = hp_needed * 90
				var alloc = min(dcr_avail, max_hull_dcr)
				ship_allocs["hull"] = alloc
				dcr_avail -= alloc
				
		if not ship_allocs.is_empty():
			allocations[s.name] = ship_allocs
		
	# Submit to Game Manager
	game_manager.log_message("AI Submitting Repairs...")
	if game_manager.has_method("rpc_submit_repair_allocations"):
		if game_manager.multiplayer.has_multiplayer_peer() and not game_manager.multiplayer.is_server():
			game_manager.rpc_id(1, "rpc_submit_repair_allocations", side_id, allocations)
		else:
			game_manager.rpc_submit_repair_allocations(side_id, allocations)

static func _get_repairable_keys(s) -> Array:
	var keys = []
	if s.hull < s.max_hull: keys.append("hull")
	
	var rep_adf = s.current_adf_modifier - s.unrepairable_adf_modifier
	for i in range(rep_adf):
		keys.append("adf_%d" % i)
		
	var rep_mr = s.current_mr_modifier - s.unrepairable_mr_modifier
	for i in range(rep_mr):
		keys.append("mr_%d" % i)
		
	if s.has_electrical_fire and not s.unrepairable_electrical_fire: keys.append("fire_elec")
	if s.has_disastrous_fire and not s.unrepairable_disastrous_fire: keys.append("fire_dis")
	if s.ccs_damaged and not s.unrepairable_ccs: keys.append("ccs")
	
	if s.icm_max < s.base_icm_max and not s.unrepairable_icm: keys.append("icm")
	if s.ms_max < s.base_ms_max and not s.unrepairable_ms: keys.append("ms")
	
	for i in range(s.weapons.size()):
		if s.weapons[i].get("is_crippled", false) and not s.weapons[i].get("unrepairable", false):
			keys.append("wpn_%d" % i)
	
	return keys

static func _sort_weapons_by_utility(s, key_a: String, key_b: String) -> bool:
	var idx_a = int(key_a.split("_")[1])
	var idx_b = int(key_b.split("_")[1])
	
	var wpn_a = s.weapons[idx_a]
	var wpn_b = s.weapons[idx_b]
	
	var util_a = _get_weapon_utility(wpn_a)
	var util_b = _get_weapon_utility(wpn_b)
	
	return util_a > util_b

static func _get_weapon_utility(wpn: Dictionary) -> float:
	var utility = 0.0
	var damage_dice = wpn.get("damage_dice", 1)
	var max_range = wpn.get("max_range", 0)
	utility = (damage_dice * 5.0) + max_range
	if wpn.get("ammo", 1) <= 0:
		utility = -999.0
	return utility
