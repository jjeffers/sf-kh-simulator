class_name AutoDeployProcessor
extends RefCounted

const ROLE_FRONT_LINE = "Front-line"
const ROLE_SUPPORT = "Support"
const ROLE_ESCORT = "Escort"

func execute(ships: Array, valid_hexes: Array[Vector3i], game_manager: Node) -> void:
    if ships.is_empty() or valid_hexes.is_empty():
        return
        
    var rng = RandomNumberGenerator.new()
    rng.randomize()
        
    var enemy_center_mass = _calculate_enemy_center_mass(game_manager, ships[0].side_id)
    var roles = _categorize_ships(ships)
    
    # Determine if this side is the Attacker.
    # Attackers historically possess valid deployment hexes restricted entirely to the map's outer radius edge.
    var is_attacker = true
    for h in valid_hexes:
        if HexGrid.hex_distance(Vector3i.ZERO, h) < game_manager.map_radius:
            is_attacker = false
            break

    # Extract all Asset Carriers available for this deployment side to harbor Attack Fighters
    var available_carriers = []
    for s in ships:
        if s.ship_class == "Assault Carrier" and not s.is_destroyed:
            available_carriers.append(s)

    var deployment_queue = []
    # If attacker, Fighters must dock with an Asset Carrier
    if is_attacker:
        var carrier_index = 0
        for s in ships:
            if s.ship_class == "Fighter":
                if available_carriers.size() > 0:
                    var carrier = available_carriers[carrier_index % available_carriers.size()]
                    s.dock_with(carrier)
                    carrier_index += 1
                else:
                    # Very strange edge case where attacker brings fighters without carriers.
                    # Fallback to normal queue.
                    pass
            
    # Priority: Support (Must be protected), Front-line (Take the hits), Escort (Screening)
    for s in roles[ROLE_SUPPORT]:
        if not s.is_docked: deployment_queue.append(s)
    for s in roles[ROLE_FRONT_LINE]:
        if not s.is_docked: deployment_queue.append(s)
    for s in roles[ROLE_ESCORT]:
        if not s.is_docked: deployment_queue.append(s)
    
    var placed_ships = []
    
    for s in deployment_queue:
        var ship_hexes = valid_hexes.duplicate()
        var scen_key = NetworkManager.lobby_data.get("scenario", "") if NetworkManager.has_node("/root/NetworkManager") else ""
        if scen_key == "close_escort" and s.name == "Megasaurus":
            ship_hexes = ship_hexes.filter(func(h): return h.y == 0)
            
        var best_hex = _find_best_hex(s, ship_hexes, placed_ships, enemy_center_mass, game_manager, rng, is_attacker)
        s.grid_position = best_hex
        s.position = HexGrid.hex_to_pixel(best_hex)
        s.is_deployed = true
        
        # Facing toward enemy center mass
        s.facing = _calculate_initial_facing(best_hex, enemy_center_mass)
        
        # Determine speed (now factoring in facing and obstacles)
        s.speed = _calculate_initial_speed(s, game_manager)
        
        # Override Megasaurus for Close Escort
        if scen_key == "close_escort" and s.name == "Megasaurus":
            s.facing = 3 # West
            s.speed = 5
            
        # Space stations
        if s.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
            s.orbit_direction = 1 # Default CW
            s.speed = 0
            
        placed_ships.append(s)
        
    _deploy_mines(ships[0].side_id, game_manager)
    _deploy_seekers(ships[0].side_id, game_manager)

