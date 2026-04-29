class_name ComputerOpponent
extends Node

var game_manager: GameManager
var side_id: int = 0
var is_sathar: bool = false
var rng: RandomNumberGenerator

var _process_timer: Timer
var _is_waiting_for_transition: bool = false
var _flight_leader_targets: Dictionary = {}

func _init():
	rng = RandomNumberGenerator.new()
	rng.randomize()

func _ready():
	_process_timer = Timer.new()
	_process_timer.one_shot = true
	_process_timer.timeout.connect(_on_think_timeout)
	add_child(_process_timer)
	
	setup_faction_details()

func setup_faction_details():
	is_sathar = false
	var scen_key = NetworkManager.lobby_data.get("scenario", "")
	if scen_key != "":
		var scen = ScenarioManager.get_scenario(scen_key)
		if scen and scen.has("sides"):
			var idx = side_id - 1
			if scen["sides"].has(idx):
				if scen["sides"][idx].get("name", "") == "Sathar":
					is_sathar = true
	game_manager.log_message("[color=yellow]AI Spawning for Side %d (Sathar: %s)[/color]" % [side_id, str(is_sathar)])

func _process(_delta):
	# Polling GameManager state to know when it is our turn to act
	if not is_instance_valid(game_manager):
		return
		
	# Quick exit if timers are running (delaying between actions)
	if not _process_timer.is_stopped():
		return
		
	# Are animations playing?
	if game_manager.current_combat_state == GameManager.CombatState.RESOLVING:
		return
		
	match game_manager.current_phase:
		GameManager.Phase.DEPLOYMENT:
			if game_manager.deployment_subphase == side_id and not _has_deployed():
				_think(1.0)
		GameManager.Phase.MOVEMENT:
			if game_manager.current_side_id == side_id:
				if _has_unmoved_ships():
					if not is_instance_valid(game_manager.selected_ship):
						_think(0.5)
					elif game_manager.selected_ship.side_id == side_id and not game_manager.selected_ship.has_moved:
						_think(0.5)
					else:
						game_manager.log_message("[color=gray]AI Poll: Selected ship is valid but already moved or wrong side.[/color]")
				else:
					game_manager.log_message("[color=gray]AI Poll: Movement Phase active but no unmoved ships left.[/color]")
					# We are done moving, but UI is waiting for commit
					_think(1.0)
		GameManager.Phase.COMBAT:
			var passive_firing = (game_manager.combat_subphase == 1 and game_manager.firing_side_id == side_id)
			var active_firing = (game_manager.combat_subphase == 2 and game_manager.firing_side_id == side_id)
			if (passive_firing or active_firing) and game_manager.current_combat_state == GameManager.CombatState.PLANNING:
				if not _has_finished_combat_planning():
					_think(1.0)
				else:
					# Finished planning, commit attacks
					_think(1.0)
		GameManager.Phase.REPAIR:
			if game_manager.repair_subphase == side_id and not _has_finished_repairs():
				_think(1.0)

func _has_deployed() -> bool:
	if side_id == 1:
		return game_manager.has_deployed_side_1
	else:
		return game_manager.has_deployed_side_2

func _has_unmoved_ships() -> bool:
	for s in game_manager.ships:
		if is_instance_valid(s) and s.side_id == side_id and not s.has_moved and not s.has_orders and not s.is_exploding and not s.is_destroyed and not s.has_withdrawn:
			return true
	return false

# Track if we've already done planning for the current subphase to avoid infinite loops
var _last_planned_combat_turn: int = -1
var _last_planned_combat_subphase: int = -1
func _has_finished_combat_planning() -> bool:
	return _last_planned_combat_turn == game_manager.turn_count and _last_planned_combat_subphase == game_manager.combat_subphase

var _repairs_planned_turn: int = -1
func _has_finished_repairs() -> bool:
	return _repairs_planned_turn == game_manager.turn_count

func _think(wait_time: float):
	# Skip simulated wait times during automated headless benchmarks
	if is_instance_valid(game_manager) and game_manager.is_headless:
		wait_time = 0.01
		
	if game_manager.current_phase != GameManager.Phase.MOVEMENT:
		_is_waiting_for_transition = false

	# Start a timer to simulate "thinking" and allow UI to naturally update
	_process_timer.start(wait_time)

