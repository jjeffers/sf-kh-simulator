extends SceneTree

func _init():
var scenario_manager = preload("res://Scripts/ScenarioManager.gd").new()
var test_ship = {"ship_class": "Assault Scout", "name": "Rapier", "side_id": 0}
var ships = [test_ship]
# test battle_of_kenzah, side 0
NetworkManager.lobby_data = {"scenario": "battle_of_kenzah"}
var hexes = scenario_manager.get_valid_deployment_hexes(0, ships, [], test_ship)
print("HEXES FOR BATTLE OF KENZAH UPF: ", hexes.size())
quit()
