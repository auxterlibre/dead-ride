extends SceneTree

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE: String = "res://_not_exported/items"
const OUT_DIR: String = "res://assets/meshes/weapons/ranged"
const MATERIAL_PATH: String = "res://assets/materials/weapons/weapons_material.tres"
# Already under assets/, unlike the tool kit's atlas - nothing to copy out.
const TEXTURE_PATH: String = "res://assets/textures/weapons/weapons_black.png"
const ROUGHNESS: float = 0.9  # what the survivalist atlas the other weapons wear uses

# Source file -> output name.
const PIECES: Dictionary = {
	"smg": "smg",
}

var material: BaseMaterial3D = null


func _init():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(MATERIAL_PATH.get_base_dir()))
	for source in PIECES:
		var packed: PackedScene = load("%s/%s.glb" % [SOURCE, source])
		if packed == null:
			print("DBG %s did not load - run verify.sh import first" % source)
			continue
		var scene: Node = packed.instantiate()
		var found: Array = scene.find_children("*", "MeshInstance3D", true, false)
		if found.is_empty():
			print("DBG %s has no mesh" % source)
			scene.free()
			continue
		save_mesh(PIECES[source], found, scene)
		scene.free()
	quit()


# Every MeshInstance3D in the source becomes one surface set on a single mesh,
# so a weapon authored as separate parts still arrives as one resource.
func save_mesh(p_name: String, p_instances: Array, p_root: Node):
	var out: ArrayMesh = ArrayMesh.new()
	var parts: int = 0
	for instance: MeshInstance3D in p_instances:
		var mesh: ArrayMesh = instance.mesh as ArrayMesh
		if mesh == null:
			continue
		parts += 1
		var xform: Transform3D = relative_transform(instance, p_root)
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			if not xform.is_equal_approx(Transform3D.IDENTITY):
				bake_transform(arrays, xform)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1,
					shared_material(mesh.surface_get_material(surface)))
	out.resource_name = p_name
	var path: String = "%s/%s.tres" % [OUT_DIR, p_name]
	out.take_over_path(path)
	ExtractLib.save_keeping_uid(out, path)
	print("DBG %-14s %d parts  %d surfaces  aabb %s -> %s" % [p_name, parts,
			out.get_surface_count(), out.get_aabb().size, path])


# Transform of p_node in p_root's space. Accumulated by hand rather than read
# off global_transform, which needs the node to be inside the tree.
func relative_transform(p_node: Node3D, p_root: Node) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var node: Node = p_node
	while node != null and node != p_root:
		if node is Node3D:
			result = (node as Node3D).transform * result
		node = node.get_parent()
	return result


# Folds a part's placement into its vertices, since the surfaces are being
# merged onto one mesh that has no node to carry it.
func bake_transform(p_arrays: Array, p_xform: Transform3D):
	var vertices: PackedVector3Array = p_arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = p_xform * vertices[i]
	p_arrays[Mesh.ARRAY_VERTEX] = vertices
	# Normals take the inverse transpose, or non-uniform scale shears them off
	# the surface; tangents keep their handedness in w.
	var normal_basis: Basis = p_xform.basis.inverse().transposed()
	if p_arrays[Mesh.ARRAY_NORMAL] != null:
		var normals: PackedVector3Array = p_arrays[Mesh.ARRAY_NORMAL]
		for i in normals.size():
			normals[i] = (normal_basis * normals[i]).normalized()
		p_arrays[Mesh.ARRAY_NORMAL] = normals
	if p_arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = p_arrays[Mesh.ARRAY_TANGENT]
		for i in range(0, tangents.size(), 4):
			var t: Vector3 = (p_xform.basis * Vector3(tangents[i],
					tangents[i + 1], tangents[i + 2])).normalized()
			tangents[i] = t.x
			tangents[i + 1] = t.y
			tangents[i + 2] = t.z
		p_arrays[Mesh.ARRAY_TANGENT] = tangents


# One material for every weapon: the source's, albedo swapped to the atlas copy
# that ships. An existing file wins, so hand tweaks survive a re-run.
func shared_material(p_source: Material) -> BaseMaterial3D:
	if material != null:
		return material
	if FileAccess.file_exists(ProjectSettings.globalize_path(MATERIAL_PATH)):
		var existing: BaseMaterial3D = load(MATERIAL_PATH)
		if existing != null:
			material = existing
			return material
	var result: BaseMaterial3D = null
	if p_source is BaseMaterial3D:
		result = (p_source as BaseMaterial3D).duplicate()
	else:
		result = StandardMaterial3D.new()
	result.albedo_texture = load(TEXTURE_PATH)
	result.roughness = ROUGHNESS
	result.resource_name = "weapons_material"
	result.take_over_path(MATERIAL_PATH)
	ExtractLib.save_keeping_uid(result, MATERIAL_PATH)
	material = result
	return material