func _on_think_timeout():
	if not is_instance_valid(game_manager): return
	
	match game_manager.current_phase:
		GameManager.Phase.DEPLOYMENT:
			_execute_deployment()
		GameManager.Phase.MOVEMENT:
			if game_manager.current_side_id != side_id:
				_think(1.0)
				return # Wait for our turn
			if _has_unmoved_ships():
				_is_waiting_for_transition = false
				_execute_movement()
			else:
				# Pass turn
				if _is_waiting_for_transition:
					_think(1.0)
					return
				_is_waiting_for_transition = true
				if game_manager.multiplayer.has_multiplayer_peer():
					game_manager.rpc_id(1, "request_execute_movement")
				else:
					game_manager.execute_all_movement()
		GameManager.Phase.COMBAT:
			if game_manager.firing_side_id != side_id:
				_think(1.0)
				return # Wait for our turn
				
			if game_manager.current_combat_state == GameManager.CombatState.PLANNING:
				if not _has_finished_combat_planning():
					var attacks_data = _plan_combat()
					var seed_val = randi()
					if game_manager.multiplayer.has_multiplayer_peer():
						game_manager.rpc_id(1, "execute_commit_combat", attacks_data, seed_val)
					else:
						game_manager.execute_commit_combat(attacks_data, seed_val)
				else:
					_think(1.0)
			else:
				_think(1.0)
		GameManager.Phase.REPAIR:
			if game_manager.repair_subphase != side_id:
				_think(1.0)
				return # Wait for our turn
				
			if not _has_finished_repairs():
				_execute_repairs()
			
			_think(1.0)

# --- DEPLOYMENT ---
func _execute_deployment():
	game_manager.log_message("AI Auto-Deploying Ships...")
	
	# Uses AutoDeployProcessor logic for heuristics
	var my_ships = game_manager.ships.filter(func(s): return s.side_id == side_id)
	
	var valid_hexes = ScenarioManager.get_valid_deployment_hexes(side_id, my_ships, game_manager.planet_hexes)
	var deployer = AutoDeployProcessor.new()
	deployer.execute(my_ships, valid_hexes, game_manager)
	
	var dep_data = {}
	for s in my_ships:
		dep_data[s.name] = {
			"grid_position": s.grid_position,
			"facing": s.facing,
			"speed": s.speed,
			"orbit_direction": s.orbit_direction,
			"is_deployed": true
		}
	
	var deployed_mines_data = game_manager.deployment_mines_placed.duplicate()
	var deployed_seekers_data = game_manager.deployment_seekers_placed.duplicate()
	
	if game_manager.multiplayer.has_multiplayer_peer() and not game_manager._is_server_or_offline():
		game_manager.rpc_submit_deployment.rpc_id(1, side_id, dep_data, deployed_mines_data, deployed_seekers_data)
	else:
		game_manager.rpc_submit_deployment(side_id, dep_data, deployed_mines_data, deployed_seekers_data)

