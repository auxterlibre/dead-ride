extends SceneTree

const ROOTS: Array[String] = ["res://scripts", "res://_tools"]
const SKIP_USAGE: int = PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP \
		| PROPERTY_USAGE_SUBGROUP

var globals: Dictionary = {}


func _init():
	for entry in ProjectSettings.get_global_class_list():
		globals[entry["class"]] = entry
	var found: int = 0
	for root in ROOTS:
		found += scan_dir(root)
	print("DBG shadow_check: %d shadowed name%s" % [found, "" if found == 1 else "s"])
	quit(1 if found > 0 else 0)


func scan_dir(p_dir: String) -> int:
	var found: int = 0
	for file in DirAccess.get_files_at(p_dir):
		if file.ends_with(".gd"):
			found += scan_file("%s/%s" % [p_dir, file])
	for sub in DirAccess.get_directories_at(p_dir):
		found += scan_dir("%s/%s" % [p_dir, sub])
	return found


func scan_file(p_path: String) -> int:
	var lines: PackedStringArray = FileAccess.get_file_as_string(p_path).split("\n")
	var members: Dictionary = members_of(base_of(lines))
	if members.is_empty():
		return 0
	var pattern: RegEx = RegEx.create_from_string(
			"^\\s*(?:var|const)\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var found: int = 0
	for i in lines.size():
		var hit: RegExMatch = pattern.search(lines[i])
		if hit == null or not members.has(hit.get_string(1)):
			continue
		print("DBG SHADOW %s:%d  %s  (%s declares it)" % [p_path.trim_prefix("res://"),
				i + 1, hit.get_string(1), members[hit.get_string(1)]])
		found += 1
	return found


func base_of(p_lines: PackedStringArray) -> String:
	for line in p_lines:
		if line.begins_with("extends "):
			return line.substr(8).strip_edges()
	return ""


func members_of(p_base: String) -> Dictionary:
	var result: Dictionary = {}
	var walk: String = p_base
	var guard: int = 0
	while walk != "" and guard < 32:
		guard += 1
		if ClassDB.class_exists(walk):
			for prop in ClassDB.class_get_property_list(walk):
				if not (prop.usage & SKIP_USAGE):
					result[prop.name] = walk
			for entry in ClassDB.class_get_signal_list(walk):
				result[entry.name] = walk
			return result
		if not globals.has(walk):
			return result
		var lines: PackedStringArray = FileAccess.get_file_as_string(
				globals[walk].path).split("\n")
		var pattern: RegEx = RegEx.create_from_string(
				"^(?:var|const|signal)\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
		for line in lines:
			var hit: RegExMatch = pattern.search(line)
			if hit:
				result[hit.get_string(1)] = walk
		walk = base_of(lines)
	return result
