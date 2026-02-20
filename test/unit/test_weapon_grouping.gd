extends GutTest

var ShipScript = load("res://Scripts/Ship.gd")

func test_weapon_grouping_logic():
	var ship = ShipScript.new()
	
	# Manually configure weapons for predictability
	ship.weapons = []
	
	# 1. Active Laser (Standard)
	ship.weapons.append({
		"type": "Laser",
		"range": 9,
		"ammo": 999,
		"is_crippled": false
	})
	
	# 2. Another Active Laser (Should group with #1)
	ship.weapons.append({
		"type": "Laser",
		"range": 9,
		"ammo": 999,
		"is_crippled": false
	})
	
	# 3. Rocket Battery (Empty - Should be excluded)
	ship.weapons.append({
		"type": "Rocket Battery",
		"range": 3,
		"ammo": 0,
		"is_crippled": false
	})
	
	# 4. Torpedo (Crippled - Should be excluded)
	ship.weapons.append({
		"type": "Torpedo",
		"range": 4,
		"ammo": 2,
		"is_crippled": true
	})
	
	# 5. Laser Canon (Different type, Active)
	ship.weapons.append({
		"type": "Laser Canon",
		"range": 10,
		"ammo": 999,
		"is_crippled": false
	})
	
	var groups = ship.get_active_weapon_groups()
	
	# Verify Lasers
	assert_true(groups.has("Laser_9"), "Should have Laser group")
	if groups.has("Laser_9"):
		assert_eq(groups["Laser_9"]["count"], 2, "Should have 2 Lasers")
		assert_eq(groups["Laser_9"]["name"], "Laser Battery", "Name should be mapped")
		
	# Verify Rocket Battery (Excluded due to ammo)
	assert_false(groups.has("Rocket Battery_3"), "Empty Rocket Battery should be excluded")
	
	# Verify Torpedo (Excluded due to crippled)
	assert_false(groups.has("Torpedo_4"), "Crippled Torpedo should be excluded")
	
	# Verify Laser Canon
	assert_true(groups.has("Laser Canon_10"), "Should have Laser Canon group")
	if groups.has("Laser Canon_10"):
		assert_eq(groups["Laser Canon_10"]["count"], 1, "Should have 1 Laser Canon")

	ship.free()
