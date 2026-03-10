extends SceneTree

func _init():
	var file_path = "user://campaign_save2.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("FAILED TO OPEN")
		quit()
		return
	
	var text = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(text)
	
	if err == OK:
		print("DAY: ", json.data.get("current_day", "NOT FOUND"))
	else:
		print("PARSE ERROR: ", json.get_error_message())
	quit()
