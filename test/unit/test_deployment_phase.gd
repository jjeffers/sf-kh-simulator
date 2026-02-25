extends GutTest

var gm_class = load("res://Scripts/GameManager.gd")
var gm = null

func before_each():
	gm = gm_class.new()
	add_child(gm)

func after_each():
	if is_instance_valid(gm):
		gm.queue_free()

func test_start_deployment_phase():
	# Stub the UI building methods, they try to add nodes we might not have set up completely
	# But in headless they usually pass if we don't click anything
	gm.setup_game(12345, "simple_test")
	
	assert_eq(gm.current_phase, gm.Phase.DEPLOYMENT, "Phase should be DEPLOYMENT")
	assert_eq(gm.deployment_subphase, 2, "Deployment should start with side 2")
	assert_false(gm.has_deployed_side_1, "Side 1 not deployed")
	assert_false(gm.has_deployed_side_2, "Side 2 not deployed")

func test_deployment_rpc_transitions_phase():
	gm.setup_game(12345, "simple_test")
	
	# Simulate Side 2 deploying
	var state_side_2 = {}
	# In simple_test, side 2 is Sathar. Let's just submit empty or partial since it only checks the keys matching ship names
	gm.rpc_submit_deployment(2, state_side_2)
	assert_true(gm.has_deployed_side_2, "Side 2 should be marked deployed")
	assert_eq(gm.deployment_subphase, 1, "Side 1 should now be deploying")
	assert_eq(gm.current_phase, gm.Phase.DEPLOYMENT, "Phase is still DEPLOYMENT")
	
	# Simulate Side 1 deploying
	var state_side_1 = {}
	gm.rpc_submit_deployment(1, state_side_1)
	assert_true(gm.has_deployed_side_1, "Side 1 should be marked deployed")
	
	# The game transitions to MOVEMENT
	assert_eq(gm.current_phase, gm.Phase.MOVEMENT, "Phase should transition to MOVEMENT after both deploy")
