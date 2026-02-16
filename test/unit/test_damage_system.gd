extends GutTest

var ship: Ship
var combat_script = load("res://Scripts/Combat.gd")

func before_each():
	ship = Ship.new()
	ship.configure_fighter() # Hull 8, ADF 5, MR 5

func after_each():
	ship.free()

func test_combat_damage_table_lookup():
	# Test Critical Hull (1-10)
	var eff = Combat.get_damage_effect(5)
	assert_eq(eff.type, "Hull")
	assert_eq(eff.mult, 2.0)
	
	# Test Standard Hull (11-45)
	eff = Combat.get_damage_effect(30)
	assert_eq(eff.type, "Hull")
	assert_eq(eff.mult, 1.0)
	
	# Test ADF Hit (46-49)
	eff = Combat.get_damage_effect(48)
	assert_eq(eff.type, "ADF")
	assert_eq(eff.val, -1)
	
	# Test Fire (100+)
	eff = Combat.get_damage_effect(110)
	assert_eq(eff.type, "Fire")
	assert_eq(eff.key, "Electrical")

func test_ship_apply_damage_hull():
	var eff = {"type": "Hull", "mult": 1.0, "text": "Hit"}
	ship.apply_damage_effect(eff, 5)
	assert_eq(ship.hull, 3) # 8 - 5 = 3
	
	eff = {"type": "Hull", "mult": 2.0, "text": "Crit"}
	ship.hull = 10
	ship.apply_damage_effect(eff, 4)
	assert_eq(ship.hull, 2) # 10 - (4*2) = 2

func test_ship_apply_damage_adf():
	assert_eq(ship.current_adf_modifier, 0)
	var eff = {"type": "ADF", "val": - 1, "text": "ADF Hit"}
	ship.apply_damage_effect(eff, 0)
	assert_eq(ship.current_adf_modifier, 1) # Modifier increases
	assert_eq(ship.get_effective_adf(), 4) # 5 - 1

func test_ship_apply_damage_weapon():
	# Fighter has "Assault Rockets"
	var eff = {"type": "Weapon", "list": ["Rocket"], "text": "Wpn Hit"}
	ship.apply_damage_effect(eff, 0)
	
	var w = ship.weapons[0]
	assert_true(w.get("is_crippled", false), "Rocket should be crippled")

func test_fire_damage_stack():
	var eff = {"type": "Fire", "key": "Electrical", "text": "Fire"}
	ship.apply_damage_effect(eff, 0)
	assert_true(ship.has_electrical_fire)
	assert_eq(ship.fire_damage_stack, 20)
