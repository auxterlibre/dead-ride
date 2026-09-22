@tool
class_name Ground
extends StaticBody3D

const THICKNESS: float = 2.0  # how far the collision box reaches below the surface

@onready var surface: MeshInstance3D = $Surface
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready():
	fit_collision()


# The plane is the authority; resize it and the box under it follows.
func fit_collision():
	var plane: PlaneMesh = surface.mesh as PlaneMesh
	var box: BoxShape3D = collision.shape as BoxShape3D
	if plane == null or box == null:
		return
	box.size = Vector3(plane.size.x, THICKNESS, plane.size.y)
	collision.position = Vector3(0.0, -THICKNESS * 0.5, 0.0)


# Terrain columns this floor covers, for the painter's height field. Read off
# the sibling map's cell size rather than a constant of its own, so the two
# grids cannot drift apart.
func columns() -> Rect2i:
	var plane: PlaneMesh = surface.mesh as PlaneMesh
	var map: GridMap = get_parent().get_node_or_null("TerrainFloors") as GridMap
	if plane == null or map == null:
		return Rect2i()
	var cell: Vector2 = Vector2(map.cell_size.x, map.cell_size.z)
	var corner: Vector2 = (Vector2(global_position.x, global_position.z)
			- plane.size * 0.5) / cell
	return Rect2i(Vector2i(corner.round()), Vector2i((plane.size / cell).round()))
