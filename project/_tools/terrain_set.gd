extends SceneTree
# Conform terrain texture-set folders to the TerraBrush Texture2DArray slot
# contract and wire them up. Usage: verify.sh script res://_tools/terrain_set.gd -- <folder|check>

const ROOT:String = "res://assets/textures/terrains"
const SIZE:int = 1024
const ROUGHNESS_FILL:float = 0.87
const SOURCE_EXTENSIONS:Array[String] = ["png", "bmp", "jpg", "jpeg", "tga", "webp"]
const SLOT_HINTS:Dictionary = {
	"albedo": ["albedo", "color", "diff"],
	"normal": ["normal"],
	"roughness": ["roug"],
	"height": ["height", "heigh", "disp"],
}
const SLOT_FORMATS:Dictionary = {
	"albedo": Image.FORMAT_RGB8,
	"normal": Image.FORMAT_RGBA8,
	"roughness": Image.FORMAT_RGB8,
	"height": Image.FORMAT_L8,
}
const FORMAT_NAMES:Array[String] = ["L8", "LA8", "R8", "RG8", "RGB8", "RGBA8"]

var errors:int = 0
const IMPORT_TEMPLATE:String = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="%s"

[deps]

source_file="%s"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


func _init():
	var args:PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or args[0] == "check":
		check_all()
	else:
		fix_set(args[0])
	quit()


func fix_set(p_folder:String):
	var dir:String = ROOT + "/" + p_folder
	if not DirAccess.dir_exists_absolute(dir):
		print("DBG ERROR: no folder %s" % dir)
		return

	var slots:Dictionary = classify_sources(dir)
	for slot in ["albedo", "normal", "height"]:
		if not slots.has(slot):
			print("DBG ERROR: no %s texture found in %s - supply one first" % [slot, p_folder])
			return

	var changed:bool = false
	for slot in slots:
		if conform_texture(slots[slot], slot, dir + "/" + p_folder + "_" + slot + ".png"):
			changed = true
	if not slots.has("roughness"):
		var roughness:Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
		roughness.fill(Color(ROUGHNESS_FILL, ROUGHNESS_FILL, ROUGHNESS_FILL))
		roughness.save_png(dir + "/" + p_folder + "_roughness.png")
		print("DBG generated flat roughness (%0.2f) - repaint if the surface needs variation" % ROUGHNESS_FILL)
		changed = true

	for slot in SLOT_FORMATS:
		ensure_import_sidecar(dir + "/" + p_folder + "_" + slot + ".png")
	var tres:String = set_resource_path(p_folder, dir)
	write_set_resource(p_folder, dir, tres)
	add_to_palette(p_folder, tres)

	print("DBG done. Next: verify.sh import errors  (then reload the editor scene)")
	if errors > 0:
		print("DBG WARNING: %d texture(s) left unresolved above - fix and rerun" % errors)
	elif not changed:
		print("DBG (sources were already conformant)")


# Maps slot name -> source path for every recognizable image in the folder.
func classify_sources(p_dir:String) -> Dictionary:
	var slots:Dictionary = {}
	for file in DirAccess.get_files_at(p_dir):
		if not file.get_extension().to_lower() in SOURCE_EXTENSIONS:
			continue
		var matched:bool = false
		for slot in SLOT_HINTS:
			for hint in SLOT_HINTS[slot]:
				if hint in file.to_lower() and not matched:
					if slots.has(slot):
						print("DBG WARNING: both %s and %s look like %s - using the first" % [
								slots[slot].get_file(), file, slot])
					else:
						slots[slot] = p_dir + "/" + file
					matched = true
		if not matched:
			print("DBG WARNING: %s matches no slot (albedo/normal/roughness/height) - ignored" % file)
	return slots


# Converts one source to its slot contract at p_target. True if anything changed.
func conform_texture(p_source:String, p_slot:String, p_target:String) -> bool:
	var image:Image = Image.load_from_file(ProjectSettings.globalize_path(p_source))
	if image == null:
		print("DBG ERROR: could not load %s" % p_source)
		errors += 1
		return false
	var wanted:int = SLOT_FORMATS[p_slot]
	if p_source == p_target and image.get_format() == wanted and image.get_width() == SIZE \
			and image.get_height() == SIZE:
		return false

	if p_slot == "albedo" and image.get_format() == Image.FORMAT_RGBA8 and alpha_varies(image):
		print("DBG ERROR: %s alpha channel carries data - decide what it is before stripping" % p_source.get_file())
		errors += 1
		return false
	if image.get_format() != wanted:
		print("DBG %s: %s -> %s" % [p_target.get_file(), format_name(image.get_format()), format_name(wanted)])
		image.convert(wanted)
	if image.get_width() != SIZE or image.get_height() != SIZE:
		print("DBG %s: %dx%d -> %dx%d (eyeball for stretching - non-square sources are usually crops)" % [
				p_target.get_file(), image.get_width(), image.get_height(), SIZE, SIZE])
		image.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	image.save_png(ProjectSettings.globalize_path(p_target))

	if p_source != p_target:
		DirAccess.remove_absolute(p_source)
		DirAccess.remove_absolute(p_source + ".import")
		print("DBG replaced %s with %s" % [p_source.get_file(), p_target.get_file()])
	return true


func alpha_varies(p_image:Image) -> bool:
	for y in range(0, p_image.get_height(), 32):
		for x in range(0, p_image.get_width(), 32):
			if p_image.get_pixel(x, y).a < 0.99:
				return true
	return false


