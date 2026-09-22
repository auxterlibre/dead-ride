class_name Utils
extends RefCounted

static func get_random_array_item(array:Array):
	return array[randi() % array.size()]


# The marker is invisible and easy to delete in the editor, which silently kills all aiming.
static func resolve_aim_target(p_body:Node3D,
		p_modifier:SkeletonModifier3D) -> Marker3D:
	var target:Marker3D = p_body.get_node_or_null("AimTarget") as Marker3D
	if target == null:
		target = Marker3D.new()
		target.name = "AimTarget"
		target.top_level = true  # world space: never rides the body transform
		p_body.add_child(target)
		push_warning("AimTarget missing on %s - recreated at runtime" % p_body.name)
	if p_modifier and p_modifier.target_node.is_empty():
		p_modifier.target_node = p_modifier.get_path_to(target)
	return target


static func roll_dice(sides:int):
	var dice_roll:int = randi_range(1, sides)
	return dice_roll


static func list_files_in_directory(path):
	var files:Array = []
	var dir := DirAccess.open(path)
	if dir:
		if dir.list_dir_begin() == OK:
			while true:
				var file = dir.get_next()
				if file == "":
					break
				elif not file.begins_with("."): # This would be a directory
					files.append(file)
			dir.list_dir_end()
		else:
			print("Could not open the directory " + path)
	else:
		print("Could not load the path " + path)
	return files


static func get_best_chance_value(dict:Dictionary):
	var total = 0.0
	var random:float = randf()
	var cumulative = 0.0
	var dict_values:Array = dict.values()
	var dict_keys:Array = dict.keys()
	for i in dict_values.size():
		total += dict_values[i]
	if total <= 0:
		return null
	for i in dict_values.size():
		dict_values[i] =  dict_values[i] / total
	for i in dict.size():
		cumulative += dict_values[i]
		if random < cumulative:
			return dict_keys[i]


static func print_log(message:String, add_time_stamp:bool = false):
	var loggin_enabled:bool = ProjectSettings.get_setting("debug/file_logging/enable_file_logging")
	if loggin_enabled:
		var dt:Dictionary = Time.get_datetime_dict_from_system()
		var time:String = "%02d:%02d:%02d" % [dt.hour,dt.minute,dt.second]
		if add_time_stamp:
			print("%s\n%s\n\n" % [time, message])
		else:
			print("%s\n\n" % message)
