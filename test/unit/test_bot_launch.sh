#!/bin/bash
# test_bot_launch.sh
echo "Launching Host..."
godot --headless --host --scenario surprise_attack --wait 2 > host_bot_test.log 2>&1 &
HOST_PID=$!
sleep 2

echo "Launching Client Bot..."
godot --headless --join 127.0.0.1 --side 2 --bot > client_bot_test.log 2>&1 &
CLIENT_PID=$!
sleep 5

echo "Killing..."
kill -9 $HOST_PID
kill -9 $CLIENT_PID

echo ""
echo "--- HOST RESULTS ---"
grep -i "ai" host_bot_test.log || echo "No AI log found in host"
grep -i "computer" host_bot_test.log || echo "No ComputerOpponent log found in host"
grep -i "bot" host_bot_test.log || echo "No Bot log found in host"

echo ""
echo "--- CLIENT/BOT LOGS (Search for bot/AI) ---"
grep -i "ai" client_bot_test.log || echo "No AI log found in client"
grep -i "computer" client_bot_test.log || echo "No ComputerOpponent log found in client"
grep -i "bot" client_bot_test.log || echo "No Bot log found in client"
