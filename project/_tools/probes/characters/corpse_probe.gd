extends ProbeBase
# DBG probe: enemy loot - a killed body builds its pockets (the hands' own
# weapon instances, magazines riding, plus a small pinch of their calibre),
# advertises Search only once dead and only with something in them, and opens
# through the container bus like any box. Empty hands stay silent.


func _ready():
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	await settle(6)

	var enemy: Character = (load("res://scenes/characters/enemy.tscn") \
			as PackedScene).instantiate()
	add_child(enemy)
	enemy.global_position = Vector3(40.0, 0.0, 40.0)
	await settle(4)
	var loot: EnemyLoot = null
	for child in enemy.get_children():
		if child is EnemyLoot:
			loot = child
	if not check(loot != null, "the enemy carries the loot component", str(loot)):
		finish()
		return

	# --- alive advertises nothing
	check(not loot.offer.enabled, "a living body offers no search", "quiet")

	# --- death builds the pockets
	var armed: int = enemy.weapons.inventory.size()
	var first: WeaponData = enemy.weapons.inventory[0]
	first.current_ammo = 3  # a known magazine to follow into the pockets
	enemy.take_damage(AttackData.new(999, enemy.global_position, 0.0, null))
	check(enemy.is_dead, "the body is down", "dead")
	check(loot.offer.enabled and not loot.storage.entries.is_empty(),
			"and NOW the search advertises", "%d stacks" % loot.storage.entries.size())

	# --- the hands' own instances, not conjured copies
	var found: InventoryEntry = loot.storage.entry_of(first)
	check(found != null and found.item.current_ammo == 3,
			"the drawn weapon moves in whole, magazine riding",
			"%d rounds" % (found.item.current_ammo if found else -1))
	var weapons_in: int = 0
	for entry in loot.storage.entries:
		if entry.item is WeaponData:
			weapons_in += 1
	check(weapons_in == armed, "every carried weapon is in the pockets",
			"%d of %d" % [weapons_in, armed])

	# --- a very small pinch of the calibre
	var pinch: ItemData = load(EnemyLoot.AMMO_ITEMS[first.ammo_type])
	var rounds: int = loot.storage.count_of(pinch)
	check(rounds >= EnemyLoot.AMMO_PINCH.x * 1,
			"a pinch of its rounds came too", "%d rounds" % rounds)

	# --- searching opens the container bus, then reads hollow
	var opened: Array = []
	var listener: Callable = func(p_title, p_inventory):
		opened.append([p_title, p_inventory])
	Signals.container_opened.connect(listener)
	loot.open()
	Signals.container_opened.disconnect(listener)
	check(opened.size() == 1 and opened[0][1] == loot.storage,
			"searching opens the body's own pockets", str(opened.size()))
	check(str(opened[0][0]).length() > 0, "titled after the body",
			str(opened[0][0]))
	check(loot.offer.spent, "and the dot goes hollow once searched", "spent")

	# --- empty hands stay silent
	var bare: Character = (load("res://scenes/characters/enemy.tscn") \
			as PackedScene).instantiate()
	var stripped: CharacterData = (load("res://data/characters/mannequin.tres") \
			as CharacterData).duplicate()
	stripped.weapon_inventory = []
	bare.data = stripped
	add_child(bare)
	bare.global_position = Vector3(44.0, 0.0, 40.0)
	await settle(4)
	var bare_loot: EnemyLoot = null
	for child in bare.get_children():
		if child is EnemyLoot:
			bare_loot = child
	bare.take_damage(AttackData.new(999, bare.global_position, 0.0, null))
	check(bare_loot != null and not bare_loot.offer.enabled,
			"fists-only pockets never advertise",
			"%d stacks" % (bare_loot.storage.entries.size() if bare_loot
			and bare_loot.storage else -1))

	finish()
