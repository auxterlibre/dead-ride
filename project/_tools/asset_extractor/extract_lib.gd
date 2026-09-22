extends RefCounted

const SOURCE_DIR:String = "res://_not_exported/character"
const MESH_ROOT:String = "res://assets/meshes/characters"
const MATERIAL_DIR:String = "res://assets/materials"
const TEXTURE_DIR:String = "res://assets/textures"
# A backpack is an ITEM, not a body part: SkinManager fills %Backpack from
# BackpackData.mesh/.skin rather than from meshes/characters/<name>/.
const BACKPACK_DIR: String = "res://assets/meshes/backpacks"


# First <p_file> anywhere under p_dir (recursive), "" if absent. Lets manual
# reorganisation of the asset tree win over the default destination.
static func _find_file(p_dir:String, p_file:String) -> String:
	if not DirAccess.dir_exists_absolute(p_dir):
		return ""
	for file in DirAccess.get_files_at(p_dir):
		if file == p_file:
			return "%s/%s" % [p_dir, file]
	for sub in DirAccess.get_directories_at(p_dir):
		var found:String = _find_file("%s/%s" % [p_dir, sub], p_file)
		if found != "":
			return found
	return ""


# Texture with identical content anywhere under p_dir, "" if none. Content
# match survives manual renames.
static func _find_texture_by_content(p_dir:String, p_md5:String) -> String:
	if not DirAccess.dir_exists_absolute(p_dir):
		return ""
	for file in DirAccess.get_files_at(p_dir):
		var path:String = "%s/%s" % [p_dir, file]
		if file.get_extension() == "png" and FileAccess.get_md5(path) == p_md5:
			return path
	for sub in DirAccess.get_directories_at(p_dir):
		var found:String = _find_texture_by_content("%s/%s" % [p_dir, sub], p_md5)
		if found != "":
			return found
	return ""


# Path of the material under p_dir whose albedo texture is p_tex_path, "" if
# none. Finds hand-renamed materials.
static func _find_material_using(p_dir:String, p_tex_path:String) -> String:
	if not DirAccess.dir_exists_absolute(p_dir):
		return ""
	for file in DirAccess.get_files_at(p_dir):
		if file.get_extension() != "tres":
			continue
		var path:String = "%s/%s" % [p_dir, file]
		var mat:BaseMaterial3D = load(path) as BaseMaterial3D
		if mat != null and mat.albedo_texture != null \
				and mat.albedo_texture.resource_path == p_tex_path:
			return path
	for sub in DirAccess.get_directories_at(p_dir):
		var found:String = _find_material_using("%s/%s" % [p_dir, sub], p_tex_path)
		if found != "":
			return found
	return ""


