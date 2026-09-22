extends SceneTree
# One-off probe, part 4: dump hill_top_e_center vertex data - positions,
# normals, UVs, and the atlas color each UV samples - to explain the chevrons.


func _init():
	var mesh:ArrayMesh = load("res://assets/meshes/environment/terrain/hill_top_e_center.tres")
	var arrays:Array = mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs:PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices:PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var atlas:Image = Image.load_from_file(
			"C:/Projects/Godot/Nowhere/Project/assets/textures/environment/nature_texture.png")
	print("DBG %d vertices, %d indices (%d triangles)" % [
			vertices.size(), indices.size(), indices.size() / 3.0])
	for i in vertices.size():
		var pixel:Color = atlas.get_pixel(
				int(uvs[i].x * atlas.get_width()) % atlas.get_width(),
				int(uvs[i].y * atlas.get_height()) % atlas.get_height())
		print("DBG v%d pos=(%+.2f, %+.2f, %+.2f) n=(%+.2f, %+.2f, %+.2f) uv=(%.4f, %.4f) color=%s" % [
				i, vertices[i].x, vertices[i].y, vertices[i].z,
				normals[i].x, normals[i].y, normals[i].z,
				uvs[i].x, uvs[i].y, pixel.to_html(false)])
	print("DBG triangles: %s" % str(indices))
	quit()
