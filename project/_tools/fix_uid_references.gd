extends SceneTree
# Syncs every ext_resource uid to its target file. Run when "invalid UID" warnings appear.

var ext_regex:RegEx = RegEx.create_from_string("uid=\"(uid://[^\"]+)\" path=\"(res://[^\"]+)\"")
var header_regex:RegEx = RegEx.create_from_string("uid=\"(uid://[^\"]+)\"")


func _init() -> void:
	var fixed:int = scan_dir("res://")
	print("fixed %d stale uid references" % fixed)
	quit()


func scan_dir(p_dir:String) -> int:
	var fixed:int = 0
	for file in DirAccess.get_files_at(p_dir):
		if file.get_extension() in ["tres", "tscn"]:
			fixed += fix_file(p_dir.path_join(file))
	for sub in DirAccess.get_directories_at(p_dir):
		if sub.begins_with("."):
			continue
		fixed += scan_dir(p_dir.path_join(sub))
	return fixed


func fix_file(p_path:String) -> int:
	var text:String = FileAccess.get_file_as_string(p_path)
	var fixed:int = 0
	for m in ext_regex.search_all(text):
		var current:String = m.get_string(1)
		var target:String = m.get_string(2)
		var real:String = uid_of(target)
		if real == "" or real == current:
			continue
		text = text.replace("uid=\"%s\" path=\"%s\"" % [current, target],
			"uid=\"%s\" path=\"%s\"" % [real, target])
		print("- %s: %s -> %s (%s)" % [p_path.get_file(), current, real, target.get_file()])
		fixed += 1
	if fixed > 0:
		var f:FileAccess = FileAccess.open(p_path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	return fixed


func uid_of(p_path:String) -> String:
	if p_path.get_extension() in ["tres", "tscn"] and FileAccess.file_exists(p_path):
		var m:RegExMatch = header_regex.search(FileAccess.get_file_as_string(p_path).get_slice("\n", 0))
		return m.get_string(1) if m != null else ""
	if FileAccess.file_exists(p_path + ".import"):
		var m:RegExMatch = header_regex.search(FileAccess.get_file_as_string(p_path + ".import"))
		return m.get_string(1) if m != null else ""
	if FileAccess.file_exists(p_path + ".uid"):
		return FileAccess.get_file_as_string(p_path + ".uid").strip_edges()
	return ""