# Part names are the mesh node names with the GLB basename stripped. Empty on failure.
# p_texture_suffixes maps a source texture FILENAME to its variant suffix, so a
# character wearing several atlases at once (the marksman's ghillie suit and
# face net) keeps them apart instead of being flattened onto one. Anything
# unlisted is the primary, "a".
# p_atlas names the texture/material set when several characters share one image
# (the Young Ones are one atlas over two bodies); it defaults to the character.
static func extract_character_body(p_path:String, p_name:String = "",
		p_texture_suffixes: Dictionary = {}, p_atlas: String = "") -> PackedStringArray:
	var saved:PackedStringArray = []
	var packed:PackedScene = load(p_path)
	if packed == null:
		push_error("Could not load %s - has it been imported?" % p_path)
		return saved
	var glb_base:String = p_path.get_file().get_basename()
	var name:String = p_name if p_name != "" else glb_base.to_snake_case()
	var wrapper:Node = packed.instantiate()
	var skeleton:Skeleton3D = wrapper.find_child("Skeleton3D", true, false)
	if skeleton == null:
		push_error("%s has no Skeleton3D - not a character body" % p_path)
		wrapper.free()
		return saved
	if skeleton.get_parent().name != "Rig_Medium":
		# Old-rig models still work on Rig_Medium when the shared bones' rest
		# poses match - their name-based skins are saved alongside the meshes.
		push_warning("%s rig is '%s', not Rig_Medium - extracting anyway" % [
				p_path, skeleton.get_parent().name])

	var mesh_dir:String = MESH_ROOT.path_join(name)
	DirAccess.make_dir_recursive_absolute(mesh_dir)
	var atlas: String = p_atlas if p_atlas != "" else name
	var materials: Dictionary = {}  # source texture path -> the shared material
	for mesh_instance:MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", false, false):
		var mesh:Mesh = mesh_instance.mesh.duplicate()
		# Per SURFACE, not per mesh: a part can mix atlases (the glasses carry
		# two), and one material for the whole body loses every other texture.
		for i in mesh.get_surface_count():
			var material: BaseMaterial3D = shared_material(
					mesh_instance.mesh.surface_get_material(i) as BaseMaterial3D,
					atlas, p_texture_suffixes, materials)
			if material != null:
				mesh.surface_set_material(i, material)
		var part:String = String(mesh_instance.name)
		if part.to_lower().begins_with(glb_base.to_lower() + "_"):
			part = part.substr(glb_base.length() + 1)
		part = part.to_snake_case()
		var mesh_path:String = "%s/%s.tres" % [mesh_dir, part]
		var skin_path:String = "%s/%s_skin.tres" % [mesh_dir, part]
		if part == "backpack":
			DirAccess.make_dir_recursive_absolute(BACKPACK_DIR)
			mesh_path = "%s/%s_backpack.tres" % [BACKPACK_DIR, name]
			skin_path = "%s/%s_backpack_skin.tres" % [BACKPACK_DIR, name]
		mesh.take_over_path(mesh_path)
		save_keeping_uid(mesh, mesh_path)
		saved.append(mesh_path)
		if mesh_instance.skin != null:
			var skin:Skin = mesh_instance.skin.duplicate()
			skin.take_over_path(skin_path)
			save_keeping_uid(skin, skin_path)
	wrapper.free()
	return saved


# One material per distinct source texture, cached for the whole character.
static func shared_material(p_source: BaseMaterial3D, p_name: String,
		p_suffixes: Dictionary, p_cache: Dictionary) -> BaseMaterial3D:
	if p_source == null:
		return null
	var key: String = ""
	if p_source.albedo_texture != null:
		key = p_source.albedo_texture.resource_path
	if p_cache.has(key):
		return p_cache[key]
	var material: BaseMaterial3D = local_material(
			p_source, p_name, p_suffixes.get(key.get_file(), "a"))
	p_cache[key] = material
	return material


