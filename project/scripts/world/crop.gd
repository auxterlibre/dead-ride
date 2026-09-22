class_name Crop
extends Node3D

signal changed  # watered / grown / ripened / died; visuals hook here

var data: CropData
var days_until_fruit: int = 0
var fruit_ready: bool = false
var pending_produce: int = 0  # rolled at ripening; what harvest hands over
var watered_today: bool = false
var dry_days: int = 0
var dead: bool = false
var last_absolute_day: int = -1

@onready var sprout: MeshInstance3D = get_node_or_null("Sprout")
@onready var dead_sprout: MeshInstance3D = get_node_or_null("DeadSprout")
@onready var fruit: Node3D = get_node_or_null("Fruit")


func _ready():
	Signals.calendar_updated.connect(on_calendar_updated)
	last_absolute_day = absolute_day(Calendar.time_data)
	changed.connect(update_visual)
	update_visual()


func setup(p_data: CropData):
	data = p_data
	days_until_fruit = p_data.grow_days
	update_visual()


func update_visual():
	if sprout == null:
		return
	var span: float = maxf(1.0, float(data.grow_days) if data else 1.0)
	var progress: float = 1.0 - float(days_until_fruit) / span
	sprout.scale = Vector3.ONE * lerpf(0.35, 1.0, clampf(progress, 0.0, 1.0))
	sprout.visible = not dead
	if dead_sprout:
		dead_sprout.visible = dead
	if fruit:
		fruit.visible = fruit_ready and not dead


# Sleep can jump several midnights at once; each one is its own day's verdict,
# and the watering only ever covers the first.
func on_calendar_updated(p_time: TimeData):
	var today: int = absolute_day(p_time)
	while last_absolute_day < today:
		last_absolute_day += 1
		end_of_day()


func end_of_day():
	if dead:
		return
	if watered_today:
		dry_days = 0
		grow_one_day()
	else:
		dry_days += 1
		if dry_days >= 2:
			die()
	watered_today = false
	changed.emit()


func grow_one_day():
	if fruit_ready:
		return  # holding ripe fruit; picking it restarts the clock
	days_until_fruit = maxi(days_until_fruit - 1, 0)
	if days_until_fruit == 0:
		fruit_ready = true
		pending_produce = data.roll_produce()


# The GDD waters these with FUEL; whatever that costs happens at the caller.
func water():
	if dead:
		return
	watered_today = true
	changed.emit()


# Hands the fruit to an inventory; whatever doesn't fit stays ON the plant,
# so a full pack never destroys a harvest. Only a cleared plant regrows.
func harvest(p_inventory: Inventory) -> int:
	if dead or not fruit_ready or data.produce == null:
		return 0
	var leftover: int = p_inventory.add(data.produce, pending_produce)
	var taken: int = pending_produce - leftover
	pending_produce = leftover
	if pending_produce == 0:
		fruit_ready = false
		days_until_fruit = data.regrow_days
	changed.emit()
	return taken


func die():
	dead = true
	changed.emit()


func absolute_day(p_time: TimeData) -> int:
	return (p_time.year * TimeData.MONTHS_PER_YEAR + p_time.month - 1) \
			* TimeData.DAYS_PER_MONTH + p_time.day - 1
