@tool
extends EditorPlugin

const PROBE_ROOT: String = "res://_tools/probes"
# Hand-picked: everything else under _tools/ is a component or a CLI driver,
# and no scan rule separates those from a scene worth opening.
const SCENES: Dictionary = {
	"Gym": "res://_tools/gym/gym.tscn",
	"Zoo": "res://_tools/zoo/zoo.tscn",
	"Icon studio": "res://_tools/asset_extractor/icon_studio.tscn",
}

var menu: MenuButton


func _enter_tree():
	menu = MenuButton.new()
	menu.text = "Scenes"
	menu.icon = EditorInterface.get_editor_theme().get_icon(
			"PackedScene", "EditorIcons")
	menu.switch_on_hover = true
	# Rebuilt per open, so a new probe shows up without restarting the editor.
	menu.about_to_popup.connect(rebuild)
	listen(menu.get_popup())
	add_control_to_container(CONTAINER_TOOLBAR, menu)


func _exit_tree():
	remove_control_from_container(CONTAINER_TOOLBAR, menu)
	menu.queue_free()


func rebuild():
	var popup: PopupMenu = menu.get_popup()
	reset(popup)
	var main: String = main_scene_path()
	if main != "":
		add_entry(popup, "Game", main)
		popup.add_separator()
	for label in SCENES:
		if ResourceLoader.exists(SCENES[label]):
			add_entry(popup, label, SCENES[label])
	popup.add_separator()
	add_probes(popup)


func open(p_index: int, p_popup: PopupMenu):
	var path: Variant = p_popup.get_item_metadata(p_index)
	if path is String:
		EditorInterface.open_scene_from_path(path)


# One submenu per probe subject folder, off the *_probe.tscn naming convention.
func add_probes(p_popup: PopupMenu):
	var probes: PopupMenu = submenu("Probes")
	for folder in sorted(DirAccess.get_directories_at(PROBE_ROOT)):
		var group: PopupMenu = submenu(folder)
		var directory: String = "%s/%s" % [PROBE_ROOT, folder]
		for file in sorted(DirAccess.get_files_at(directory)):
			if file.ends_with("_probe.tscn"):
				add_entry(group, title(file), "%s/%s" % [directory, file])
		if group.item_count == 0:
			group.free()
			continue
		probes.add_submenu_node_item(folder.capitalize(), group)
	p_popup.add_submenu_node_item("Probes", probes)


# The path rides as METADATA, not as the item id: separators and submenu items
# take auto-assigned ids that collide with anything id-keyed.
func add_entry(p_popup: PopupMenu, p_label: String, p_path: String):
	p_popup.add_item(p_label)
	p_popup.set_item_metadata(p_popup.item_count - 1, p_path)


func submenu(p_name: String) -> PopupMenu:
	var popup: PopupMenu = PopupMenu.new()
	popup.name = p_name
	listen(popup)
	return popup


func listen(p_popup: PopupMenu):
	p_popup.index_pressed.connect(open.bind(p_popup))


# clear() leaves the submenu nodes parented, so they have to go by hand or the
# next rebuild stacks a second set under mangled names.
func reset(p_popup: PopupMenu):
	p_popup.clear()
	for child in p_popup.get_children():
		p_popup.remove_child(child)
		child.queue_free()


# The setting holds a uid, not a path, on any project saved by 4.4 or later.
func main_scene_path() -> String:
	var setting: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if not setting.begins_with("uid://"):
		return setting
	var id: int = ResourceUID.text_to_id(setting)
	return ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""


func title(p_file: String) -> String:
	return p_file.get_basename().trim_suffix("_probe").capitalize()


func sorted(p_names: PackedStringArray) -> PackedStringArray:
	p_names.sort()
	return p_names