# Existing files under materials/ and textures/ are reused, so manual moves and tweaks survive.
# p_suffix is the variant letter or tag: "a" is the primary skin, matching the
# <name>_texture_a.png / <name>_material_a.tres the rest of the kit already uses.
static func local_material(p_source:BaseMaterial3D, p_name:String,
		p_suffix: String = "a") -> BaseMaterial3D:
	if p_source == null:
		return null
	var has_texture:bool = p_source.albedo_texture != null and p_source.albedo_texture.resource_path != ""
	var tex_path:String = ""
	if has_texture and not "::" in p_source.albedo_texture.resource_path:
		tex_path = _find_texture_by_content(
				TEXTURE_DIR, FileAccess.get_md5(p_source.albedo_texture.resource_path))
	if tex_path == "":
		tex_path = _find_file(TEXTURE_DIR, "%s_texture_%s.png" % [p_name, p_suffix])
	if tex_path == "" and has_texture:
		tex_path = "%s/characters/%s/%s_texture_%s.png" % [
				TEXTURE_DIR, p_name, p_name, p_suffix]
		DirAccess.make_dir_recursive_absolute(tex_path.get_base_dir())
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(p_source.albedo_texture.resource_path),
			ProjectSettings.globalize_path(tex_path))
	# A material already using this texture wins even if the file was renamed.
	if has_texture:
		var used:String = _find_material_using(MATERIAL_DIR, tex_path)
		if used != "":
			return load(used)
	var mat_path:String = _find_file(MATERIAL_DIR, "%s_material_%s.tres" % [p_name, p_suffix])
	if mat_path != "":
		var existing:BaseMaterial3D = load(mat_path)
		if existing != null:
			return existing
		# Exists but not loadable yet (texture awaiting import): link by path.
		var stub:StandardMaterial3D = StandardMaterial3D.new()
		stub.take_over_path(mat_path)
		return stub

	mat_path = "%s/characters/%s_material_%s.tres" % [MATERIAL_DIR, p_name, p_suffix]
	DirAccess.make_dir_recursive_absolute(mat_path.get_base_dir())
	var material:BaseMaterial3D = p_source.duplicate()
	if has_texture:
		# take_over_path: reference the copy's final path before it's imported.
		var local_tex:Texture2D = p_source.albedo_texture.duplicate()
		local_tex.take_over_path(tex_path)
		material.albedo_texture = local_tex
	material.resource_name = "%s_material_%s" % [p_name, p_suffix]
	material.take_over_path(mat_path)
	save_keeping_uid(material, mat_path)
	return material


# Runtime ResourceSaver drops uids, orphaning uid:// references - patch them back after saving.
static func save_keeping_uid(p_resource:Resource, p_path:String) -> void:
	var uid:String = ""
	if FileAccess.file_exists(ProjectSettings.globalize_path(p_path)):
		var old_header:String = FileAccess.get_file_as_string(p_path).get_slice("\n", 0)
		var m:RegExMatch = RegEx.create_from_string("uid=\"(uid://[^\"]+)\"").search(old_header)
		if m != null:
			uid = m.get_string(1)
	ResourceSaver.save(p_resource, p_path)
	if uid == "":
		uid = ResourceUID.id_to_text(ResourceUID.create_id())
	var lines:PackedStringArray = FileAccess.get_file_as_string(p_path).split("\n")
	if not "uid=" in lines[0]:
		lines[0] = lines[0].insert(lines[0].find("]"), " uid=\"%s\"" % uid)
	var path_re:RegEx = RegEx.create_from_string("path=\"([^\"]+)\"")
	for i in lines.size():
		if not lines[i].begins_with("[ext_resource") or "uid=" in lines[i]:
			continue
		var pm:RegExMatch = path_re.search(lines[i])
		if pm == null:
			continue
		var dep_uid:String = _uid_of(pm.get_string(1))
		if dep_uid != "":
			lines[i] = lines[i].replace(" path=", " uid=\"%s\" path=" % dep_uid)
	var f:FileAccess = FileAccess.open(p_path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()


# uid of an existing resource file: the .uid sidecar for scripts, the .import
# sidecar for imported assets, the header for text resources. "" when unknown
# (e.g. not yet imported).
static func _uid_of(p_res_path:String) -> String:
	# A script's uid lives in a bare <script>.gd.uid file, not in the script.
	var sidecar: String = p_res_path + ".uid"
	if FileAccess.file_exists(ProjectSettings.globalize_path(sidecar)):
		var text: String = FileAccess.get_file_as_string(sidecar).strip_edges()
		if text.begins_with("uid://"):
			return text
	var source:String = ""
	if FileAccess.file_exists(ProjectSettings.globalize_path(p_res_path + ".import")):
		source = FileAccess.get_file_as_string(p_res_path + ".import")
	elif FileAccess.file_exists(ProjectSettings.globalize_path(p_res_path)):
		source = FileAccess.get_file_as_string(p_res_path).get_slice("\n", 0)
	var m:RegExMatch = RegEx.create_from_string("uid=\"(uid://[^\"]+)\"").search(source)
	return m.get_string(1) if m != null else ""
