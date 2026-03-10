extends Node

func _ready():
	print("Checking if rpc_id with string exists...")
	var has_rpc = self.has_method("rpc_id")
	print("Has rpc_id string method: ", has_rpc)
	
	print("Done!")
	get_tree().quit()
