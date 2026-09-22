class_name ProbeBase
extends Node
# The shared spine every probe was re-declaring: the claim/measurement counters
# and the toggle-and-diff helper the shots each grew their own copy of.

var passed: int = 0
var failed: int = 0


# A probe run is unattended by definition, and the windowed ones play the whole
# game at whoever is sitting there - engines, gunfire, the lot. Muting the bus
# leaves every claim intact: AudioStreamPlayer.playing is what probes assert on,
# and a muted BUS does not stop a stream from playing.
func _init():
	silence()


# The handful of probe roots that structurally cannot extend ProbeBase (Node3D)
# call this themselves rather than growing a second copy of the line.
static func silence():
	AudioServer.set_bus_mute(0, true)  # bus 0 is always Master


# One claim, one measurement. The line format is the contract verify.sh greps.
func check(p_ok: bool, p_label: String, p_detail: String) -> bool:
	if p_ok:
		passed += 1
	else:
		failed += 1
	print("DBG %s %s: %s" % ["PASS" if p_ok else "FAIL", p_label, p_detail])
	return p_ok


# The tally verify.sh counts a run by. A probe that ends without one is read as
# crashed or hung, never as passing.
func finish() -> void:
	print("DBG %d passed, %d failed" % [passed, failed])
	get_tree().quit()


func settle(p_frames: int = 10) -> void:
	for i in p_frames:
		await get_tree().process_frame


# Singletons by TYPE - the level's own DebugMenu resolves its targets the same
# way. A literal path into the level is what a probe must never hold: the layout
# is the designer's to rearrange, and each time it moved it took a probe down
# with it. Authored one-offs go by NAME through find_child, groups by group.
func find_first(p_root: Node, p_class: String) -> Node:
	var found: Array[Node] = p_root.find_children("*", p_class, true, false)
	return found[0] if not found.is_empty() else null


func headless() -> bool:
	return DisplayServer.get_name() == "headless"


# --headless installs a dummy rasteriser: captures save blank and frame_post_draw
# never resolves, which hangs a capture step to its frame budget. Shots guard on
# this instead of producing a blank png nobody notices.
func windowed(p_what: String = "this capture") -> bool:
	if headless():
		print("DBG SKIP %s: headless renders blank" % p_what)
		return false
	return true


func capture() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


# Screenshots go to user://. Six shots used to carry an absolute path into a temp
# directory from the session that wrote them, which stopped existing long before
# anyone looked for the png.
func save_shot(p_image: Image, p_name: String) -> void:
	p_image.save_png("user://%s.png" % p_name)
	print("DBG saved %s" % p_name)


# What a still frame costs on its own. Capture, wait, capture again with nothing
# touched: every visual claim is then measured against THIS number instead of one
# picked by hand, so a run on another machine calibrates itself.
func idle_floor(p_frames: int = 6, p_step: int = 8, p_band: float = 1.0) -> float:
	var a: Image = await capture()
	await settle(p_frames)
	var b: Image = await capture()
	return frame_diff(a, b, p_step, p_band)


# The mean colour, in the second frame, of the pixels that changed between them -
# what a lineup shot needs to tell "the model rendered" apart from "the model
# rendered as Godot's white fallback material".
func changed_mean(p_a: Image, p_b: Image, p_step: int = 4, p_threshold: float = 0.02) -> Color:
	var total: Color = Color(0.0, 0.0, 0.0)
	var hits: int = 0
	for y in range(0, p_a.get_height(), p_step):
		for x in range(0, p_a.get_width(), p_step):
			var a: Color = p_a.get_pixel(x, y)
			var b: Color = p_b.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > p_threshold:
				total += b
				hits += 1
	if hits == 0:
		return Color(0.0, 0.0, 0.0)
	return Color(total.r / hits, total.g / hits, total.b / hits)


# Mean abs RGB delta between two frames, sampled on a lattice. This is how a
# shot proves motion or a tint that a still cannot show: capture with the effect
# on, toggle it off, capture again, and measure - never trust the eye on wisps.
# p_band is the share of frame height sampled from the centre (1.0 = all of it).
func frame_diff(p_a: Image, p_b: Image, p_step: int = 8, p_band: float = 1.0) -> float:
	var height: int = p_a.get_height()
	var margin: int = int(height * (1.0 - clampf(p_band, 0.0, 1.0)) * 0.5)
	var total: float = 0.0
	var samples: int = 0
	for y in range(margin, height - margin, p_step):
		for x in range(0, p_a.get_width(), p_step):
			var a: Color = p_a.get_pixel(x, y)
			var b: Color = p_b.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			samples += 1
	return total / maxf(samples, 1)
