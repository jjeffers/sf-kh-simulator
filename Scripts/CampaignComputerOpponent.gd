class_name CampaignComputerOpponent
extends Node

var campaign: Node
var faction: String
var rng: RandomNumberGenerator

var _process_timer: Timer

func _init(p_faction: String = ""):
	faction = p_faction
	rng = RandomNumberGenerator.new()
	rng.randomize()

func _ready():
	campaign = get_parent()
	_process_timer = Timer.new()
	_process_timer.one_shot = true
	_process_timer.timeout.connect(_on_think_timeout)
	add_child(_process_timer)

func _process(_delta):
	# Wait until UI is stable
	if not is_instance_valid(campaign) or not campaign.is_inside_tree():
		return
		
	var current_scene = get_tree().current_scene
	if not current_scene or current_scene.scene_file_path != "res://Scenes/CampaignMap.tscn":
		return
		
	# Skip if not our turn or if already ready
	if _has_finished_turn():
		return
		
	# Quick exit if waiting on simulated thinking delay
	if not _process_timer.is_stopped():
		return
		
	_think(1.0)

func _has_finished_turn() -> bool:
	if not is_instance_valid(campaign): return true
	if faction == "UPF":
		return campaign.upf_ready
	else:
		return campaign.sathar_ready

func _think(wait_time: float):
	if OS.has_feature("test"):
		wait_time = 0.05
	_process_timer.start(wait_time)

func _on_think_timeout():
	if not is_instance_valid(campaign): return
	
	if _has_finished_turn():
		return
		
	ConsoleManager.log_message("[color=gray]Campaign AI (%s) evaluating turn...[/color]" % faction)
	
	_execute_repairs()
	_execute_movement()
	_evaluate_encounters()
	
	var wait_time = 0.5
	if OS.has_feature("test"):
		wait_time = 0.05
	await get_tree().create_timer(wait_time).timeout
	
	if not is_instance_valid(campaign): return
	
	if campaign.active_encounters.size() > 0:
		return
	
	# Pass turn
	ConsoleManager.log_message("[color=yellow]Campaign AI (%s) is ending its turn.[/color]" % faction)
	if campaign.multiplayer.has_multiplayer_peer() and not campaign.multiplayer.is_server():
		campaign.request_end_turn.rpc_id(1, faction)
	else:
		campaign.request_end_turn(faction)

# --- PHASE 1: REPAIRS ---
func _execute_repairs():
	# Finds any critical ships in SCCs and triggers repair logic
	var sccs = []
	for sid in campaign.systems.keys():
		var sys = campaign.systems[sid]
		if faction == "UPF" and (sid in campaign.UPF_STARSHIP_CONSTRUCTION_CENTERS or sid in campaign.UPF_FORTRESSES):
			sccs.append(sid)
		elif faction == "Sathar" and (sid in campaign.UPF_STARSHIP_CONSTRUCTION_CENTERS) and sys.get("occupying_faction", "") == "Sathar":
			sccs.append(sid)
			
	if sccs.size() == 0: return

	for fleet in campaign.fleets:
		if fleet.faction == faction and not fleet.is_moving() and sccs.has(fleet.current_system_id):
			if faction == "UPF":
				_process_upf_repairs(fleet)
			else:
				_process_sathar_repairs(fleet)
				
func _process_upf_repairs(fleet):
	var sys_id = fleet.current_system_id
	var cap = campaign.UPF_SCC_CAPACITIES.get(sys_id, 0)
	var used = campaign.upf_scc_capacity_used.get(sys_id, 0)
	var avail = cap - used
	
	for s in fleet.ships:
		if avail >= cap: # Could fix critical system
			var fixed_sys = false
			if s.get("unrepairable_adf_modifier", 0) > 0:
				s["unrepairable_adf_modifier"] -= 1
				fixed_sys = true
			elif s.get("unrepairable_mr_modifier", 0) > 0:
				s["unrepairable_mr_modifier"] -= 1
				fixed_sys = true
			elif s.get("unrepairable_electrical_fire", false):
				s["unrepairable_electrical_fire"] = false
				fixed_sys = true
			elif s.get("unrepairable_disastrous_fire", false):
				s["unrepairable_disastrous_fire"] = false
				fixed_sys = true
			elif s.get("unrepairable_ccs", false):
				s["unrepairable_ccs"] = false
				fixed_sys = true
			elif s.get("unrepairable_icm", false):
				s["unrepairable_icm"] = false
				fixed_sys = true
			elif s.get("unrepairable_ms", false):
				s["unrepairable_ms"] = false
				fixed_sys = true
			else:
				if s.has("weapons"):
					for w in s["weapons"]:
						if w.get("unrepairable", false):
							w["unrepairable"] = false
							w["is_crippled"] = false
							fixed_sys = true
							break
			if fixed_sys:
				used += cap
				avail -= cap
				campaign.upf_scc_capacity_used[sys_id] = used
				ConsoleManager.log_message("[color=green]UPF AI completely overhauled critical damage on %s at %s.[/color]" % [s.get("name", "Ship"), sys_id])
				continue
		
		var hp = s.get("hull", s.get("max_hull", 100))
		var m_hp = s.get("max_hull", 100)
		if hp < m_hp and avail > 0 and not s.get("unrepairable_hull", false):
			var needed = m_hp - hp
			var restored = min(needed, avail)
			s["hull"] = hp + restored
			used += restored
			avail -= restored
			campaign.upf_scc_capacity_used[sys_id] = used
			ConsoleManager.log_message("[color=green]UPF AI repaired %d hull points on %s at %s.[/color]" % [restored, s.get("name", "Ship"), sys_id])

