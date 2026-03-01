#!/bin/bash
# Crash isolated debugging script
godot --path . --headless --host --scenario "the_last_stand" --side 1 > user_log.txt 2>&1 &
HOST_PID=$!
sleep 2
godot --path . --headless --join --side 2 >> user_log.txt 2>&1 &
CLIENT_PID=$!
sleep 5
kill $HOST_PID
kill $CLIENT_PID
cat user_log.txt
