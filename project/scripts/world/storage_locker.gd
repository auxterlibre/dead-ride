class_name StorageLocker
extends StaticBody3D
# An Inventory over a StorageData mask, so it opens through the container screen.

@export var title: String = "Storage"
@export var layout: StorageData

var storage: Inventory = Inventory.new()


func _ready():
	add_to_group("persistent")
	if layout:
		storage.setup(layout)


func open(_p_player = null):
	if layout == null:
		return
	Signals.container_opened.emit(title, storage)


func save_state() -> Dictionary:
	return {"entries": storage.save_entries()}


func load_state(p_state: Dictionary):
	storage.load_entries(p_state.entries)