# Pre-writes the .import so the first import already has mipmaps + a known uid.
func ensure_import_sidecar(p_png:String):
	var sidecar:String = ProjectSettings.globalize_path(p_png) + ".import"
	if FileAccess.file_exists(sidecar):
		var text:String = FileAccess.get_file_as_string(sidecar)
		if "mipmaps/generate=false" in text:
			FileAccess.open(sidecar, FileAccess.WRITE).store_string(
					text.replace("mipmaps/generate=false", "mipmaps/generate=true"))
			print("DBG %s: mipmaps enabled" % p_png.get_file())
		return
	var uid:String = ResourceUID.id_to_text(ResourceUID.create_id())
	FileAccess.open(sidecar, FileAccess.WRITE).store_string(IMPORT_TEMPLATE % [uid, p_png])
	print("DBG %s: import sidecar written (%s)" % [p_png.get_file(), uid])


func sidecar_uid(p_png:String) -> String:
	var text:String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(p_png) + ".import")
	return text.get_slice("uid=\"", 1).get_slice("\"", 0)


# Reuses an existing .tres in the folder (legacy names like desert_ground_01.tres)
# so references never break; only a set with no resource yet gets the canonical name.
func set_resource_path(p_folder:String, p_dir:String) -> String:
	for file in DirAccess.get_files_at(p_dir):
		if file.get_extension() == "tres":
			return p_dir + "/" + file
	return p_dir + "/" + p_folder + ".tres"


func write_set_resource(p_folder:String, p_dir:String, p_tres:String):
	var uid:String
	if FileAccess.file_exists(ProjectSettings.globalize_path(p_tres)):
		var existing:String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(p_tres))
		uid = existing.get_slice("uid=\"", 1).get_slice("\"", 0)
	else:
		uid = ResourceUID.id_to_text(ResourceUID.create_id())
	var lines:Array[String] = [
		'[gd_resource type="TextureSetResource" format=3 uid="%s"]' % uid, ""]
	for slot in ["albedo", "height", "normal", "roughness"]:
		var png:String = p_dir + "/" + p_folder + "_" + slot + ".png"
		lines.append('[ext_resource type="Texture2D" uid="%s" path="%s" id="%s"]' % [
				sidecar_uid(png), png, slot])
	lines.append_array(["", "[resource]", 'name = "%s"' % p_folder.capitalize(),
			'albedoTexture = ExtResource("albedo")', 'normalTexture = ExtResource("normal")',
			'roughnessTexture = ExtResource("roughness")', 'heightTexture = ExtResource("height")', ""])
	FileAccess.open(ProjectSettings.globalize_path(p_tres), FileAccess.WRITE).store_string(
			"\n".join(lines))
	print("DBG %s written (name \"%s\")" % [p_tres.get_file(), p_folder.capitalize()])


func add_to_palette(p_folder:String, p_tres:String):
	var palette_path:String = ProjectSettings.globalize_path(ROOT + "/terrain_sets.tres")
	var text:String = FileAccess.get_file_as_string(palette_path)
	if p_tres in text:
		print("DBG palette already contains %s" % p_folder)
		return
	var set_uid:String = FileAccess.get_file_as_string(
			ProjectSettings.globalize_path(p_tres)).get_slice("uid=\"", 1).get_slice("\"", 0)
	var id:String = "set_" + p_folder
	var entry:String = '[ext_resource type="TextureSetResource" uid="%s" path="%s" id="%s"]\n' % [
			set_uid, p_tres, id]
	text = text.replace("\n[resource]", "\n%s\n[resource]" % entry)
	if "([])" in text:
		text = text.replace("([])", '([ExtResource("%s")])' % id)
	else:
		text = text.replace(")])", '), ExtResource("%s")])' % id)
	FileAccess.open(palette_path, FileAccess.WRITE).store_string(text)
	print("DBG added %s to terrain_sets.tres palette" % p_folder)


func check_all():
	var palette:String = FileAccess.get_file_as_string(
			ProjectSettings.globalize_path(ROOT + "/terrain_sets.tres"))
	for folder in DirAccess.get_directories_at(ROOT):
		var in_palette:String = "in palette" if "/" + folder + "/" in palette else "NOT in palette"
		print("DBG === %s (%s)" % [folder, in_palette])
		var slots:Dictionary = classify_sources(ROOT + "/" + folder)
		for slot in SLOT_FORMATS:
			if not slots.has(slot):
				print("DBG   %s: MISSING" % slot)
				continue
			var image:Image = Image.load_from_file(ProjectSettings.globalize_path(slots[slot]))
			var ok:bool = image.get_format() == SLOT_FORMATS[slot] \
					and image.get_width() == SIZE and image.get_height() == SIZE
			var sidecar:String = ProjectSettings.globalize_path(slots[slot]) + ".import"
			var mips:bool = FileAccess.file_exists(sidecar) and \
					"mipmaps/generate=true" in FileAccess.get_file_as_string(sidecar)
			print("DBG   %s: %s %dx%d mips=%s %s" % [slot, format_name(image.get_format()),
					image.get_width(), image.get_height(), mips,
					"OK" if ok and mips else "<-- fix_set needed"])


func format_name(p_format:int) -> String:
	return FORMAT_NAMES[p_format] if p_format < FORMAT_NAMES.size() else str(p_format)
