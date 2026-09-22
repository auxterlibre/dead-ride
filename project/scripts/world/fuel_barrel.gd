class_name FuelBarrel
extends StaticBody3D

const DRIP_INTERVAL: Vector2 = Vector2(2.0, 4.0)  # sec between stains while it holds fuel
const DRIP_RING: Vector2 = Vector2(0.35, 0.7)  # m off the rim a stain lands
const DRY_WARNING: float = 6.0  # liters left when the ground tint starts fading
const WARM_RATE: float = 0.2  # chill share per second a standing barrel gains
# Sheds slower than GrassField.growth_rate (0.25) chases, so the tufts track
# the falling target all the way down and the free lands on zero, not a pop.
const FADE_RATE: float = 0.2

@export var capacity: float = 60.0  # liters
@export var drain_per_hour: float = 2.0  # liters per scorch game-hour
@export var fill_rate: float = 4.0  # L/s poured from a carried can

var current_fuel: float
var drip_timer: float = 0.0
# The ground cools SLOWLY under a fresh barrel and dries slowly behind a taken
# one: warmth scales chill_strength, so the sand tint and the grass both ride
# it for free. Probes that need a settled pocket set it to 1.0 directly.
var warmth: float = 0.0
var fading: bool = false  # picked up: the barrel is gone, its cold lingers
var last_use_frame: int = -10  # use_point's hold-streak latch

@onready var cool_shape: CollisionShape3D = $CoolArea/CollisionShape3D
@onready var refill_area: InteractiveArea = $RefillArea


func _ready():
	# A child of the BuildGrid - authored or placed - is saved by the grid's
	# ledger; joining `persistent` too would spawn twins on load.
	if not get_parent() is BuildGrid:
		add_to_group("persistent")
	add_to_group("steer_around")
	add_to_group("chill_source")
	current_fuel = capacity
	refill_area.noticed.connect(refresh_offers)
	# The hand picks the point's job, so a drawn can re-aims it mid-stand.
	Signals.quick_slots_updated.connect(func(_p_entries, _p_active): refresh_offers())
	refresh_offers()


func _process(p_delta: float):
	if fading:
		fade_step(p_delta)
		return
	warm_step(p_delta)
	if venting():
		advance(p_delta)
	leak(p_delta)


# Split from _process for probe-stepping, like advance() and leak().
func warm_step(p_delta: float):
	warmth = minf(warmth + WARM_RATE * p_delta, 1.0)


func fade_step(p_delta: float):
	warmth = maxf(warmth - FADE_RATE * p_delta, 0.0)
	if warmth <= 0.0:
		queue_free()


# Picked up: the node stays only as its ground-cold, fading out. Everything
# else about it stops NOW - the body intangible, the offer retracted, the seal
# dry - because the barrel itself is in someone's arms.
func begin_fade():
	if fading:
		return
	fading = true
	$Mesh.hide()
	collision_layer = 0
	remove_from_group("steer_around")
	remove_from_group("persistent")
	refill_area.enabled = false
	# The hull is gone this frame; the grass may take the ground back.
	Signals.structure_changed.emit(global_position)


# Split from _process so probes can step it without waiting real seconds.
func advance(p_delta: float):
	current_fuel = maxf(current_fuel
			- drain_per_hour / Calendar.HOUR_DURATION * p_delta, 0.0)
	if current_fuel <= 0.0:
		refresh_offers()


# The drip is the SEAL, not the vent: a fueled barrel weeps black stains round
# the clock, heat or no heat - the vent only decides the cooling and the drain.
# Split from _process for the same probe-stepping reason as advance().
func leak(p_delta: float):
	if current_fuel <= 0.0:
		return
	drip_timer -= p_delta
	if drip_timer <= 0.0:
		drip_timer = randf_range(DRIP_INTERVAL.x, DRIP_INTERVAL.y)
		drip()


# The pocket only holds while there is cold fuel to vent and heat to fight -
# and never while the barrel is being carried: no coolant effect on the move.
func venting() -> bool:
	return not fading and current_fuel > 0.0 and is_instance_valid(Globals.heat) \
			and Globals.heat.is_scorching()


func drip():
	var angle: float = randf() * TAU
	var reach: float = randf_range(DRIP_RING.x, DRIP_RING.y)
	BloodPool.drop(get_tree().current_scene, global_position
			+ Vector3(cos(angle) * reach, 0.0, sin(angle) * reach), "fuel")


# ONE point, two jobs, the crop spot's rule: the HAND picks. A fuelled can in
# the active slot means the player came to pour; anything else and the press
# hoists the barrel itself. The frame-gap latch is what keeps a held pour that
# drains its can mid-stream from rolling over into a pickup on the very next
# held frame: hold calls land on CONSECUTIVE frames, so only a fresh press -
# or the prompt clicked, which injects no input at all - reads as intent.
func use_point(p_player = null):
	if fading:
		return
	var streak: bool = Engine.get_process_frames() - last_use_frame <= 1
	last_use_frame = Engine.get_process_frames()
	if held_can() and current_fuel < capacity:
		refill(p_player)
	elif not streak:
		var player: Node = p_player if p_player else InputManager.player
		if player == null:
			return
		for child in player.get_children():
			if child is PlayerCarry:
				child.pickup(self)
				return


# HELD offer, the pump nozzle pattern: pours every frame the key is down -
# from the can in hand first, else the first carried can with fuel, so probes
# and any future plumbing can still pour without posing the hand.
func refill(_p_player = null):
	var can: FuelCanData = held_can()
	if can == null:
		can = fuel_can()
	if can == null:
		return
	var liters: float = minf(fill_rate * get_process_delta_time(),
			minf(capacity - current_fuel, can.current_fuel))
	if liters <= 0.0:
		return
	can.drain(liters)
	current_fuel += liters
	refresh_offers()


func chill_radius() -> float:
	return cool_shape.shape.radius


# The ground tint dries out with the last liters - a warning the pocket is
# dying - scaled by warmth, which is what makes the cold ARRIVE and LEAVE
# slowly instead of popping with the barrel.
func chill_strength() -> float:
	return clampf(current_fuel / DRY_WARNING, 0.0, 1.0) * warmth


func fuel_can() -> FuelCanData:
	if not is_instance_valid(InputManager.player) \
			or InputManager.player.carried == null:
		return null
	for entry in InputManager.player.carried.inventory.entries:
		var can: FuelCanData = entry.item as FuelCanData
		if can and can.current_fuel > 0.0:
			return can
	return null


# The can IN HAND, the crop spot's watering rule - not merely packed.
func held_can() -> FuelCanData:
	if not is_instance_valid(InputManager.player) \
			or InputManager.player.carried == null:
		return null
	var can: FuelCanData = InputManager.player.carried.held_item() as FuelCanData
	return can if can and can.current_fuel > 0.0 else null


func refresh_offers():
	if fading:
		refill_area.enabled = false
		return
	if held_can() and current_fuel < capacity:
		refill_area.action_label = "Refill Barrel (%d/%dL)" \
				% [roundi(current_fuel), roundi(capacity)]
	else:
		refill_area.action_label = "Pick up"
	refill_area.enabled = true
	refill_area.refresh()


func save_state() -> Dictionary:
	return {"fuel": current_fuel}


func load_state(p_state: Dictionary):
	current_fuel = float(p_state.fuel)
	refresh_offers()