# --- MOVEMENT ---
func _execute_movement():
	# --- Activate Strategic Seekers ---
	var my_dormant_seekers = game_manager.active_seekers.filter(func(s): return s["side_id"] == side_id and s.get("speed", 0) == 0)
	for seeker in my_dormant_seekers:
		var s_pos = seeker["pos"]
		
		# Find the absolute nearest ship to the seeker (friendly or enemy)
		var nearest_ship = null
		var min_d = 999
		for sh in game_manager.ships:
			if is_instance_valid(sh) and not sh.is_exploding and not sh.is_destroyed:
				var d = HexGrid.hex_distance(s_pos, sh.grid_position)
				if d < min_d:
					min_d = d
					nearest_ship = sh
					
		# Only activate if the absolute nearest ship is an ENEMY (Friendly Fire Prevention)
		if nearest_ship and nearest_ship.side_id != side_id:
			# Evaluate if the enemy is a worthy target based on distance and class
			var activation_score = 0.0
			
			# Distance scaling (Range 2 is high reward, 12+ is low)
			if min_d <= 2:
				activation_score += 50.0
			elif min_d <= 5:
				activation_score += 30.0
			elif min_d <= 8:
				activation_score += 15.0
			elif min_d <= 12:
				activation_score += 5.0
			else:
				activation_score += 0.0
				
			# Ship Class Bias
			if nearest_ship.ship_class in ["Battleship", "Assault Carrier", "Heavy Cruiser"]:
				activation_score += 40.0
			elif nearest_ship.ship_class in ["Light Cruiser", "Destroyer", "Frigate"]:
				activation_score += 15.0
			elif nearest_ship.ship_class in ["Fighter", "Assault Scout"]:
				activation_score += 0.0 # Lowest priority
			elif "Station" in nearest_ship.ship_class or "Fortress" in nearest_ship.ship_class:
				activation_score += 25.0
				
			# If the score is high enough, activate the seeker
			if activation_score >= 20.0 and min_d <= 18:
				game_manager.log_message("AI activating Seeker at %v! Target: %s (Dist: %d, Score: %.1f)" % [s_pos, nearest_ship.name, min_d, activation_score])
				if game_manager._is_networked():
					game_manager.rpc_activate_seeker.rpc(s_pos)
				else:
					game_manager.rpc_activate_seeker(s_pos)

	# Find a ship to move
	var ship_to_move = null
	var unmoved_count = 0
	for s in game_manager.ships:
		if is_instance_valid(s) and s.side_id == side_id and not s.has_moved and not s.has_orders and not s.is_exploding and not s.is_destroyed and not s.has_withdrawn:
			unmoved_count += 1
			if ship_to_move == null:
				ship_to_move = s
			
	if ship_to_move == null:
		return
		
	# Quick indicator if this is the start of the sequence
	var total_my_ships = game_manager.ships.filter(func(s): return is_instance_valid(s) and s.side_id == side_id and not s.is_exploding and not s.is_destroyed).size()
	if unmoved_count == total_my_ships:
		game_manager.log_message("[color=yellow]AI Computer Opponent Planning Movement...[/color]")
		
	game_manager.log_message("[color=gray]AI Thinking: Evaluating %s (Unmoved left: %d)[/color]" % [ship_to_move.name, unmoved_count])
		
	# Calculate valid hexes and pathing
	var start_hex = ship_to_move.grid_position
	var target_enemy = null
	if ship_to_move.ship_class == "Fighter":
		var leader = _get_flight_leader(ship_to_move)
		if leader == ship_to_move:
			target_enemy = _pick_strike_target(ship_to_move)
			_flight_leader_targets[ship_to_move.name] = target_enemy
		else:
			target_enemy = _flight_leader_targets.get(leader.name, null)
			if not is_instance_valid(target_enemy) or target_enemy.is_exploding or target_enemy.is_destroyed:
				target_enemy = _pick_strike_target(ship_to_move)
	else:
		var min_dist = 9999
		for e in game_manager.ships:
			if is_instance_valid(e) and e.side_id != side_id and not e.is_exploding and not e.is_destroyed:
				var d = HexGrid.hex_distance(start_hex, e.grid_position)
				if d < min_dist:
					min_dist = d
					target_enemy = e
		
	game_manager.log_message("[color=gray]AI Thinking: Nearest target for %s is %s[/color]" % [ship_to_move.name, target_enemy.name if target_enemy else "None"])
	
	var fleet_retreat_ordered = _evaluate_fleet_advantage()
	var ship_retreat_utility = _calculate_retreat_utility(ship_to_move)
	var is_retreating = fleet_retreat_ordered or ship_retreat_utility > 50.0
	
	if is_retreating:
		var w_status = game_manager._can_withdraw(ship_to_move)
		if w_status["allowed"]:
			game_manager.log_message("[color=orange]AI Execution: %s is triggering WITHDRAW![/color]" % ship_to_move.name)
			if game_manager._is_networked() and not game_manager._is_server_or_offline():
				game_manager.rpc_id(1, "rpc_execute_withdraw", ship_to_move.name)
				game_manager.rpc_id(1, "register_movement_plan", ship_to_move.name, [], ship_to_move.facing, 0, false, [])
			else:
				game_manager.rpc_execute_withdraw(ship_to_move.name)
				game_manager.register_movement_plan(ship_to_move.name, [], ship_to_move.facing, 0, false, [])
			return
		else:
			game_manager.log_message("[color=orange]AI Execution: %s wants to retreat but is blocked! Evading to edges...[/color]" % ship_to_move.name)
	
	var best_move = _find_best_legal_move(ship_to_move, target_enemy, is_retreating)
	
	if best_move and best_move["path"].size() > 0:
		# Submit to GameManager
		if game_manager._is_networked() and not game_manager._is_server_or_offline():
			game_manager.rpc_id(1, "register_movement_plan", ship_to_move.name, best_move["path"], best_move["facing"], 0, false, [])
		else:
			game_manager.register_movement_plan(ship_to_move.name, best_move["path"], best_move["facing"], 0, false, [])
		game_manager.log_message("AI plotted movement for %s (Speed %d -> %d, %d hexes)" % [ship_to_move.get_display_name(), ship_to_move.speed, best_move["path"].size(), best_move["path"].size()])
	else:
		# Fallback to hold position/speed 0 if possible
		if game_manager._is_networked() and not game_manager._is_server_or_offline():
			game_manager.rpc_id(1, "register_movement_plan", ship_to_move.name, [], ship_to_move.facing, 0, false, [])
		else:
			game_manager.register_movement_plan(ship_to_move.name, [], ship_to_move.facing, 0, false, [])
		game_manager.log_message("AI held position for %s" % ship_to_move.get_display_name())
	
	# The AI is done with this ship, but wait for GameManager's register_movement_plan
	# to officially lock the node logic. Next _process tick will seek the next ship.

