extends Node3D
# DBG probe: a weaponless enemy arms its FISTS and actually punches - no more
# chasing into melee range and hovering there, staring at the player.

const FISTS_INTERVAL: float = 1.0  # fire_rate knob 0 = 1 swing/sec

var passed: int = 0
var failed: int = 0
var hits: Array = []  # [damage, clock] per landed blow
var clock: float = 0.0


func _ready():
	ProbeBase.silence()  # Node3D, so it cannot inherit the mute
	build_floor()
	var player: Character = (load("res://scenes/characters/player.tscn")
			as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3.ZERO

	var stripped: CharacterData = (load("res://data/enemies/survivalist.tres")
			as CharacterData).duplicate()
	stripped.weapon_inventory = [] as Array[WeaponData]
	var enemy: Character = (load("res://scenes/characters/enemy.tscn")
			as PackedScene).instantiate()
	enemy.data = stripped
	add_child(enemy)
	enemy.global_position = Vector3(0.0, 0.0, 2.4)
	# The loadout lands deferred (apply_data waits a frame before arming).
	for i in 10:
		await get_tree().process_frame
		if enemy.weapons.current_weapon != null:
			break

	var weapon: WeaponData = enemy.weapons.current_weapon
	check(weapon != null and weapon.type == Enums.WeaponType.MELEE_UNARMED,
			"an empty loadout arms its fists",
			"holding: %s" % (weapon.name if weapon else "nothing"))

	var start_health: int = player.current_health
	player.damaged.connect(func(p_attack): hits.append([p_attack.damage, clock]))
	for i in 600:  # up to 10s of physics for acquire -> chase -> punches
		await get_tree().physics_frame
		clock += 1.0 / 60.0
		if hits.size() >= 3:
			break

	check(hits.size() >= 1, "the punch actually lands",
			"%d blows in %.1fs" % [hits.size(), clock])
	if hits.size() >= 1:
		check(hits[0][0] == enemy.weapons.current_weapon.damage_value,
				"dealing the fists' own damage", "%d hp a blow" % hits[0][0])
		check(player.current_health == maxi(start_health - hits.size() * hits[0][0], 0),
				"and the player felt every one (floored at dead)",
				"%d -> %d hp" % [start_health, player.current_health])
	check(hits.size() >= 2, "it keeps swinging on a cadence", "%d blows" % hits.size())
	if hits.size() >= 2:
		var gap: float = hits[1][1] - hits[0][1]
		check(gap >= FISTS_INTERVAL * 0.85,
				"spaced by the swing cooldown, not every frame", "%.2fs apart" % gap)

	print("DBG %d passed, %d failed" % [passed, failed])
	get_tree().quit()


func build_floor():
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 20  # walls|ground, what characters stand on
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)


func check(p_ok: bool, p_label: String, p_detail: String):
	if p_ok:
		passed += 1
	else:
		failed += 1
	print("DBG %s %s: %s" % ["PASS" if p_ok else "FAIL", p_label, p_detail])