func _process_sathar_repairs(fleet):
	var indices_to_remove = []
	var sys_id = fleet.current_system_id
	
	for i in range(fleet.ships.size()):
		var s = fleet.ships[i]
		var hp = s.get("hull", s.get("max_hull", 100))
		var m_hp = s.get("max_hull", 100)
		var is_critical = false
		
		is_critical = s.get("unrepairable_adf_modifier", 0) > 0 or s.get("unrepairable_mr_modifier", 0) > 0
		if not is_critical and s.has("weapons"):
			for w in s["weapons"]:
				if w.get("unrepairable", false):
					is_critical = true
					break
					
		if is_critical or (m_hp > 0 and (float(hp) / float(m_hp)) < 0.5):
			campaign.sathar_repair_queue.append({
				"fleet_name": fleet.fleet_name,
				"ship": s,
				"days_remaining": 6,
				"system_id": sys_id
			})
			indices_to_remove.append(i)
			ConsoleManager.log_message("[color=green]Sathar AI queued %s at %s for 6 days of SCC repairs.[/color]" % [s.get("name", "Ship"), sys_id])
			
	# Remove ships ordered by highest index to avoid shifting
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for idx in indices_to_remove:
		fleet.ships.remove_at(idx)
		
	if fleet.ships.size() == 0:
		campaign.remove_fleet(fleet)
		
# --- PHASE 2: MOVEMENT ---
func _execute_movement():
	var idle_fleets = []
	for f in campaign.fleets:
		if f.faction == faction and not f.is_moving():
			idle_fleets.append(f)
			
	for fleet in idle_fleets:
		var target_id = _find_strategic_target(fleet)
		if target_id and target_id != fleet.current_system_id:
			var path = _find_path(fleet.current_system_id, target_id)
			if path.size() > 1:
				var move_to = path[1] # Next system in path
				campaign.order_fleet_move(fleet, move_to)
				ConsoleManager.log_message("AI ordered fleet %s to move toward %s (next stop %s)." % [fleet.fleet_name, target_id, move_to])

func _find_strategic_target(fleet) -> String:
	# Simplified A* heuristic for high value targets
	var start = fleet.current_system_id
	var best_target = start
	var best_score = -9999.0
	
	if faction == "Sathar":
		# Seek UPF Fortresses and SCCs
		var min_dist = 999
		for sid in campaign.systems.keys():
			var sys = campaign.systems[sid]
			if sid in campaign.UPF_STARSHIP_CONSTRUCTION_CENTERS or sid in campaign.UPF_FORTRESSES:
				var path = _find_path(start, sid)
				if path.size() > 0 and path.size() < min_dist:
					min_dist = path.size()
					best_target = sid
					best_score = 1000.0 - min_dist
	else:
		# UPF looks for Sathar fleets
		var min_dist = 999
		for e_fleet in campaign.fleets:
			if e_fleet.faction != faction:
				var e_sys = e_fleet.current_system_id if not e_fleet.is_moving() else e_fleet.destination_system_id
				if e_sys:
					var path = _find_path(start, e_sys)
					if path.size() > 0 and path.size() < min_dist:
						min_dist = path.size()
						best_target = e_sys
						best_score = 500.0 - min_dist
		
		# If no imminent targets, fall back to SCCs
		if best_score < 0:
			var best_scc_dist = 999
			for sid in campaign.systems.keys():
				var sys = campaign.systems[sid]
				if (sid in campaign.UPF_FORTRESSES) or (sid in campaign.UPF_STARSHIP_CONSTRUCTION_CENTERS):
					var path = _find_path(start, sid)
					if path.size() > 0 and path.size() < best_scc_dist:
						best_scc_dist = path.size()
						best_target = sid
						
	return best_target