# --- REPAIR ---
func _execute_repairs():
	game_manager.log_message("AI Auto-Repairing Ships...")
	_repairs_planned_turn = game_manager.turn_count
	var repair_script = load("res://Scripts/AutoRepairProcessor.gd")
	repair_script.execute_repairs(game_manager, side_id)

func _find_best_legal_move(ship: Ship, target: Ship, is_retreating: bool = false) -> Dictionary:
	var old_speed = ship.speed if not ship.is_docked else 0
	var eff_adf = ship.get_effective_adf()
	var max_mr = ship.get_effective_mr()
	
	var min_speed = max(0, old_speed - eff_adf)
	var max_speed = old_speed + eff_adf
	
	game_manager.log_message("[color=gray]AI Thinking: %s constraints -> Speed [%d, %d], MR %d[/color]" % [ship.name, min_speed, max_speed, max_mr])
	
	var all_paths = []
	_dfs_paths(ship.grid_position, ship.facing, max_mr, max_speed, min_speed, [], max_mr, all_paths, old_speed)
	
	game_manager.log_message("[color=gray]AI Thinking: Explored %d possible paths matching speed bounds.[/color]" % all_paths.size())
	
	var best_score = -99999.0
	var best_move = null
	
	for move in all_paths:
		var end_hex = move["path"].back() if move["path"].size() > 0 else ship.grid_position
		
		var score = _score_hex(end_hex, target, is_retreating, ship)
		
		# AI Constraint: Avoid self-destruction via DCR limits
		var mr_used = max_mr - move.get("mr_left", max_mr)
		var adf_used = abs(move["path"].size() - old_speed)
		var risk = ship.get_hull_integrity_risk(adf_used, mr_used)
		if risk > 0:
			score -= risk * 100.0
		
		# Collision check vs planets (Extreme Penalty, rather than skipping, so we don't return null and get blocked by GameManager)
		var is_safe = true
		for hex in move["path"]:
			if hex in game_manager.planet_hexes:
				is_safe = false
				break
		if not is_safe:
			score -= 10000.0
			
		# Off-map penalty
		if HexGrid.hex_distance(Vector3i.ZERO, end_hex) > game_manager.map_radius:
			score -= 5000.0
			
		if score > best_score:
			best_score = score
			best_move = move
			
	# Desperation fallback -> generate a straight line at current speed if DFS somehow failed
	if not best_move:
		game_manager.log_message("[color=red]AI Warning: DFS returned NO paths for %s! Generating emergency straight-line path of length %d...[/color]" % [ship.name, old_speed])
		var emergency_path: Array[Vector3i] = []
		var curr_hex = ship.grid_position
		var fwd_vec = HexGrid.get_direction_vec(ship.facing)
		for i in range(old_speed):
			curr_hex += fwd_vec
			emergency_path.append(curr_hex)
		best_move = {"path": emergency_path, "facing": ship.facing, "mr_left": max_mr}
	
	if best_move:
		game_manager.log_message("[color=gray]AI Move Eval -> Ship: %s | Start Speed: %d | Final Speed: %d (ADF: %d) | MR Used: %d/%d[/color]" % [
			ship.get_display_name(), old_speed, best_move["path"].size(), eff_adf, max_mr - best_move.get("mr_left", max_mr), max_mr
		])
			
	return best_move

