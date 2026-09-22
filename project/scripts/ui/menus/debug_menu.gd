class_name DebugMenu
extends Control

enum Row {TIME_OF_DAY, TIME_SCALE, DEBUG_DRAW, STATE_LABELS, PERF_STATS,
	FREE_CAMERA}

const TIME_SCALES: Array[float] = [0.1, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
const CAMERA_PAN_SPEED: float = 22.0  # m/s across the ground
# Ortho size is the only real closer/further - raising the camera just slides the picture.
const CAMERA_ZOOM_SPEED: float = 18.0  # ortho size per second
const CAMERA_ZOOM_MIN: float = 5.0
const CAMERA_ZOOM_MAX: float = 90.0
const CAMERA_FAST: float = 3.0  # sprint multiplier
const AMMO_PATHS: Array[String] = ["res://data/items/ammo/ammo_light.tres",
		"res://data/items/ammo/ammo_medium.tres",
		"res://data/items/ammo/ammo_heavy.tres"]

@export var row_scene: PackedScene

@onready var row_container: VBoxContainer = %RowContainer
@onready var button_container: VBoxContainer = %ButtonContainer

var rows: Dictionary = {}  # Row -> SettingsRowList
var free_camera: bool = false


func _ready():
	hide()
	build_rows()
	build_actions()


# Keeps the tree paused after closing, so CameraFollow cannot drag the view back.
func _process(p_delta: float):
	if not free_camera or visible:
		return  # panel open: the mouse and keys belong to the menu
	var rig: Node3D = Globals.camera_follow
	var camera: Camera3D = get_viewport().get_camera_3d()
	if rig == null or camera == null:
		return
	# Pan along what the camera is actually looking at, flattened to the
	# ground, so the keys match the screen rather than world axes.
	var forward: Vector3 = -camera.global_basis.z
	var right: Vector3 = camera.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	var pan: Vector3 = forward.normalized() * Input.get_axis("move_down", "move_up") \
			+ right.normalized() * Input.get_axis("move_left", "move_right")
	var speed: float = CAMERA_PAN_SPEED \
			* (CAMERA_FAST if Input.is_action_pressed("sprint") else 1.0)
	rig.global_position += pan * speed * p_delta
	camera.size = clampf(camera.size + Input.get_axis("next_item", "prev_item")
			* CAMERA_ZOOM_SPEED * p_delta, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)


func _unhandled_input(p_event: InputEvent):
	if not OS.is_debug_build():
		return
	if p_event is InputEventKey and p_event.pressed and not p_event.echo \
			and p_event.keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()
	elif visible and p_event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()  # free camera keeps its pause; the row hands the game back


# One arm per knob: title, the real values its arrows cycle, their labels, and
# the value it currently holds.
func row_data(p_row: Row) -> Dictionary:
	match p_row:
		Row.TIME_OF_DAY:
			var hours: Array = range(24)
			return {"title": "Time of day", "values": hours,
					"labels": hours.map(func(h): return "%02d:00" % h),
					"live": Calendar.time_data.hour}
		Row.TIME_SCALE:
			# str() trims the trailing zeros; GDScript's % has no %g.
			return {"title": "Time scale", "values": TIME_SCALES,
					"labels": TIME_SCALES.map(func(s): return "%sx" % str(s)),
					"live": Engine.time_scale}
		Row.DEBUG_DRAW:
			return {"title": "Debug draw", "values": [false, true],
					"labels": ["Off", "On"], "live": Globals.debug_mode}
		Row.STATE_LABELS:
			return {"title": "State labels", "values": [false, true],
					"labels": ["Off", "On"], "live": Globals.debug_labels}
		Row.PERF_STATS:
			return {"title": "Perf stats", "values": [false, true],
					"labels": ["Off", "On"], "live": Globals.debug_stats}
		Row.FREE_CAMERA:
			return {"title": "Free camera",
					"values": [false, true],
					"labels": ["Off", "On"], "live": free_camera}
	return {}


func apply_row(p_row: Row, p_value):
	match p_row:
		Row.TIME_OF_DAY:
			Calendar.set_time(p_value, 0)
		Row.TIME_SCALE:
			Engine.time_scale = p_value
		Row.DEBUG_DRAW:
			Globals.debug_mode = p_value
		Row.STATE_LABELS:
			Globals.debug_labels = p_value
		Row.PERF_STATS:
			Globals.debug_stats = p_value
		Row.FREE_CAMERA:
			free_camera = p_value


# Label -> what it does. Anything needing the player or a vehicle no-ops when
# there isn't one, so the menu is safe in the gym too.
func actions() -> Array:
	return [
		["Give ammo (one stack each)", give_ammo],
		["Heal player", heal_player],
		["Damage player 25%", damage_player],
		["Give $500", func(): PlayerData.add_money(500)],
		["Truck delivers 200L", func(): deliver_fuel(200.0)],
		["Send the delivery truck in", send_delivery],
		["Send a customer car in", spawn_customer],
		["Restart game", restart_game],
	]


func build_rows():
	for row in Row.values():
		var list: SettingsRowList = row_scene.instantiate()
		row_container.add_child(list)
		list.value_changed.connect(on_row_changed.bind(row))
		rows[row] = list


func build_actions():
	for entry in actions():
		var button: Button = Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		button_container.add_child(button)


func open():
	refresh()
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close():
	hide()
	# Free camera holds the world still after the panel goes away - that IS the
	# mode. Switch the row back to Off to hand the game back.
	get_tree().paused = free_camera
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func refresh():
	for row in rows:
		var data: Dictionary = row_data(row)
		rows[row].setup(data.title, data.labels, data.values.find(data.live))


func on_row_changed(p_index: int, p_row: Row):
	apply_row(p_row, row_data(p_row).values[p_index])


# --- actions ---

func give_ammo():
	var pack: CharacterInventory = find_pack()
	if pack == null:
		return
	for path in AMMO_PATHS:
		var ammo: AmmoData = load(path)
		pack.inventory.add(ammo, ammo.get_max_stack())


func heal_player():
	if InputManager.player == null or InputManager.player.data == null:
		return
	InputManager.player.current_health = InputManager.player.data.max_health
	Signals.health_updated.emit(InputManager.player.current_health,
			InputManager.player.data.max_health)


# Through the hurt box, not take_damage: that is where the damage label, the
# flash and the blood live, so a debug hit looks like a real one.
func damage_player():
	var player: Character = InputManager.player
	if player == null or player.data == null:
		return
	var attack: AttackData = AttackData.new(
			maxi(1, roundi(player.data.max_health * 0.25)),
			player.global_position, 0.0, null)
	if player.hurt_box:
		player.hurt_box.hit(attack)
	else:
		player.take_damage(attack)


func deliver_fuel(p_liters: float):
	var pump: GasPump = find_first("GasPump") as GasPump
	if pump:
		print("Delivery: %dL cost $%d" % [p_liters, pump.buy_stock(p_liters)])


# Skips the arrival timer. Closing the menu unpauses, so the car pulls in as
# soon as the panel is gone.
func spawn_customer():
	var spawner: TrafficSpawner = find_first("TrafficSpawner") as TrafficSpawner
	if spawner and spawner.spawn() == null:
		print("No customer sent: the forecourt is closed, dry or full")


# Winds the clock to opening time rather than spawning behind the schedule's
# back - set_time never rewinds, so a later hour rolls to tomorrow morning.
func send_delivery():
	var service: DeliveryService = find_first("DeliveryService") as DeliveryService
	if service == null:
		return
	Calendar.set_time(service.arrive_hour, 0)
	print("Delivery truck: %s" % ("on its way" if service.truck else "no road to drive"))


# The one thing in the world of that class_name, or null in the gym where
# there isn't one. Every action above no-ops rather than erroring.
func find_first(p_class: String) -> Node:
	var found: Array = root().find_children("*", p_class, true, false)
	return found[0] if not found.is_empty() else null


func root() -> Node:
	return owner if owner else get_tree().current_scene


# The purse is a STATIC, so it outlives the scene - a reload alone would hand
# back the same money and this would not be a restart at all.
func restart_game():
	close()  # unpause and re-hide the cursor before the tree is rebuilt
	PlayerData.current_money = 0
	get_tree().reload_current_scene.call_deferred()


func find_pack() -> CharacterInventory:
	if InputManager.player == null:
		return null
	for child in InputManager.player.get_children():
		if child is CharacterInventory:
			return child
	return null
