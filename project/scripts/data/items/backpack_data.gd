class_name BackpackData
extends ItemData

@export var slots: int = 6  # quick-bar total; the first 2 are the weapon slots
@export var storage: StorageData  # the grid layout this pack opens to
@export var mesh: Mesh
@export var skin: Skin  # the Skin the mesh was exported with - binds it to the rig