func _deploy_seekers(active_side_id: int, game_manager: Node) -> void:
    # 1. Count seeker capacity available for this side
    var total_seeker_capacity = 0
    for s in game_manager.ships:
        if is_instance_valid(s) and s.side_id == active_side_id:
            for w in s.weapons:
                if w.get("type", "") == "Seeker":
                    total_seeker_capacity += w.get("ammo", 0)
    
    var seekers_needed = total_seeker_capacity - game_manager.deployment_seekers_placed.size()
    if seekers_needed <= 0:
        return
        
    # 2. Find planets defended by space stations of our side
    var target_planets = []
    for s in game_manager.ships:
        if is_instance_valid(s) and s.side_id == active_side_id and s.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
            # Find closest planet (typically orbit distance)
            for p in game_manager.planet_hexes:
                if HexGrid.hex_distance(s.grid_position, p) <= 5: 
                    if not p in target_planets:
                        target_planets.append(p)
    
    if target_planets.is_empty():
        return # No base to defend, scatter logic irrelevant
        
    # 3. Scatter randomly 7-9 hexes away from defended planets
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    
    for i in range(seekers_needed):
        var p = target_planets[rng.randi() % target_planets.size()]
        var dist = rng.randi_range(7, 9)
        
        var ring: Array[Vector3i] = []
        for dx in range(-dist, dist + 1):
            for dy in range(max(-dist, -dx - dist), min(dist, -dx + dist) + 1):
                var dz = -dx - dy
                var h = p + Vector3i(dx, dy, dz)
                if HexGrid.hex_distance(p, h) == dist:
                    ring.append(h)
                    
        # Find untaken spot on the ring
        var placed = false
        var attempts = 15
        while attempts > 0 and ring.size() > 0:
            var cand = ring[rng.randi() % ring.size()]
            # Keep it within map boundary
            if HexGrid.hex_distance(Vector3i.ZERO, cand) <= game_manager.map_radius:
                if not game_manager.deployment_seekers_placed.has(cand) and not game_manager.deployment_mines_placed.has(cand):
                    game_manager.deployment_seekers_placed.append(cand)
                    placed = true
                    break
            attempts -= 1

func _deploy_mines(active_side_id: int, game_manager: Node) -> void:
    # 1. Count mine capacity available for this side
    var total_mine_capacity = 0
    for s in game_manager.ships:
        if is_instance_valid(s) and s.side_id == active_side_id:
            for w in s.weapons:
                if w.get("type", "") == "Mine":
                    total_mine_capacity += w.get("ammo", 0)
    
    var mines_needed = total_mine_capacity - game_manager.deployment_mines_placed.size()
    if mines_needed <= 0:
        return
        
    # 2. Find planets defended by space stations of our side
    var target_planets = []
    for s in game_manager.ships:
        if is_instance_valid(s) and s.side_id == active_side_id and s.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
            # Find closest planet (typically orbit distance)
            for p in game_manager.planet_hexes:
                if HexGrid.hex_distance(s.grid_position, p) <= 5: 
                    if not p in target_planets:
                        target_planets.append(p)
    
    if target_planets.is_empty():
        return # No base to defend, scatter logic irrelevant
        
    # 3. Scatter randomly 7-9 hexes away from defended planets
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    
    for i in range(mines_needed):
        var p = target_planets[rng.randi() % target_planets.size()]
        var dist = rng.randi_range(7, 9)
        
        var ring: Array[Vector3i] = []
        for dx in range(-dist, dist + 1):
            for dy in range(max(-dist, -dx - dist), min(dist, -dx + dist) + 1):
                var dz = -dx - dy
                var h = p + Vector3i(dx, dy, dz)
                if HexGrid.hex_distance(p, h) == dist:
                    ring.append(h)
                    
        # Find untaken spot on the ring
        var placed = false
        var attempts = 15
        while attempts > 0 and ring.size() > 0:
            var cand = ring[rng.randi() % ring.size()]
            # Keep it within map boundary
            if HexGrid.hex_distance(Vector3i.ZERO, cand) <= game_manager.map_radius:
                if not game_manager.deployment_mines_placed.has(cand):
                    game_manager.deployment_mines_placed.append(cand)
                    placed = true
                    break
            attempts -= 1

