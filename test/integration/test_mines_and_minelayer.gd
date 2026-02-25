extends "res://addons/gut/test.gd"

var gm: Node

func before_each():
	var root = get_tree().root
	var old_gm = root.get_node_or_null("GameManager")
	if old_gm:
		root.remove_child(old_gm)
		old_gm.queue_free()
		
	var template = load("res://Scenes/Level_00.tscn")
	if template:
		gm = template.instantiate()
		root.add_child(gm)
	else:
		gm = load("res://Scripts/GameManager.gd").new()
		root.add_child(gm)
		
	# Wait for ready and scene setup
	await get_tree().process_frame
	await get_tree().process_frame
	
	if gm.has_method("_reset_state_for_testing"):
		gm._reset_state_for_testing()
	else:
		if gm.has_method("_setup_ui"): gm._setup_ui()
		if gm.has_method("_setup_selection_highlight"): gm._setup_selection_highlight()
		if gm.has_method("_spawn_planets"): gm._spawn_planets()
	
	gm.my_side_id = 0
	gm.current_phase = 0 # PHASE_MOVEMENT
	
	for s in gm.ships:
		if is_instance_valid(s):
			s.queue_free()
	gm.ships.clear()
	gm.active_mines.clear()
	
func after_each():
	if is_instance_valid(gm):
		gm.queue_free()
	await get_tree().process_frame

func test_minelayer_places_mine_and_detonates():
	# 1. Setup Minelayer
	var ml = preload("res://Scripts/Ship.gd").new()
	ml.name = "UPF_Minelayer_Test"
	ml.side_id = 1
	ml.grid_position = Vector3i(5, -5, 0)
	ml.facing = 0
	ml.configure_minelayer()
	gm.add_child(ml)
	gm.ships.append(ml)
	
	# Setup Target (Sathar Frigate)
	var target = preload("res://Scripts/Ship.gd").new()
	target.name = "Sathar_Frigate_Test"
	target.side_id = 2
	target.grid_position = Vector3i(7, -5, -2) # Away
	target.facing = 3
	target.configure_frigate()
	gm.add_child(target)
	gm.ships.append(target)
	
	await get_tree().process_frame
	
	# 2. Plot Minelayer movement and Drop Mine
	gm.selected_ship = ml
	gm.current_side_id = 1
	
	# Move forward 1 hex
	var forward = HexGrid.get_direction_vec(ml.facing)
	var next_hex = ml.grid_position + forward # (1, 0, -1)
	
	var path: Array[Vector3i] = [next_hex]
	gm.current_path = path
	gm.turns_remaining = ml.mr
	gm.start_speed = ml.speed
	
	gm.ghost_ship = preload("res://Scripts/Ship.gd").new()
	gm.ghost_ship.name = "GhostShip1"
	gm.ghost_ship.facing = ml.facing
	gm.add_child(gm.ghost_ship)
	
	# Simulate toggling Mine Drop mode
	gm._on_drop_mine_pressed()
	
	# Drop mine at starting pos
	gm._handle_movement_click(Vector3i(5,-5,0))
	
	assert_eq(ml.planned_mines_to_drop.size(), 1, "Minelayer should have 1 mine planned")
	
	# Commit and execute
	gm._on_commit_move()
	
	assert_eq(ml.planned_path.size(), 1, "Minelayer has plotted path")
	
	# Trigger fake execution (Server skip since we only have 1 ship)
	gm.execute_all_movement()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_eq(gm.active_mines.size(), 1, "One active mine should be placed")
	assert_eq(gm.active_mines[0]["pos"], Vector3i(5,-5,0), "Mine should be at start loc")
	
	var mine_ammo = 0
	for w in ml.weapons:
		if w["type"] == "Mine": mine_ammo = w["ammo"]
	assert_eq(mine_ammo, 19, "Mine ammo should be decremented")
	
	# 3. Next Side moves into the mine
	gm.current_side_id = 2
	gm.current_phase = 0 # Movement again
	gm.selected_ship = target
	
	# Remove ICMs to avoid the async await blocking in the test
	target.icm_current = 0
	
	var path2: Array[Vector3i] = [Vector3i(6,-5,-1), Vector3i(5,-5,0)]
	gm.current_path = path2 # Move through the mine
	
	gm.ghost_ship = preload("res://Scripts/Ship.gd").new()
	gm.ghost_ship.name = "GhostShip2"
	gm.ghost_ship.facing = target.facing
	gm.add_child(gm.ghost_ship)
	
	gm._on_commit_move()
	
	assert_eq(target.planned_path.size(), 2, "Target plotted path into mine")
	
	# Execute target movement
	await gm.execute_all_movement()
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("DEBUG Target grid pos: ", target.grid_position, " expected: ", Vector3i(5,-5,0))
	print("DEBUG Active mines: ", gm.active_mines)
	
	assert_eq(gm.active_mines.size(), 0, "Mine should be destroyed after detonation")
	pass
