class_name PlayerBuild
extends Node

const VALID_TINT: Color = Color(0.3, 1.0, 0.4, 0.45)
const BLOCKED_TINT: Color = Color(1.0, 0.25, 0.2, 0.5)

var active: BuildableData
var yaw: int = 0
var ghost: Node3D
var ghost_tint: StandardMaterial3D
var cell: Vector2i
var placeable: bool = false
var carry: PlayerCarry

@onready var body: Character = get_parent()


func _ready():
	for child in get_parent().get_children():
		if child is PlayerCarry:
			carry = child


func _process(_delta):
	if carry and carry.carrying:
		return
	if Input.is_action_just_pressed("toggle_build"):
		if active != null:
			stop()
		else:
			open_catalogue()
		return
	if active == null:
		return
	if Input.is_action_just_pressed("build_rotate"):
		yaw = (yaw + 90) % 360
	track_cursor()
	if Input.is_action_just_pressed("attack") and not InputManager.pointer_over_prompt:
		confirm()


func holds_attack() -> bool:
	return active != null


func open_catalogue():
	var grid: BuildGrid = Globals.build_grid
	if grid == null or grid.catalogue.is_empty():
		return
	var options: Array = []
	for entry in grid.catalogue:
		options.append({"label": "%s ($%d)" % [entry.name, entry.price],
				"target": self, "callback": "start", "argument": entry})
	Signals.interaction_menu_requested.emit("Build", options)


func start(p_data: BuildableData):
	if p_data == null or p_data.scene == null:
		return
	stop()
	active = p_data
	yaw = 0
	ghost = BuildGrid.make_ghost(p_data.scene)
	ghost_tint = BuildGrid.tint_ghost(ghost)
	get_tree().current_scene.add_child(ghost)
	track_cursor()


func stop():
	active = null
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null


func track_cursor():
	var grid: BuildGrid = Globals.build_grid
	if grid == null or not is_instance_valid(ghost):
		return
	cell = grid.cell_of(InputManager.get_world_mouse_pos())
	placeable = grid.can_place(active, cell, yaw) \
			and PlayerData.current_money >= active.price
	ghost.global_position = grid.world_of(cell, grid.rotated_size(active, yaw))
	ghost.rotation.y = deg_to_rad(yaw)
	ghost_tint.albedo_color = VALID_TINT if placeable else BLOCKED_TINT


func confirm():
	if not placeable or not PlayerData.spend_money(active.price):
		return
	Globals.build_grid.place(active, cell, yaw)
	track_cursor()