func _categorize_ships(ships: Array) -> Dictionary:
    var roles = {
        ROLE_FRONT_LINE: [],
        ROLE_SUPPORT: [],
        ROLE_ESCORT: []
    }
    
    for s in ships:
        # Match PRD classifications mapping against Ship.gd strings
        match s.ship_class:
            "Battleship", "Heavy Cruiser":
                roles[ROLE_FRONT_LINE].append(s)
            "Assault Carrier", "Minelayer", "Space Station", "Station", "Armed Station", "Fortified Station":
                roles[ROLE_SUPPORT].append(s)
            "Assault Scout", "Frigate", "Destroyer", "Light Cruiser":
                roles[ROLE_ESCORT].append(s)
            _:
                # Fallback based on hull size if unknown
                if s.hull >= 40:
                    roles[ROLE_FRONT_LINE].append(s)
                else:
                    roles[ROLE_ESCORT].append(s)
                    
    return roles

func _calculate_enemy_center_mass(game_manager: Node, my_side_id: int) -> Vector3i:
    var enemy_ships = []
    for s in game_manager.ships:
        if is_instance_valid(s) and s.side_id != my_side_id and s.is_deployed and not s.is_destroyed:
            enemy_ships.append(s)
            
    if enemy_ships.is_empty():
        # Fallback to center of board or an arbitrary edge mapping
        return Vector3i.ZERO
        
    var sum = Vector3i.ZERO
    for s in enemy_ships:
        sum += s.grid_position
        
    # Integer division approximation
    return Vector3i(sum.x / enemy_ships.size(), sum.y / enemy_ships.size(), sum.z / enemy_ships.size())

func _find_best_hex(ship: Node, valid_hexes: Array[Vector3i], placed_ships: Array, enemy_center_mass: Vector3i, game_manager: Node, rng: RandomNumberGenerator, is_attacker: bool = false) -> Vector3i:
    var best_hex = valid_hexes[0]
    var best_score = -99999.0
    
    # Identify ship role
    var role = ROLE_ESCORT
    var roles = _categorize_ships([ship])
    if roles[ROLE_FRONT_LINE].size() > 0: role = ROLE_FRONT_LINE
    elif roles[ROLE_SUPPORT].size() > 0: role = ROLE_SUPPORT
    
    for h in valid_hexes:
        # Constraint: Attackers must deploy every ship within 2 hexes of another friendly ship
        if is_attacker and placed_ships.size() > 0:
            var is_within_range = false
            for p in placed_ships:
                if HexGrid.hex_distance(h, p.grid_position) <= 2:
                    is_within_range = true
                    break
            if not is_within_range:
                continue # Hard skip this hex, invalid per Attacker constraints
        # Introduce a baseline Gaussian noise (normal distribution) to slightly fuzz selections.
        # This prevents identical static layouts on every button press, but preserves mathematical preferences.
        var score = rng.randfn(0.0, 15.0)
        
        # 1. Spacing Penalty: Do not stack ships
        var is_occupied = false
        for p in placed_ships:
            if p.grid_position == h:
                is_occupied = true
                break
        if is_occupied:
            score -= 500.0 # Extreme penalty, but not hard fail in case valid_hexes is smaller than fleet
            
        # 1.5. Planetary Orbit Preference for Stations
        if ship.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
            var min_dist_to_planet = 999
            for p in game_manager.planet_hexes:
                var d = HexGrid.hex_distance(h, p)
                if d < min_dist_to_planet:
                    min_dist_to_planet = d
            
            if game_manager.planet_hexes.size() > 0:
                if min_dist_to_planet == 1:
                    score += 2000.0 # Massive reward for being in orbit
                else:
                    score -= min_dist_to_planet * 100.0 # Strong pull towards the planet
            
        # Also avoid stacking on existing environmental hazards (planets) if not a station
        if ship.ship_class not in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
            if h in game_manager.planet_hexes:
                score -= 1000.0
                
        # 2. Forward Arc Optimization: Closer to enemy center mass for Front-line, farther for Support
        var dist_to_enemy = HexGrid.hex_distance(h, enemy_center_mass)
        if role == ROLE_FRONT_LINE:
            # Prefer being closer to the enemy
            score -= dist_to_enemy * 2.0
        elif role == ROLE_SUPPORT:
            # Prefer being farther from the enemy
            score += dist_to_enemy * 2.0
            
        # 3. Mutual Screen Coverage: Proximity to allies
        if not placed_ships.is_empty():
            var min_dist_to_ally = 999
            for p in placed_ships:
                var d = HexGrid.hex_distance(h, p.grid_position)
                if d < min_dist_to_ally:
                    min_dist_to_ally = d
            
            if role == ROLE_ESCORT:
                # Escorts want to tightly screen (dist 1-2)
                if min_dist_to_ally == 1 or min_dist_to_ally == 2:
                    score += 20.0
                elif min_dist_to_ally == 0:
                    pass # Handled by overlap penalty
                else:
                    score -= min_dist_to_ally * 5.0
            elif role == ROLE_FRONT_LINE:
                # Capitals want some breathing room (dist 2-3) to avoid splash but stay grouped
                if min_dist_to_ally > 1 and min_dist_to_ally <= 3:
                    score += 15.0
                
        if score > best_score:
            best_score = score
            best_hex = h
            
    return best_hex

