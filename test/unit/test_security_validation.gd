extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")

func test_validate_rpc_ownership():
	# Setup
	var gm = GameManagerScript.new()
	add_child(gm)
	
	# Mock Lobby Data on current NetworkManager singleton
	# Note: NetworkManager should be autoloaded.
	# We backup old data to be safe.
	var old_data = NetworkManager.lobby_data.duplicate()
	
	NetworkManager.lobby_data = {
		"teams": {
			100: 1, # Peer 100 -> Side 1
			200: 2, # Peer 200 -> Side 2
		}
	}
	
	# Peer 100 checks Side 1 -> Success
	var res1 = gm._validate_rpc_ownership(100, 1)
	assert_true(res1, "Peer 100 should own Side 1")
	
	# Peer 100 checks Side 2 -> Fail
	var res2 = gm._validate_rpc_ownership(100, 2)
	assert_false(res2, "Peer 100 should NOT own Side 2")
	
	# Host (1) checks Side 2 -> Success
	var res3 = gm._validate_rpc_ownership(1, 2)
	assert_true(res3, "Host (1) should own any side")
	
	# Restore
	NetworkManager.lobby_data = old_data
	
	gm.free()
