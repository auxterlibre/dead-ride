extends Control

const ANCHOR_HEIGHT: float = 0.8  # m above the interaction point the dot floats
const SHARED_POINT: float = 0.25  # m - offers closer than this share one dot

@export var dot_scene: PackedScene

var dots: Dictionary = {}  # source InteractiveArea -> dot Control
var leaving: Array[InteractionHintDot] = []  # animating out, offer already gone


func _ready():
	Signals.interaction_hint_added.connect(add_hint)
	Signals.interaction_hint_removed.connect(remove_hint)


func _process(_delta: float):
	var camera: Camera3D = get_viewport().get_camera_3d()
	# The layer outstays the last offer by one exit animation: hiding on an
	# empty `dots` would cut the exit of the dot that just emptied it.
	visible = not get_tree().paused and camera != null \
			and not (dots.is_empty() and leaving.is_empty())
	if not visible:
		return
	for point in group_by_point().values():
		draw_point(camera, point)


# Offers sharing a spot would stack into one heavier dot; a point draws once.
func group_by_point() -> Dictionary:
	var points: Dictionary = {}
	for source in dots.keys():
		if not is_instance_valid(source):
			remove_hint(source)
			continue
		var key: Vector3i = Vector3i((source.global_position / SHARED_POINT).round())
		if points.has(key):
			points[key].append(source)
		else:
			points[key] = [source]
	return points


# In reach if ANY offer here is, hollow only once ALL are taken.
func draw_point(p_camera: Camera3D, p_sources: Array):
	var active: bool = false
	var taken: bool = true
	for source in p_sources:
		active = active or source.stage == InteractiveArea.Stage.PROMPT
		taken = taken and source.spent
	var anchor: Vector3 = p_sources[0].global_position + Vector3.UP * ANCHOR_HEIGHT
	var dot: InteractionHintDot = dots[p_sources[0]]
	dot.visible = not p_camera.is_position_behind(anchor)
	dot.position = p_camera.unproject_position(anchor) - dot.size / 2.0
	dot.show_state(active, taken)
	for i in range(1, p_sources.size()):
		dots[p_sources[i]].visible = false


func add_hint(p_source):
	if dots.has(p_source) or dot_scene == null:
		return
	var dot: InteractionHintDot = dot_scene.instantiate()
	add_child(dot)
	dots[p_source] = dot


# Handed over rather than freed - the dot frees ITSELF once it has finished
# leaving. It stops being positioned at that point (the offer it was glued to
# is gone), which a twelfth of a second of travel never shows.
func remove_hint(p_source):
	var dot: InteractionHintDot = dots.get(p_source)
	if dot == null:
		return
	dots.erase(p_source)
	leaving.append(dot)
	# tree_exiting, not tree_exited: the reference is still live to erase with.
	dot.tree_exiting.connect(func(): leaving.erase(dot))
	dot.vanish()