func _calculate_initial_facing(hex: Vector3i, target: Vector3i) -> int:
    # Use existing GameManager turn calculation logic to point towards target
    var ideal_facing = 0
    var best_dot = -2.0
    var target_vec = HexGrid.hex_to_pixel(target) - HexGrid.hex_to_pixel(hex)
    
    if target_vec.length_squared() < 0.1:
        return 0 # Default facing if on top of target
        
    target_vec = target_vec.normalized()
    
    for i in range(6):
        var dir_vec = HexGrid.get_direction_vec(i)
        var pixel_dir = (HexGrid.hex_to_pixel(dir_vec) - HexGrid.hex_to_pixel(Vector3i.ZERO)).normalized()
        var dot = pixel_dir.dot(target_vec)
        if dot > best_dot:
            best_dot = dot
            ideal_facing = i
            
    return ideal_facing

func _calculate_initial_speed(ship: Node, game_manager: Node) -> int:
    # Baseline logic based on class limits and utility
    var max_speed = ship.adf # Use ADF as a proxy for raw acceleration potential for now
    var target_speed = 0
    
    match ship.ship_class:
        "Assault Scout":
            target_speed = min(10, max_speed * 2) # Very fast initial speed
        "Frigate", "Destroyer":
            target_speed = min(8, max_speed * 2 - 1)
        "Light Cruiser":
            target_speed = min(6, max_speed + 2)
        "Heavy Cruiser", "Battleship":
            target_speed = min(4, max_speed + 1) # Slow capital ships
        "Assault Carrier", "Minelayer":
            target_speed = min(3, max_speed)
        _:
            target_speed = min(2, max_speed)
            
    # Collision Avoidance Check
    # Simulate movement along the chosen facing direction to ensure it won't crash into a planet.
    var safe_speed = target_speed
    var dir_vec = HexGrid.get_direction_vec(ship.facing)
    
    while safe_speed > 0:
        var end_hex = ship.grid_position + (dir_vec * safe_speed)
        var path = HexGrid.get_line_coords(ship.grid_position, end_hex)
        var is_safe = true
        var prev_h = ship.grid_position
        
        # Check against environmental hazards
        for h in path:
            if h in game_manager.planet_hexes:
                is_safe = false
                break
                
            # Gravity crash check (entering hexside opposite planet)
            if prev_h != h:
                for p in game_manager.planet_hexes:
                    if HexGrid.hex_distance(h, p) == 1:
                        var dir_from_prev = HexGrid.get_hex_direction(h, prev_h)
                        var dir_to_planet = HexGrid.get_hex_direction(h, p)
                        if dir_from_prev == (dir_to_planet + 3) % 6:
                            is_safe = false
                            break
            if not is_safe:
                break
            
            # Prevent plotting deployments that immediately fly off the board
            if HexGrid.hex_distance(Vector3i.ZERO, h) > game_manager.map_radius:
                is_safe = false
                break
                
            prev_h = h
                
        if is_safe:
            break
            
        safe_speed -= 1
        
    return safe_speed
