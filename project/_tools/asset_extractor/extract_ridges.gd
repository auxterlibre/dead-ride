extends SceneTree
# Carves 1-wide ridge pieces from the stadium prefabs; cut edges share a plane so they mate flush.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE:String = "res://_not_exported/environment/hills"
const TERRAIN_DIR:String = "res://assets/meshes/environment/terrain"
const MATERIAL_PATH:String = "res://assets/materials/environment/nature_material_a.tres"

const CELL:float = 3.0
const JUNCTION:float = 1.0   # measured: the prefab's straight run spans |x| <= 1
const TIP:float = 1.23       # end tip x inside its cell - e_cap's 0.27 edge margin
const ROOT_DEPTH:float = 0.3 # kit cliffs continue below their base; carved ones must too
const EPS:float = 0.0001

# A soup is an Array of triangles; a triangle is 3 verts of [position, normal, uv].
var material:Material = null
var saved:int = 0


func _init():
	material = load(MATERIAL_PATH)
	var short_parts:Array = assemblies("Hill_4x2x2", 2.0)
	var tall_parts:Array = assemblies("Hill_4x2x4", 4.0)
	emit_pieces("hill_top", short_parts[0], false)
	emit_pieces("hill_cliff", short_parts[1], true)
	emit_pieces("hill_cliff_tall", tall_parts[1], true)
	print("DBG extracted %d ridge pieces into %s" % [saved, TERRAIN_DIR])
	quit()


# Strip (straight run stretched to cell pitch) and end (cap half + shortened
# run) for one assembly, saved in every orientation the autotiler names.
func emit_pieces(p_prefix:String, p_assembly:Array, p_rooted:bool):
	var stretch:Transform3D = Transform3D(
			Basis.from_scale(Vector3(CELL / (JUNCTION * 2.0), 1, 1)), Vector3.ZERO)
	var strip:Array = transformed(middle(p_assembly), stretch)

	var cap:Array = clip_half(p_assembly, -1, 0, -JUNCTION)
	var src_tip:float = -INF
	for tri in cap:
		for vert in tri:
			src_tip = maxf(src_tip, vert[0].x)
	# The cap slides so its tip lands at TIP; the straight run squashes to
	# bridge from the cell's connecting edge to the displaced junction.
	var junction_x:float = TIP - (src_tip - JUNCTION)
	var run_scale:float = (junction_x + CELL / 2.0) / (JUNCTION * 2.0)
	var run:Transform3D = Transform3D(Basis.from_scale(Vector3(run_scale, 1, 1)),
			Vector3((junction_x - CELL / 2.0) / 2.0, 0, 0))
	var end_piece:Array = transformed(cap,
			Transform3D(Basis.IDENTITY, Vector3(TIP - src_tip, 0, 0)))
	end_piece.append_array(transformed(middle(p_assembly), run))

	if p_rooted:
		strip.append_array(root_band(strip))
		end_piece.append_array(root_band(end_piece))
	strip = seam_finished(strip, [-CELL / 2.0, CELL / 2.0])
	end_piece = seam_finished(end_piece, [-CELL / 2.0])

	save_piece(p_prefix + "_strip_ew", strip)
	save_piece(p_prefix + "_strip_ns", rotated(strip, PI / 2))
	var tips:Dictionary = {"n": PI / 2, "s": -PI / 2, "w": PI, "e": 0.0}
	for dir in tips:
		save_piece("%s_end_%s" % [p_prefix, dir], rotated(end_piece, tips[dir]))

	# The canonical bend connects S+E arms (exposed NW corner = the kit's "a").
	var quadrant:Array = clip_half(clip_half(rotated(transformed(cap,
			Transform3D(Basis.IDENTITY, Vector3(TIP - src_tip, 0, 0))),
			PI * 0.75), 1, 0, 0), 0, 1, 0)
	if p_rooted:
		quadrant.append_array(root_band(quadrant))
	var bend:Array = quadrant
	bend.append_array(clip_half(clip_half(strip, -1, 0, 0), -1, 1, 0))
	bend.append_array(clip_half(clip_half(rotated(strip, -PI / 2), 0, -1, 0), 1, -1, 0))
	var corners:Dictionary = {"a": 0.0, "g": PI / 2, "i": PI, "c": -PI / 2}
	for letter in corners:
		save_piece("%s_bend_%s" % [p_prefix, letter], rotated(bend, corners[letter]))


