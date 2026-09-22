class_name PlayerCarry
extends Node
# The two-handed carry: a fuel barrel is too big for any pack, so the hands
# take the whole thing. While one is carried the quick bar hides and every
# weapon, item and build claim is refused - the barrel IS the loadout until it
# is placed again, through the build ghost's own grammar over the same grid.

const POSE_CARRY: String = "running_holding_rifle"  # the arms fit a held drum
const VALID_TINT: Color = Color(0.3, 1.0, 0.4, 0.45)
const BLOCKED_TINT: Color = Color(1.0, 0.25, 0.2, 0.5)
const RING_COLOR: Color = Color(0.45, 0.85, 1.0)
const DROP_SEARCH: int = 4  # cells outward force_drop hunts for standing room
const PLACE_RANGE: float = 3.0  # m - a barrel goes down at arm's length
const POSE_EASE: float = 6.0  # per-second slew between held and walked pose speed
const POSE_MIN_SPEED: float = 0.5  # m/s - the footsteps' own standing threshold

@export var barrel_data: BuildableData
@export var carried: CharacterInventory
@export var animator: CharacterAnimator
@export var visual: Node3D  # the authored barrel in the arms, hidden until then

var carrying: bool = false
var fuel: float = 0.0
var ghost: Node3D
var ghost_tint: StandardMaterial3D
var ring: RangeRing
var chill_reach: float = 0.0
var cell: Vector2i
var placeable: bool = false
var pose_speed: float = 0.0

@onready var body: Character = get_parent()


func _ready():
	var character: Character = body as Character
	if character:
		character.died.connect(end_carry)
	# Sitting down into a car with a barrel in your arms leaves it at the door.
	Signals.drive_state_changed.connect(func(p_driving: bool):
		if p_driving:
			force_drop())


func _process(p_delta: float):
	if not carrying:
		return
	drive_pose(p_delta)
	track_cursor()
	if Input.is_action_just_pressed("attack") and not InputManager.pointer_over_prompt:
		place_down()


# The carry pose is a RUN cycle: standing still it must HOLD, not jog the
# arms in place. The upper layer's own time scale follows the feet, eased so
# the first step of a walk does not snap the swing.
func drive_pose(p_delta: float):
	if animator == null:
		return
	var walking: bool = Vector2(body.velocity.x, body.velocity.z).length() \
			> POSE_MIN_SPEED
	pose_speed = move_toward(pose_speed, 1.0 if walking else 0.0,
			POSE_EASE * p_delta)
	animator.set_upper_speed(pose_speed)


# The same claim PlayerThrow, PlayerConsume and PlayerBuild make.
func holds_attack() -> bool:
	return carrying


func pickup(p_barrel: FuelBarrel):
	if carrying or p_barrel == null or p_barrel.fading:
		return
	fuel = p_barrel.current_fuel
	if Globals.build_grid:
		Globals.build_grid.forget(p_barrel)
	# The world's barrel lingers only as its cooling: hidden, intangible,
	# chill fading - the slow warm-up the card asks for, run backwards.
	p_barrel.begin_fade()
	carried.bare_hands()
	carrying = true
	visual.show()
	if animator:
		animator.set_upper_animation(POSE_CARRY)
		animator.upper_weight = 1.0
		pose_speed = 0.0
		animator.set_upper_speed(0.0)  # picked up standing: the pose HOLDS
	Signals.carry_state_changed.emit(true)
	spawn_ghost()


# The build ghost's exact construction: meshes alone, offering nothing.
func spawn_ghost():
	ghost = BuildGrid.make_ghost(barrel_data.scene)
	ghost_tint = BuildGrid.tint_ghost(ghost)
	chill_reach = ghost_chill_reach()
	get_tree().current_scene.add_child(ghost)
	ring = RangeRing.new()
	get_tree().current_scene.add_child(ring)
	track_cursor()


func ghost_chill_reach() -> float:
	var area: Node = ghost.find_child("CoolArea", true, false)
	if area == null:
		return 0.0
	for child in area.get_children():
		var shape: CollisionShape3D = child as CollisionShape3D
		if shape and shape.shape is SphereShape3D:
			return shape.shape.radius
	return 0.0


func track_cursor():
	var grid: BuildGrid = Globals.build_grid
	if grid == null or not is_instance_valid(ghost):
		return
	cell = grid.cell_of(InputManager.get_world_mouse_pos())
	placeable = grid.can_place(barrel_data, cell, 0) and in_reach(cell)
	ghost.global_position = grid.world_of(cell, barrel_data.footprint)
	ghost_tint.albedo_color = VALID_TINT if placeable else BLOCKED_TINT
	if is_instance_valid(ring):
		ring.draw_circle(ghost.global_position,
				chill_reach if placeable else 0.0, RING_COLOR)


# Arm's length: the barrel is IN the hands, so it goes down where they can
# put it, not wherever the cursor wandered.
func in_reach(p_cell: Vector2i) -> bool:
	var centre: Vector3 = Globals.build_grid.world_of(p_cell, barrel_data.footprint)
	return Vector2(centre.x - body.global_position.x,
			centre.z - body.global_position.z).length() <= PLACE_RANGE


func place_down():
	if not placeable or Globals.build_grid == null:
		return
	if not in_reach(cell):
		return  # placeable is track_cursor's word; the reach re-checks here
	if put_barrel(cell) != null:
		end_carry()


# The grid's placement, then the carried state poured back in.
func put_barrel(p_cell: Vector2i) -> FuelBarrel:
	var node: FuelBarrel = Globals.build_grid.place(barrel_data, p_cell, 0)
	if node:
		node.current_fuel = fuel
		node.refresh_offers()
	return node


# The involuntary drop - entering a car, lying down to sleep. Hunts outward
# from underfoot for the first cell that takes a barrel; the player's own body
# blocks the centre, so the ring around it is where this usually lands.
func force_drop():
	if not carrying or Globals.build_grid == null:
		return
	var grid: BuildGrid = Globals.build_grid
	var centre: Vector2i = grid.cell_of(body.global_position)
	for radius in DROP_SEARCH:
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue  # the ring alone; inner rings already failed
				var at: Vector2i = centre + Vector2i(x, y)
				if grid.can_place(barrel_data, at, 0) and put_barrel(at) != null:
					end_carry()
					return
	push_warning("force_drop found no standing room; the barrel is lost")
	end_carry()


func end_carry():
	if not carrying:
		return
	carrying = false
	fuel = 0.0
	visual.hide()
	if animator:
		animator.upper_weight = 0.0
		# The layer's clock belongs to the weapons again - a reload's scaled
		# clip must not inherit the carry's freeze.
		animator.set_upper_speed(1.0)
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	if is_instance_valid(ring):
		ring.queue_free()
	ring = null
	Signals.carry_state_changed.emit(false)
