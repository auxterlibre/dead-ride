class_name OutfitManager
extends Node3D

const PARTS_DIR: String = "res://assets/meshes/humanoid/parts"

var worn: Dictionary = {}

@onready var skeleton: Skeleton3D = %GeneralSkeleton


func update_meshes(p_path: String):
	if not p_path.ends_with(".tres"):
		push_warning("OutfitManager expects an OutfitData path, got '%s'" % p_path)
		return
	wear(load(p_path) as OutfitData)


func wear(p_outfit: OutfitData):
	for slot in worn:
		worn[slot].free()
	worn.clear()
	if p_outfit == null:
		return
	for part in p_outfit.parts:
		wear_part(part)


func wear_part(p_part: String):
	var mesh_path: String = "%s/%s.tres" % [PARTS_DIR, p_part]
	if not ResourceLoader.exists(mesh_path):
		push_warning("Missing outfit part: %s" % mesh_path)
		return
	var slot: String = OutfitData.slot_of(p_part)
	if worn.has(slot):
		worn[slot].free()
		worn.erase(slot)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = slot.to_pascal_case()
	instance.mesh = load(mesh_path)
	var skin_path: String = "%s/%s_skin.tres" % [PARTS_DIR, p_part]
	if ResourceLoader.exists(skin_path):
		instance.skin = load(skin_path)
	skeleton.add_child(instance)
	worn[slot] = instance


func update_backpack(_p_backpack):
	pass