# Splits a prefab into [top, cliff] by welded island; the top drops so its walk plane sits at y 0.
func assemblies(p_name:String, p_surface:float) -> Array:
	var scene:Node = (load(SOURCE + "/" + p_name + ".gltf") as PackedScene).instantiate()
	var mesh:ArrayMesh = (scene.find_children("*", "MeshInstance3D", true, false)[0]
			as MeshInstance3D).mesh
	var arrays:Array = mesh.surface_get_arrays(0)
	scene.free()
	var positions:PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs:PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices:PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var parent:PackedInt32Array = PackedInt32Array()
	parent.resize(positions.size())
	for i in positions.size():
		parent[i] = i
	for i in range(0, indices.size(), 3):
		union(parent, indices[i], indices[i + 1])
		union(parent, indices[i + 1], indices[i + 2])
	var island_low:Dictionary = {}
	for i in indices:
		var island:int = find(parent, i)
		island_low[island] = minf(island_low.get(island, INF), positions[i].y)

	var top:Array = []
	var cliff:Array = []
	for i in range(0, indices.size(), 3):
		var tri:Array = []
		for k in 3:
			var v:int = indices[i + k]
			tri.append([positions[v], normals[v], uvs[v]])
		if island_low[find(parent, indices[i])] > p_surface - 0.75:
			top.append(tri)
		else:
			cliff.append(tri)
	print("DBG %s: %d islands, %d top tris, %d cliff tris" % [
			p_name, island_low.size(), top.size(), cliff.size()])
	return [transformed(top, Transform3D(Basis.IDENTITY, Vector3(0, -p_surface, 0))), cliff]


func find(p_parent:PackedInt32Array, p_i:int) -> int:
	var i:int = p_i
	while p_parent[i] != i:
		p_parent[i] = p_parent[p_parent[i]]
		i = p_parent[i]
	return i


func union(p_parent:PackedInt32Array, p_a:int, p_b:int):
	p_parent[find(p_parent, p_a)] = find(p_parent, p_b)


# The straight run between the two cap junctions.
func middle(p_soup:Array) -> Array:
	return clip_half(clip_half(p_soup, -1, 0, JUNCTION), 1, 0, JUNCTION)


# Sutherland-Hodgman clip of every triangle against a vertical plane, keeping
# the side where nx*x + nz*z <= d. Verts on the plane stay on both sides.
func clip_half(p_soup:Array, p_nx:float, p_nz:float, p_d:float) -> Array:
	var result:Array = []
	for tri in p_soup:
		var poly:Array = []
		for i in 3:
			var a:Array = tri[i]
			var b:Array = tri[(i + 1) % 3]
			var side_a:float = p_nx * a[0].x + p_nz * a[0].z
			var side_b:float = p_nx * b[0].x + p_nz * b[0].z
			if side_a <= p_d + EPS:
				poly.append(a)
			if (side_a <= p_d + EPS) != (side_b <= p_d + EPS):
				var t:float = (p_d - side_a) / (side_b - side_a)
				poly.append([a[0].lerp(b[0], t),
						a[1].lerp(b[1], t).normalized(), a[2].lerp(b[2], t)])
		for i in range(1, poly.size() - 1):
			var area:Vector3 = (poly[i][0] - poly[0][0]).cross(poly[i + 1][0] - poly[0][0])
			if area.length_squared() > 0.000000000001:
				result.append([poly[0], poly[i], poly[i + 1]])
	return result


func transformed(p_soup:Array, p_transform:Transform3D) -> Array:
	var normal_basis:Basis = p_transform.basis.inverse().transposed()
	var result:Array = []
	for tri in p_soup:
		var out:Array = []
		for vert in tri:
			out.append([p_transform * vert[0],
					(normal_basis * vert[1]).normalized(), vert[2]])
		result.append(out)
	return result


func rotated(p_soup:Array, p_angle:float) -> Array:
	return transformed(p_soup, Transform3D(Basis(Vector3.UP, p_angle), Vector3.ZERO))


# Connecting edges get seam finishing: normals welded flat across the cut (both
# sides of a cell seam then shade alike) and open cross-sections capped.
func seam_finished(p_soup:Array, p_planes:Array) -> Array:
	var soup:Array = p_soup
	for plane in p_planes:
		soup = welded(soup, plane)
		soup.append_array(caps(soup, plane, 1.0 if plane > 0.0 else -1.0))
	return soup


# Zeroes the run-axis normal component of verts on the cut plane - mirrored
# neighbors produce the same welded normal, so the seam stops catching light.
func welded(p_soup:Array, p_plane:float) -> Array:
	var result:Array = []
	for tri in p_soup:
		var out:Array = []
		for vert in tri:
			var flat:Vector2 = Vector2(vert[1].y, vert[1].z)
			if absf(vert[0].x - p_plane) < 0.002 and flat.length() > 0.05:
				out.append([vert[0], Vector3(0, flat.x, flat.y).normalized(), vert[2]])
			else:
				out.append(vert)
		result.append(out)
	return result


