extends SceneTree
# Pulls the KayKit character sources under _not_exported/characters into game-ready meshes.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE: String = "res://_not_exported/characters"
const WEAPON_DIR: String = "res://assets/meshes/weapons"
const TEXTURE_DIR: String = "res://assets/textures/characters"
const MATERIAL_DIR: String = "res://assets/materials/characters"

# Source glb -> {name, atlas}. The pack's "Protagonist" is this project's Young
# Ones: A and B are two bodies, not two skins of one, but their atlas is the
# same image byte for byte - so it is named for the pair rather than either.
# THE LIST OUTLIVES THE FILES: _not_exported is staging and gets emptied, so an
# entry whose glb is gone is SKIPPED, not an error - it is the record of what
# this kit is made of, and re-dropping a source re-runs its own line.
const CHARACTERS: Dictionary = {
	"lumberjack/Werewolf_Man.glb": {"name": "lumberjack"},
	"marksman/Marksman.glb": {"name": "marksman"},
	"young_ones/Protagonist_A.glb": {"name": "young_one_a", "atlas": "young_ones"},
	"young_ones/Protagonist_B.glb": {"name": "young_one_b", "atlas": "young_ones"},
	"Engineer.glb": {"name": "engineer"},
}

# Source texture filename -> variant suffix, for characters wearing more than
# one atlas at once. Unlisted textures are the primary skin, "a".
const TEXTURE_SUFFIXES: Dictionary = {
	"Marksman_marksman_foliage_texture.png": "foliage",
	"Marksman_marksman_face_net_texture.png": "face_net",
}

# Spare skins no mesh references, copied so they are on hand the way the
# driver's second skin already is.
const SPARE_TEXTURES: Dictionary = {
	"lumberjack/werewolf_B.png": {"name": "lumberjack", "suffix": "b"},
}

# The rifle ships beside the marksman and wears his atlases, but the .gltf
# carries no albedo of its own - surface material NAME is the only link.
const RIFLE_SOURCE: String = "marksman/Marksman_Rifle.gltf"
const RIFLE_PIECES: Dictionary = {
	"Marksman_Rifle": "sniper_rifle",
	"Marksman_Rifle_Ghilliewrap": "sniper_rifle_ghillie",
}
const RIFLE_MATERIALS: Dictionary = {
	"marksman": "marksman_material_a.tres",
	"marksman_ghillie": "marksman_material_foliage.tres",
}


func _init():
	for source in CHARACTERS:
		var spec: Dictionary = CHARACTERS[source]
		var name: String = spec.name
		if not staged(source):
			print("DBG %-12s skipped: %s is not staged" % [name, source])
			continue
		var saved: PackedStringArray = ExtractLib.extract_character_body(
				"%s/%s" % [SOURCE, source], name, TEXTURE_SUFFIXES,
				spec.get("atlas", ""))
		print("DBG %-12s %d meshes" % [name, saved.size()])
		for path in saved:
			print("DBG     %s" % path)
	for source in SPARE_TEXTURES:
		if staged(source):
			copy_spare(source, SPARE_TEXTURES[source])
	if staged(RIFLE_SOURCE):
		extract_rifle()
	quit()


func staged(p_source: String) -> bool:
	return FileAccess.file_exists(
			ProjectSettings.globalize_path("%s/%s" % [SOURCE, p_source]))


# A spare skin: the texture beside the primary, plus a material pointing at it.
func copy_spare(p_source: String, p_spec: Dictionary):
	var name: String = p_spec.name
	var texture: String = "%s/%s/%s_texture_%s.png" % [
			TEXTURE_DIR, name, name, p_spec.suffix]
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(texture.get_base_dir()))
	if not FileAccess.file_exists(ProjectSettings.globalize_path(texture)):
		DirAccess.copy_absolute(
				ProjectSettings.globalize_path("%s/%s" % [SOURCE, p_source]),
				ProjectSettings.globalize_path(texture))
		print("DBG spare texture -> %s (needs an import pass)" % texture)
	var material_path: String = "%s/%s_material_%s.tres" % [
			MATERIAL_DIR, name, p_spec.suffix]
	# The primary is the template, so the spare inherits every tweak made to it.
	var primary: BaseMaterial3D = load("%s/%s_material_a.tres" % [MATERIAL_DIR, name])
	if primary == null or not ResourceLoader.exists(texture):
		print("DBG spare material deferred: re-run once %s has imported" % texture.get_file())
		return
	var material: BaseMaterial3D = primary.duplicate()
	material.albedo_texture = load(texture)
	material.resource_name = "%s_material_%s" % [name, p_spec.suffix]
	material.take_over_path(material_path)
	ExtractLib.save_keeping_uid(material, material_path)
	print("DBG spare material -> %s" % material_path)


func extract_rifle():
	var packed: PackedScene = load("%s/%s" % [SOURCE, RIFLE_SOURCE])
	if packed == null:
		push_error("Could not load %s/%s" % [SOURCE, RIFLE_SOURCE])
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WEAPON_DIR))
	var rig: Node = packed.instantiate()
	for instance: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		if not RIFLE_PIECES.has(String(instance.name)):
			continue
		var name: String = RIFLE_PIECES[String(instance.name)]
		var out: ArrayMesh = ArrayMesh.new()
		for surface in instance.mesh.get_surface_count():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
					instance.mesh.surface_get_arrays(surface))
			var material: Material = rifle_material(
					instance.mesh.surface_get_material(surface))
			if material != null:
				out.surface_set_material(out.get_surface_count() - 1, material)
		out.resource_name = name
		var path: String = "%s/%s.tres" % [WEAPON_DIR, name]
		out.take_over_path(path)
		ExtractLib.save_keeping_uid(out, path)
		print("DBG %-22s %d surfaces aabb %s -> %s" % [name,
				out.get_surface_count(), out.get_aabb().size, path])
	rig.free()


func rifle_material(p_source: Material) -> Material:
	if p_source == null:
		return null
	var path: String = "%s/%s" % [MATERIAL_DIR,
			RIFLE_MATERIALS.get(p_source.resource_name, "")]
	if not RIFLE_MATERIALS.has(p_source.resource_name) \
			or not ResourceLoader.exists(path):
		push_warning("Rifle surface '%s' has no marksman material yet - re-run after import"
				% p_source.resource_name)
		return p_source
	return load(path)
