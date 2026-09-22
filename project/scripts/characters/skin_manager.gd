class_name SkinManager
extends Node3D
# Swaps body parts from meshes/<character>/ - a mesh must deform through its own skin.

const PARTS:PackedStringArray = ["arm_left", "arm_right", "body", "head", "leg_left", "leg_right"]

@onready var arm_left: MeshInstance3D = %ArmLeft
@onready var arm_right: MeshInstance3D = %ArmRight
@onready var body: MeshInstance3D = %Body
@onready var head: MeshInstance3D = %Head
@onready var leg_left: MeshInstance3D = %LegLeft
@onready var leg_right: MeshInstance3D = %LegRight
@onready var glasses: MeshInstance3D = get_node_or_null("%Glasses")
@onready var backpack: MeshInstance3D = get_node_or_null("%Backpack")


@onready var mesh_instance_list:Array = [arm_left, arm_right, body, head, leg_left, leg_right]


func update_meshes(path:String):
	path = path.strip_edges().trim_suffix("/")
	for idx in PARTS.size():
		var mesh_path:String = "%s/%s.tres" % [path, PARTS[idx]]
		if not ResourceLoader.exists(mesh_path):
			push_warning("Missing body part: %s" % mesh_path)
			continue
		mesh_instance_list[idx].mesh = load(mesh_path)
		var skin_path:String = "%s/%s_skin.tres" % [path, PARTS[idx]]
		if ResourceLoader.exists(skin_path):
			mesh_instance_list[idx].skin = load(skin_path)


# Equips the data's backpack mesh on the %Backpack slot, or empties the slot
# when the character carries none (any scene-authored preview mesh included).
func update_backpack(p_backpack:BackpackData):
	if backpack == null:
		return
	backpack.mesh = p_backpack.mesh if p_backpack else null
	backpack.skin = p_backpack.skin if p_backpack else null