# Fills open cross-sections with dirt fans; flush neighbours hide them back to back.
func caps(p_soup:Array, p_plane:float, p_outward:float) -> Array:
	var counts:Dictionary = {}
	var edges:Dictionary = {}
	for tri in p_soup:
		for i in 3:
			var a:Array = tri[i]
			var b:Array = tri[(i + 1) % 3]
			var key:String = edge_key(a[0], b[0])
			counts[key] = counts.get(key, 0) + 1
			edges[key] = [a, b]
	var boundary:Array = []
	var adjacency:Dictionary = {}
	for key in counts:
		if counts[key] != 1:
			continue
		var a:Array = edges[key][0]
		var b:Array = edges[key][1]
		if absf(a[0].x - p_plane) > 0.002 or absf(b[0].x - p_plane) > 0.002:
			continue
		for node in [point_key(a[0]), point_key(b[0])]:
			if not adjacency.has(node):
				adjacency[node] = []
			adjacency[node].append(boundary.size())
		boundary.append([a, b])

	var result:Array = []
	var used:Dictionary = {}
	for start in boundary.size():
		if used.has(start):
			continue
		used[start] = true
		var chain:Array = [boundary[start][0], boundary[start][1]]
		for direction in 2:
			while true:
				var tip:Array = chain.back() if direction == 0 else chain.front()
				var next:int = -1
				for id in adjacency[point_key(tip[0])]:
					if not used.has(id):
						next = id
						break
				if next == -1:
					break
				used[next] = true
				var a:Array = boundary[next][0]
				var far:Array = boundary[next][1] \
						if point_key(a[0]) == point_key(tip[0]) else a
				if direction == 0:
					chain.append(far)
				else:
					chain.push_front(far)
		if chain.size() > 2 and point_key(chain.front()[0]) == point_key(chain.back()[0]):
			chain.pop_back()
		result.append_array(fan(chain, p_outward))
	return result


# Triangulates one boundary chain (fan from its centroid, the open side closed
# by the wrap-around chord). Skips degenerate shell-line chains.
func fan(p_chain:Array, p_outward:float) -> Array:
	if p_chain.size() < 3:
		return []
	var shoelace:float = 0.0
	for i in p_chain.size():
		var a:Vector3 = p_chain[i][0]
		var b:Vector3 = p_chain[(i + 1) % p_chain.size()][0]
		shoelace += a.y * b.z - b.y * a.z
	if absf(shoelace) / 2.0 < 0.005:
		return []
	if shoelace * p_outward < 0.0:
		p_chain.reverse()
	var normal:Vector3 = Vector3(p_outward, 0, 0)
	var center:Vector3 = Vector3.ZERO
	var dirt:Array = p_chain[0]
	for vert in p_chain:
		center += vert[0] / p_chain.size()
		if vert[0].y < dirt[0].y:
			dirt = vert
	var result:Array = []
	for i in p_chain.size():
		var a:Vector3 = p_chain[i][0]
		var b:Vector3 = p_chain[(i + 1) % p_chain.size()][0]
		result.append([[center, normal, dirt[2]], [a, normal, dirt[2]], [b, normal, dirt[2]]])
	return result


func point_key(p_point:Vector3) -> String:
	return "%d,%d,%d" % [roundi(p_point.x * 10000),
			roundi(p_point.y * 10000), roundi(p_point.z * 10000)]


# Downward wall quads under every open boundary edge lying on the base plane:
# buried at ground contact, they fill the joint when cliffs stack.
func root_band(p_soup:Array) -> Array:
	var counts:Dictionary = {}
	var samples:Dictionary = {}
	for tri in p_soup:
		for i in 3:
			var a:Array = tri[i]
			var b:Array = tri[(i + 1) % 3]
			var key:String = edge_key(a[0], b[0])
			counts[key] = counts.get(key, 0) + 1
			samples[key] = [a, b]
	var band:Array = []
	for key in counts:
		if counts[key] != 1:
			continue
		var a:Array = samples[key][0]
		var b:Array = samples[key][1]
		if a[0].y > 0.005 or b[0].y > 0.005:
			continue
		var drop:Vector3 = Vector3(0, -ROOT_DEPTH, 0)
		var normal:Vector3 = (a[0] - b[0]).cross(drop).normalized()
		var ad:Array = [a[0] + drop, normal, a[2]]
		var bd:Array = [b[0] + drop, normal, b[2]]
		band.append([[b[0], normal, b[2]], [a[0], normal, a[2]], ad])
		band.append([[b[0], normal, b[2]], ad, bd])
	return band


func edge_key(p_a:Vector3, p_b:Vector3) -> String:
	var qa:String = "%d,%d,%d" % [roundi(p_a.x * 10000), roundi(p_a.y * 10000), roundi(p_a.z * 10000)]
	var qb:String = "%d,%d,%d" % [roundi(p_b.x * 10000), roundi(p_b.y * 10000), roundi(p_b.z * 10000)]
	return qa + "|" + qb if qa < qb else qb + "|" + qa


func save_piece(p_name:String, p_soup:Array):
	var positions:PackedVector3Array = PackedVector3Array()
	var normals:PackedVector3Array = PackedVector3Array()
	var uvs:PackedVector2Array = PackedVector2Array()
	for tri in p_soup:
		for vert in tri:
			positions.append(vert[0])
			normals.append(vert[1])
			uvs.append(vert[2])
	var arrays:Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh:ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	mesh.resource_name = p_name
	var path:String = "%s/%s.tres" % [TERRAIN_DIR, p_name]
	mesh.take_over_path(path)
	ExtractLib.save_keeping_uid(mesh, path)
	saved += 1
	var aabb:AABB = mesh.get_aabb()
	print("DBG %-24s %4d tris  x[%+.2f..%+.2f] y[%+.2f..%+.2f] z[%+.2f..%+.2f]" % [
			p_name, p_soup.size(), aabb.position.x, aabb.end.x,
			aabb.position.y, aabb.end.y, aabb.position.z, aabb.end.z])
