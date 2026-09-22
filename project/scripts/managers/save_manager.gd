extends Node
# One save, one rolling backup. Anything in the `persistent` group that was
# AUTHORED into the scene (owner != null - runtime spawns like traffic have
# none) contributes a save_state() Dictionary under its scene-relative path
# and gets it back through load_state() after a fresh scene reload. Enemies
# are deliberately absent: camps repopulate at their posts on every load.

const VERSION: int = 2  # v2: quick slots save their own stacks, not grid indices

# Vars, not consts: probes point these at scratch files so a headless run can
# never overwrite the player's real save.
var save_path: String = "user://save.json"
var backup_path: String = "user://save.bak"
var pending: Dictionary = {}
var item_index: Dictionary = {}  # item name -> resource path, built on demand


func save_game():
	var scene: Node = get_tree().current_scene
	var state: Dictionary = {
		"version": VERSION,
		"calendar": Calendar.time_data.get_save_dict(),
		"money": PlayerData.current_money,
		"nodes": {},
	}
	for node in get_tree().get_nodes_in_group("persistent"):
		if node.owner == null:
			continue  # spawned at runtime; the fresh scene won't have it
		state.nodes[str(scene.get_path_to(node))] = node.save_state()
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),
				ProjectSettings.globalize_path(backup_path))
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(state, "\t"))
	file.close()


func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(backup_path)


# Reload the scene fresh, then lay the state over it - the same flow respawn
# proved out, so no diffing of a live world.
func load_game() -> bool:
	var state: Dictionary = read_state()
	if state.is_empty():
		return false
	pending = state
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()
	apply_when_ready.call_deferred()
	return true


func apply_when_ready():
	# Wait for FACTS, not frame counts: the swap lands at frame's end (current
	# scene is briefly null), and Character.apply_data defers its loadout one
	# more frame. The barrier is a live scene CONTAINING an armed player -
	# checking the player alone once matched the old, not-yet-freed one.
	# Capped so a playerless scene cannot hang the load forever.
	var patience: int = 60
	while patience > 0:
		var scene: Node = get_tree().current_scene
		var player: Character = InputManager.player
		if scene != null and player != null and scene.is_ancestor_of(player) \
				and player.carried != null and player.carried.quick_slots.size() > 0:
			break
		patience -= 1
		await get_tree().process_frame
	var state: Dictionary = pending
	pending = {}
	# JSON numbers parse as floats; TimeData's fields are typed ints.
	var calendar: Dictionary = {}
	for key in state.calendar:
		calendar[key] = int(state.calendar[key])
	Calendar.time_data.get_data_from_file(calendar)
	Signals.calendar_updated.emit(Calendar.time_data)
	PlayerData.current_money = int(state.money)
	Signals.money_changed.emit(PlayerData.current_money)
	var root: Node = get_tree().current_scene
	for key in state.nodes:
		var node: Node = root.get_node_or_null(NodePath(key))
		if node and node.has_method("load_state"):
			node.load_state(state.nodes[key])


# The save, or the backup when the save is missing or corrupt.
func read_state() -> Dictionary:
	for path in [save_path, backup_path]:
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("version", 0) == VERSION:
			return parsed
	return {}


# Runtime item copies (a looted gun, the starting loadout's duplicates) carry
# NO resource_path, so identity falls back to the item's unique name against a
# one-time walk of data/items.
func item_path(p_item: ItemData) -> String:
	if p_item.resource_path != "":
		return p_item.resource_path
	if item_index.is_empty():
		index_items("res://data/items")
	return item_index.get(p_item.name, "")


func index_items(p_dir: String):
	for file in DirAccess.get_files_at(p_dir):
		if file.ends_with(".tres"):
			var item: ItemData = load(p_dir + "/" + file) as ItemData
			if item:
				item_index[item.name] = p_dir + "/" + file
	for dir in DirAccess.get_directories_at(p_dir):
		index_items(p_dir + "/" + dir)