func _find_path(start: String, end: String) -> Array:
	if start == end: return [start]
	
	# Basic Breadth First Search since graph is small and unweighted (for jumps)
	var queue = [[start]]
	var visited = {start: true}
	
	while queue.size() > 0:
		var path = queue.pop_front()
		var node = path.back()
		
		if node == end:
			return path
			
		if campaign.systems.has(node) or node.begins_with("Start Circle"):
			var connections = campaign._get_connected_systems(node)
			for neighbor in connections:
				if not visited.has(neighbor):
					visited[neighbor] = true
					var new_path = path.duplicate()
					new_path.append(neighbor)
					queue.append(new_path)
					
	return [] # No path found

# --- PHASE 3: ENCOUNTERS ---
func _evaluate_encounters():
	for attacking_sys in campaign.active_encounters:
		# Can only evaluate if this faction is actually present
		var am_present = false
		for f in campaign.fleets:
			if f.faction == faction and f.current_system_id == attacking_sys and not f.is_moving():
				am_present = true
				break
				
		var has_station = false
		if faction == "UPF" and (campaign.UPF_FORTRESSES.has(attacking_sys) or campaign.UPF_ARMED_STATIONS.has(attacking_sys)):
			am_present = true
			has_station = true
			
		if not am_present:
			continue
			
		var attacker = campaign.encounter_attackers.get(attacking_sys, "Both")
		var is_attacker = (attacker == faction or attacker == "Both")
		
		# Assess advantage if UPF is fighting
		if faction == "UPF":
			var car = _evaluate_campaign_advantage(attacking_sys)
			if car < 0.3 and not has_station:  # Can't retreat stations
				# Try to retreat
				var my_fleets = []
				for f in campaign.fleets:
					if f.faction == faction and f.current_system_id == attacking_sys and not f.is_moving():
						my_fleets.append(f)
						
				if my_fleets.size() > 0:
					var retreat_sys = _find_safe_retreat_location(attacking_sys)
					if retreat_sys != "":
						for f in my_fleets:
							campaign.order_fleet_move(f, retreat_sys)
						ConsoleManager.log_message("[color=orange]UPF AI tactical retreat from %s ordered to %s![/color]" % [attacking_sys, retreat_sys])
						continue # We retreated, don't confirm readiness
						
		# If we didn't retreat, we must engage
		if is_attacker:
			if campaign.multiplayer.has_multiplayer_peer():
				if not campaign.multiplayer.is_server():
					campaign.rpc_open_encounter_dialog.rpc_id(1, attacking_sys)
				else:
					campaign.rpc_open_encounter_dialog.rpc(attacking_sys)
			else:
				campaign.rpc_open_encounter_dialog(attacking_sys)
				
		# Automatically confirm readiness for bots
		if campaign.multiplayer.has_multiplayer_peer():
			if campaign.multiplayer.is_server():
				campaign.set_encounter_ready(attacking_sys, faction, true)
			else:
				campaign.set_encounter_ready.rpc_id(1, attacking_sys, faction, true)
		else:
			campaign.set_encounter_ready(attacking_sys, faction, true)

func _evaluate_campaign_advantage(sys_id: String) -> float:
	var my_power = 0.0
	var enemy_power = 0.0
	
	for f in campaign.fleets:
		if f.current_system_id == sys_id and not f.is_moving():
			var power = 0.0
			for s in f.ships:
				power += s.get("hull", s.get("max_hull", 100))
			if f.faction == faction:
				my_power += power
			else:
				enemy_power += power
				
	# Include stations
	if faction == "UPF" and (campaign.UPF_FORTRESSES.has(sys_id) or campaign.UPF_ARMED_STATIONS.has(sys_id)):
		my_power += 200.0 # arbitrary station value
	elif faction == "Sathar" and (campaign.UPF_FORTRESSES.has(sys_id) or campaign.UPF_ARMED_STATIONS.has(sys_id)):
		enemy_power += 200.0
			
	if enemy_power <= 0: return 999.0
	return my_power / enemy_power

func _find_safe_retreat_location(sys_id: String) -> String:
	if not campaign.systems.has(sys_id): return ""
	var neighbors = campaign.systems[sys_id].get("connections", [])
	
	for n in neighbors:
		var is_safe = true
		for f in campaign.fleets:
			if f.current_system_id == n and f.faction != faction and not f.is_moving():
				is_safe = false
				break
		if is_safe:
			return n
			
	# If no truly safe, return the first one
	if neighbors.size() > 0: return neighbors[0]
	return ""
