# Run this script to launch two instances of the game.
# If 'godot' is not in your PATH, modify the $godotExe variable.

$godotExe = "godot"
# Alternatively, if you know the path:
# $godotExe = "C:\Path\To\Godot_v4.2.exe"

Write-Host "Launching Instance 1 (Host)..."
Start-Process -FilePath $godotExe -ArgumentList "--path ."

Start-Sleep -Seconds 2

Write-Host "Launching Instance 2 (Client)..."
Start-Process -FilePath $godotExe -ArgumentList "--path ."
