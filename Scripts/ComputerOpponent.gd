class_name ComputerOpponent
extends Node

var game_manager: GameManager
var side_id: int = 0
var is_sathar: bool = false
var rng: RandomNumberGenerator

var _process_timer: Timer

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
		if is_instance_valid(s) and s.side_id == side_id and not s.has_moved and not s.has_orders and not s.is_exploding and not s.is_docked:
			return true
	return false

# Track if we've already done planning for the current subphase to avoid infinite loops
var _combat_planned_subphase: int = 0
func _has_finished_combat_planning() -> bool:
	return _combat_planned_subphase == game_manager.combat_subphase

var _repairs_planned_turn: int = -1
func _has_finished_repairs() -> bool:
	return _repairs_planned_turn == game_manager.turn_count

func _think(wait_time: float):
	# Start a timer to simulate "thinking" and allow UI to naturally update
	_process_timer.start(wait_time)

func _on_think_timeout():
	if not is_instance_valid(game_manager): return
	
	match game_manager.current_phase:
		GameManager.Phase.DEPLOYMENT:
			_execute_deployment()
		GameManager.Phase.MOVEMENT:
			if _has_unmoved_ships():
				_execute_movement()
			else:
				# Pass turn
				if game_manager.multiplayer.has_multiplayer_peer():
					game_manager.rpc_id(1, "request_execute_movement")
				else:
					game_manager.execute_all_movement()
		GameManager.Phase.COMBAT:
			if not _has_finished_combat_planning():
				var attacks_data = _plan_combat()
				var seed_val = randi()
				if game_manager.multiplayer.has_multiplayer_peer():
					game_manager.rpc_id(1, "execute_commit_combat", attacks_data, seed_val)
				else:
					game_manager.execute_commit_combat(attacks_data, seed_val)
		GameManager.Phase.REPAIR:
			if not _has_finished_repairs():
				_execute_repairs()

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
	# Find a ship to move
	var ship_to_move = null
	var unmoved_count = 0
	for s in game_manager.ships:
		if is_instance_valid(s) and s.side_id == side_id and not s.has_moved and not s.has_orders and not s.is_exploding and not s.is_docked:
			unmoved_count += 1
			if ship_to_move == null:
				ship_to_move = s
			
	if ship_to_move == null:
		return
		
	# Quick indicator if this is the start of the sequence
	var total_my_ships = game_manager.ships.filter(func(s): return is_instance_valid(s) and s.side_id == side_id and not s.is_exploding and not s.is_docked).size()
	if unmoved_count == total_my_ships:
		game_manager.log_message("[color=yellow]AI Computer Opponent Planning Movement...[/color]")
		
	game_manager.log_message("[color=gray]AI Thinking: Evaluating %s (Unmoved left: %d)[/color]" % [ship_to_move.name, unmoved_count])
		
	# Calculate valid hexes and pathing
	var start_hex = ship_to_move.grid_position
	# For AI movement, simple heuristic: move towards nearest enemy or stay put if defending
	var target_enemy = null
	var min_dist = 9999
	for e in game_manager.ships:
		if is_instance_valid(e) and e.side_id != side_id and not e.is_exploding:
			var d = HexGrid.hex_distance(start_hex, e.grid_position)
			if d < min_dist:
				min_dist = d
				target_enemy = e
				
		pass # The target_enemy evaluation is now done inside the _find_best_legal_move scoring step.
		
	game_manager.log_message("[color=gray]AI Thinking: Nearest target for %s is %s[/color]" % [ship_to_move.name, target_enemy.name if target_enemy else "None"])
	var best_move = _find_best_legal_move(ship_to_move, target_enemy)
	
	if best_move and best_move["path"].size() > 0:
		# Submit to GameManager
		game_manager.register_movement_plan(ship_to_move.name, best_move["path"], best_move["facing"], 0, false, [])
		game_manager.log_message("AI plotted movement for %s (Speed %d -> %d, %d hexes)" % [ship_to_move.get_display_name(), ship_to_move.speed, best_move["path"].size(), best_move["path"].size()])
	else:
		# Fallback to hold position/speed 0 if possible
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

