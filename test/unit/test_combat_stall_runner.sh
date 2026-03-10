#!/bin/bash
cat << 'EOF' > /home/jdjeffers/sf-kh-simulator/test_combat_stall.gd
extends SceneTree

func _init():
	print("Running Mock Test...")
	
	# We must mock NetworkManager if it's missing, but it's an Autoload.
	# We can't guarantee autoloads work in -s, so maybe we mock `GameManager` lightly?
EOF
