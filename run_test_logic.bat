@echo off
echo Running test...
"c:\Program Files\Godot_v4.6-stable_win64.exe" --headless --path . -s addons/gut/gut_cmdln.gd -- -gtest=res://test/unit/test_turn_cycle.gd > test_output_cycle_12.txt 2>&1
echo Done.
type test_output_cycle_12.txt