func _find_best_legal_move(ship: Ship, target: Ship) -> Dictionary:
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
		
		var score = _score_hex(end_hex, target)
		
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
	if current_path.size() >= min_depth and current_path.size() <= max_depth:
		all_paths.append({"path": current_path.duplicate(), "facing": current_facing, "mr_left": mr_left})
		
	if current_path.size() == max_depth:
		return
		
	# Forward
	var forward_vec = HexGrid.get_direction_vec(current_facing)
	var next_hex = current_hex + forward_vec
	
	var p_forward = current_path.duplicate()
	p_forward.append(next_hex)
	_dfs_paths(next_hex, current_facing, mr_left, max_depth, min_depth, p_forward, start_mr, all_paths, old_speed)
	
	# Turn Left/Right (Costs 1 MR, turns facing by 1, moves forward by 1)
	if mr_left > 0:
		# Rule: Cannot turn in the starting hex unless starting speed was 0
		var can_turn = true
		if old_speed > 0 and current_path.size() == 0:
			can_turn = false
			
		if can_turn:
			for turn in [-1, 1]:
				var new_facing = (current_facing + turn + 6) % 6
				var turn_vec = HexGrid.get_direction_vec(new_facing)
				var turn_hex = current_hex + turn_vec
				var p_turn = current_path.duplicate()
				p_turn.append(turn_hex)
				_dfs_paths(turn_hex, new_facing, mr_left - 1, max_depth, min_depth, p_turn, start_mr, all_paths, old_speed)

func _score_hex(hex: Vector3i, target: Ship) -> float:
	var score = 0.0
	if not target: return rng.randfn(0.0, 2.0)
	
	var dist_to_target = HexGrid.hex_distance(hex, target.grid_position)
	
	# L1: Reach
	if dist_to_target <= 10:
		score += 2.0 * (10 - dist_to_target)
		
	# L3: Threat Avoidance
	if dist_to_target < 3:
		score -= 2.5 * (3 - dist_to_target)
		
	# Gaussian Noise (Fuzziness)
	score += rng.randfn(0.0, 2.0)
	return score

# --- COMBAT ---
func _plan_combat() -> Array:
	var my_ships = game_manager.ships.filter(func(s): return is_instance_valid(s) and s.side_id == side_id and not s.is_exploding)
	var targets = game_manager.ships.filter(func(s): return is_instance_valid(s) and s.side_id != side_id and not s.is_exploding)
	var attacks_data = []
	
	for ship in my_ships:
		for i in range(ship.weapons.size()):
			var w = ship.weapons[i]
			if w.get("fired", false): continue
			if not game_manager._is_weapon_available_in_phase(w, ship): continue
			
			var best_target = null
			var best_utility = -999.0
			
			for t in targets:
				var dist = HexGrid.hex_distance(ship.grid_position, t.grid_position)
				if dist <= w["range"]:
					# Base Utility
					var u_a = 10.0 - dist # Preference for closer targets
					if is_sathar:
						u_a += 0.5 # Sathar Aggression Bias
					
					# Fuzziness
					u_a += rng.randfn(0.0, 1.5)
					
					if u_a > best_utility:
						best_utility = u_a
						best_target = t
			
			if best_target:
				game_manager.log_message("AI Planning: %s -> %s with %s (Utility: %.2f)" % [ship.get_display_name(), best_target.get_display_name(), w["name"], best_utility])
				
				# Compile directly for resolution payload
				attacks_data.append({
					"s": ship.name,
					"t": best_target.name,
					"w": i,
					"tp": best_target.grid_position
				})

	_combat_planned_subphase = game_manager.combat_subphase
	return attacks_data
