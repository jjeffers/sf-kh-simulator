extends GutTest

var CampaignManagerRef
var CampaignFleetRef

func before_all():
	CampaignManagerRef = load("res://Scripts/CampaignManager.gd")
	CampaignFleetRef = load("res://Scripts/CampaignFleet.gd")

func before_each():
	# Reset campaign manager state
	CampaignManager.fleets = []
	CampaignManager.systems = {}
	CampaignManager.start_circles = []
	CampaignManager.active_encounters = []
	CampaignManager.encounter_attackers = {}
	CampaignManager.upf_ready = false
	
	# Mock some systems
	CampaignManager.systems["Prenglar"] = {"name": "Prenglar", "x": 0, "y": 0, "connections": ["Cassiopeia"]}
	CampaignManager.systems["Cassiopeia"] = {"name": "Cassiopeia", "x": 1, "y": 0, "connections": ["Prenglar"]}

func after_each():
	CampaignManager.fleets = []
	
func test_retreating_fleet_blocks_end_turn():
	var f1 = CampaignFleetRef.new("Task Force 1", "UPF", "Prenglar")
	f1.must_retreat = true
	CampaignManager.fleets.append(f1)
	
	CampaignManager.request_end_turn("UPF")
	assert_false(CampaignManager.upf_ready, "UPF should not be ready if a fleet must retreat and hasn't plotted")

func test_retreating_fleet_allows_end_turn_after_plotting():
	var f1 = CampaignFleetRef.new("Task Force 1", "UPF", "Prenglar")
	f1.must_retreat = true
	CampaignManager.fleets.append(f1)
	
	# Plot move
	var result = CampaignManager.order_fleet_move(f1, "Cassiopeia")
	assert_true(result, "Should be able to plot valid retreat route")
	assert_true(f1.is_moving(), "Fleet should be moving")
	
	CampaignManager.request_end_turn("UPF")
	assert_true(CampaignManager.upf_ready, "UPF should be ready since retreating fleet plotted a move")

func test_retreating_fleet_cannot_plot_to_enemy_system():
	var f1 = CampaignFleetRef.new("Task Force 1", "UPF", "Prenglar")
	f1.must_retreat = true
	CampaignManager.fleets.append(f1)
	
	var f2 = CampaignFleetRef.new("Sathar Swarm", "Sathar", "Cassiopeia")
	f2.add_ship({"class": "Fighter", "hull": 10}) 
	CampaignManager.fleets.append(f2)
	
	var result = CampaignManager.order_fleet_move(f1, "Cassiopeia")
	assert_false(result, "Should not be able to retreat to enemy occupied system")
	assert_false(f1.is_moving(), "Fleet should not be moving")