func _dfs_paths(current_hex: Vector3i, current_facing: int, mr_left: int, max_depth: int, min_depth: int, current_path: Array, start_mr: int, all_paths: Array, old_speed: int):
	# Cap the maximum number of explored paths to prevent Godot engine crashes on highly maneuverable ships
	var MAX_EXPLORE = 2000
	if all_paths.size() >= MAX_EXPLORE:
		return
		
	if current_path.size() >= min_depth and current_path.size() <= max_depth:
		all_paths.append({"path": current_path.duplicate(), "facing": current_facing, "mr_left": mr_left})
		
	if current_path.size() == max_depth:
		return
		
	# Prepare branches
	var branches = []
	
	# Branch 1: Forward
	branches.append({"type": "forward"})
	
	# Branches 2 & 3: Turn Left/Right (Costs 1 MR, turns facing by 1, moves forward by 1)
	if mr_left > 0:
		# Rule: Cannot turn in the starting hex unless starting speed was 0
		var can_turn = true
		if old_speed > 0 and current_path.size() == 0:
			can_turn = false
			
		if can_turn:
			branches.append({"type": "turn", "direction": -1})
			branches.append({"type": "turn", "direction": 1})
			
	# Shuffle branches to ensure we get a diverse set of paths if we hit the MAX_EXPLORE cap
	# Using Fisher-Yates shuffle
	for i in range(branches.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = branches[i]
		branches[i] = branches[j]
		branches[j] = temp
		
	# Execute branches
	for branch in branches:
		if branch["type"] == "forward":
			var forward_vec = HexGrid.get_direction_vec(current_facing)
			var next_hex = current_hex + forward_vec
			
			var p_forward = current_path.duplicate()
			p_forward.append(next_hex)
			_dfs_paths(next_hex, current_facing, mr_left, max_depth, min_depth, p_forward, start_mr, all_paths, old_speed)
		elif branch["type"] == "turn":
			var turn = branch["direction"]
			var new_facing = (current_facing + turn + 6) % 6
			var turn_vec = HexGrid.get_direction_vec(new_facing)
			var turn_hex = current_hex + turn_vec
			var p_turn = current_path.duplicate()
			p_turn.append(turn_hex)
			_dfs_paths(turn_hex, new_facing, mr_left - 1, max_depth, min_depth, p_turn, start_mr, all_paths, old_speed)

func _score_hex(hex: Vector3i, target: Ship, is_retreating: bool = false, evaluating_ship: Ship = null) -> float:
	var score = 0.0
	
	if is_retreating:
		var dist_from_center = HexGrid.hex_distance(Vector3i.ZERO, hex)
		score += dist_from_center * 5.0
		if target:
			var d_t = HexGrid.hex_distance(hex, target.grid_position)
			score += d_t * 2.0
	else:
		if not target: return rng.randfn(0.0, 2.0)
		
		var dist_to_target = HexGrid.hex_distance(hex, target.grid_position)
		
		# Base pull towards target (encourages closing the gap even outside weapon range)
		score -= dist_to_target * 1.0
		
		# L1: Reach
		if dist_to_target <= 10:
			score += 2.0 * (10 - dist_to_target)
			
		# L3: Threat Avoidance
		if dist_to_target < 3:
			score -= 2.5 * (3 - dist_to_target)
			
		# L6: Fighter Flocking Cohesion & Aggression
		if evaluating_ship and evaluating_ship.ship_class == "Fighter":
			# Dramatic bias towards closing with enemies for fighters
			score -= dist_to_target * 5.0
			
			# Prevent stacking on any ally fighter
			for ally in game_manager.ships:
				if is_instance_valid(ally) and ally.side_id == evaluating_ship.side_id and ally.ship_class == "Fighter" and ally != evaluating_ship:
					var dist_to_ally = HexGrid.hex_distance(hex, ally.grid_position)
					if dist_to_ally == 0:
						score -= 10.0 # FLOCK_SEPARATION_PENALTY (Don't stack)
			
			# Follower clustering
			var leader = _get_flight_leader(evaluating_ship)
			if leader and leader != evaluating_ship:
				var dist_to_leader = HexGrid.hex_distance(hex, leader.grid_position)
				if dist_to_leader <= 2 and dist_to_leader > 0:
					score += 10.0  # Strong FLOCK_COHESION_BONUS to stick with leader
				elif dist_to_leader > 2:
					score -= dist_to_leader * 1.5 # Penalize drifting from leader
			
	# Gaussian Noise (Fuzziness)
	var noise_variance = 4.0 if (evaluating_ship and evaluating_ship.ship_class == "Fighter") else 2.0
	score += rng.randfn(0.0, noise_variance)
	return score

# --- TACTICAL RETREAT EVALUATION ---
func _evaluate_fleet_advantage() -> bool:
	var my_combat_power = 0.0
	var enemy_combat_power = 0.0
	var defending_station = false
	
	for ship in game_manager.ships:
		if not is_instance_valid(ship) or ship.is_exploding or ship.has_withdrawn or ship.is_destroyed:
			continue
			
		var ship_power = float(ship.hull)
		for w in ship.weapons:
			if not w.get("is_crippled", false) and w.get("ammo", -1) != 0:
				ship_power += 5.0 # Rough approx of active weapon output
				
		if ship.side_id == side_id:
			my_combat_power += ship_power
			if "Station" in ship.ship_class or "Fortress" in ship.ship_class:
				defending_station = true
		else:
			enemy_combat_power += ship_power
			
	if enemy_combat_power == 0:
		return false
		
	var car = my_combat_power / enemy_combat_power
	var retreat_threshold = 0.3 # Base 3-to-1 disadvantage triggers retreat
	
	if is_sathar:
		retreat_threshold -= 0.15 # Sathar fight longer unconditionally
		
	if defending_station:
		retreat_threshold -= 0.1 # Will fight to a lower margin to protect stations
		
	game_manager.log_message("[color=gray]AI Thinking: Fleet CAR: %.3f (Threshold: %.2f) Powers: Me=%.1f, Enemy=%.1f[/color]" % [car, retreat_threshold, my_combat_power, enemy_combat_power])
		
	return car < retreat_threshold

func _calculate_retreat_utility(ship: Ship) -> float:
	if ship.ship_class == "Fighter":
		return 0.0 # Fighters never decide to retreat themselves, they must stay with carrier
		
	var utility = 0.0
	var hull_pct = float(ship.hull) / float(ship.max_hull) if ship.max_hull > 0 else 0.0
	
	# Factor 1: Critical Structural Damage
	if hull_pct < 0.25:
		utility += (0.25 - hull_pct) * 100.0
		
	# Factor 2: Defensive Collapse
	var has_defenses = ship.icm_current > 0 or ship.ms_current > 0
	if hull_pct < 0.5 and not has_defenses:
		utility += 20.0
		
	# Factor 3: Combat Ineffectiveness (Disarmed)
	var active_weapons = 0
	for w in ship.weapons:
		if not w.get("is_crippled", false) and w.get("ammo", -1) != 0:
			active_weapons += 1
			
	if active_weapons == 0:
		utility += 100.0 # High priority: unarmed ships provide no offensive value
		
	# Modify: Sathar Aggression
	if is_sathar:
		utility -= 20.0
		
	# Modify: Carrier Duty
	if ship.ship_class == "Assault Carrier":
		utility -= 30.0 # Will risk itself more if it means staying to retrieve fighters
	
	game_manager.log_message("[color=gray]AI Thinking: %s Individual Retreat Utility: %.1f (Hull: %.2f%%, Def: %s, Atk: %d)[/color]" % [ship.name, utility, hull_pct*100, str(has_defenses), active_weapons])
	
	return utility

# --- COMBAT ---
func _plan_combat() -> Array:
	var my_ships = game_manager.ships.filter(func(s): return is_instance_valid(s) and s.side_id == side_id and not s.is_exploding and not s.is_destroyed)
	var targets = game_manager.ships.filter(func(s): return is_instance_valid(s) and s.side_id != side_id and not s.is_exploding and not s.is_destroyed)
	var attacks_data = []
	
	for ship in my_ships:
		for i in range(ship.weapons.size()):
			var w = ship.weapons[i]
			if w.get("fired", false): continue
			if not game_manager._is_weapon_available_in_phase(w, ship): continue
			
			var valid_targets = game_manager._get_valid_targets_for_weapon(ship, w)
			
			var best_target = null
			var best_utility = -999.0
			
			for t in valid_targets:
				var dist = HexGrid.hex_distance(ship.grid_position, t.grid_position)
				
				# Base Utility
				var u_a = 10.0 - dist # Preference for closer targets
				if is_sathar:
					u_a += 0.5 # Sathar Aggression Bias
					
				# Swarm Bonus
				if ship.ship_class == "Fighter":
					var leader = _get_flight_leader(ship)
					if leader and _flight_leader_targets.get(leader.name) == t:
						u_a += 50.0
				
				# Fuzziness
				u_a += rng.randfn(0.0, 1.5)
				
				if u_a > best_utility:
					best_utility = u_a
					best_target = t
			
			if best_target:
				game_manager.log_message("AI Planning: %s -> %s with %s (Utility: %.2f)" % [ship.get_display_name(), best_target.get_display_name(), w["name"], best_utility])
				
				# Compile directly for resolution payload
				attacks_data.append({
					"s": str(ship.name),
					"t": str(best_target.name),
					"w": i,
					"tp": best_target.grid_position
				})

	_last_planned_combat_turn = game_manager.turn_count
	_last_planned_combat_subphase = game_manager.combat_subphase
	return attacks_data

# --- FIGHTER FLIGHT LEADERS ---
func _get_flight_leader(fighter: Ship) -> Ship:
	if fighter.ship_class != "Fighter":
		return null
		
	var potential_leaders = []
	for ally in game_manager.ships:
		if is_instance_valid(ally) and ally.side_id == fighter.side_id and ally.ship_class == "Fighter" and not ally.is_exploding and not ally.is_destroyed:
			if HexGrid.hex_distance(fighter.grid_position, ally.grid_position) <= 20:
				potential_leaders.append(ally)
				
	if potential_leaders.size() == 0:
		return fighter
		
	# Sort by name alphabetically so it's consistent across turns
	potential_leaders.sort_custom(func(a, b): return a.name < b.name)
	return potential_leaders[0]

func _pick_strike_target(ship: Ship) -> Ship:
	var best_target = null
	var best_utility = -999.0
	
	for e in game_manager.ships:
		if is_instance_valid(e) and e.side_id != ship.side_id and not e.is_exploding and not e.is_destroyed:
			var dist = HexGrid.hex_distance(ship.grid_position, e.grid_position)
			var u = 20.0 - (dist * 0.5) # Preference for closer targets, but heavily outweighed by ship class
			
			# Priority to Capital Ships
			if e.ship_class == "Assault Carrier" or e.ship_class == "Battleship":
				u += 50.0
			elif e.ship_class == "Heavy Cruiser" or e.ship_class == "Light Cruiser":
				u += 30.0
			elif e.ship_class == "Destroyer":
				u += 15.0
			elif e.ship_class == "Frigate":
				u += 5.0
			elif e.ship_class == "Corvette":
				u += 0.0
			elif "Station" in e.ship_class or "Fortress" in e.ship_class:
				u += 25.0
				
			# Randomness
			u += rng.randfn(0.0, 5.0)
			
			if u > best_utility:
				best_utility = u
				best_target = e
				
	return best_target
