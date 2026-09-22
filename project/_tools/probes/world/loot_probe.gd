extends ProbeBase
# DBG probe: scavenging - crates stock themselves on the first search, keep
# what they rolled, and what comes out is worth money to the delivery truck.

const SAMPLES: int = 400  # table rolls, enough for the rarest entry to show

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn
@onready var TABLE: LootTableData = load("res://data/world/desert_scavenge.tres")


func _ready():
	var game: Node = GAME.instantiate()
	add_child(game)
	for i in 4:
		await get_tree().process_frame

	var crates: Array = get_tree().get_nodes_in_group("loot_container")
	check(crates.size() >= 2, "the map carries crates to search",
			"%d found" % crates.size())
	if crates.is_empty():
		finish()
		return

	var crate: LootContainer = crates[0]
	check(crate.storage.entries.is_empty(), "an unsearched crate is empty",
			"%d entries" % crate.storage.entries.size())
	crate.open()
	var found: Array = crate.storage.entries.map(
			func(e): return "%s x%d" % [e.item.name, e.count])
	check(not crate.storage.entries.is_empty(), "searching it stocks it", str(found))

	# Re-opening must not re-roll, or a crate is an infinite supply.
	var before: int = crate.storage.entries.size()
	crate.open()
	check(crate.storage.entries.size() == before, "searching again rolls nothing new",
			"%d entries still" % crate.storage.entries.size())

	# Two crates roll independently rather than sharing one result.
	var other: LootContainer = crates[1]
	other.open()
	print("DBG second crate: %s" % str(other.storage.entries.map(
			func(e): return "%s x%d" % [e.item.name, e.count])))

	check_boxes(crates)
	check_table()
	check_sale(game, crate)
	finish()


# The two box flavors: cardboard stocks only its own table's junk, army
# crates duplicate rolled weapons so no two ever share a magazine.
func check_boxes(p_crates: Array):
	var cardboard: int = 0
	var army: int = 0
	for crate in p_crates:
		if crate.title == "Cardboard Box":
			cardboard += 1
		elif crate.title == "Army Crate":
			army += 1
	check(cardboard == 3 and army == 3,
			"three boxes of each flavor stand in the desert",
			"%d cardboard, %d army" % [cardboard, army])

	var small: StorageData = load("res://data/storage/box_small_layout.tres")
	var medium: StorageData = load("res://data/storage/box_medium_layout.tres")
	var large_mask: StorageData = load("res://data/storage/box_large_layout.tres")
	check(small.size == Vector2i(3, 3) and medium.size == Vector2i(4, 4) \
			and large_mask.size == Vector2i(6, 5),
			"masks parse to 3x3 / 4x4 / 6x5",
			"%s %s %s" % [small.size, medium.size, large_mask.size])

	# Cardboard never rolls guns or ammo - sample a stack of fresh smalls.
	var box_scene: PackedScene = load("res://scenes/props/loot_boxes/cardboard_box_small.tscn")
	var wrong: Array = []
	for i in 12:
		var box: LootContainer = box_scene.instantiate()
		add_child(box)
		box.fill()
		for entry in box.storage.entries:
			if not (entry.item is TrinketData or entry.item is ConsumableData):
				wrong.append(entry.item.name)
		box.queue_free()
	check(wrong.is_empty(), "cardboard boxes hold only junk, parts and bandages",
			str(wrong))

	# A crate somebody has been through advertises hollow.
	var fresh: LootContainer = box_scene.instantiate()
	add_child(fresh)
	var offer: InteractiveArea = find_first(fresh, "InteractiveArea")
	check(not offer.spent, "an unsearched crate advertises solid", "not spent")
	fresh.open()
	check(offer.spent, "searching one turns its own dot hollow", "spent")

	# The searched bit rides the save row, the hollow look a node: a load re-marks.
	var reopened: LootContainer = box_scene.instantiate()
	add_child(reopened)
	reopened.load_state(fresh.save_state())
	check(find_first(reopened, "InteractiveArea").spent,
			"and a load remembers it, hollow and all", "spent")
	reopened.queue_free()
	fresh.queue_free()

	# Army crates: every looted weapon is its OWN instance, magazine unloaded.
	var crate_scene: PackedScene = load("res://scenes/props/loot_boxes/army_crate_small.tscn")
	var guns: Array = []
	var shared: int = 0
	var preloaded: int = 0
	for i in 40:
		var crate: LootContainer = crate_scene.instantiate()
		add_child(crate)
		crate.fill()
		for entry in crate.storage.entries:
			if entry.item is WeaponData:
				if guns.has(entry.item):
					shared += 1
				if entry.item.current_ammo != -1:
					preloaded += 1
				guns.append(entry.item)
		crate.queue_free()
	check(guns.size() >= 2, "army crates cough up weapons now and then",
			"%d guns in 40 crates" % guns.size())
	check(shared == 0 and preloaded == 0,
			"every looted gun is a fresh unloaded instance",
			"%d shared, %d preloaded" % [shared, preloaded])

	# Counted in ITEMS: same-kind entries merge, so an entry count reads short.
	var table: LootTableData = load("res://data/world/cardboard_box.tres")
	var large: LootContainer = load("res://scenes/props/loot_boxes/cardboard_box_large.tscn").instantiate()
	add_child(large)
	large.fill()
	var items: int = 0
	for entry in large.storage.entries:
		items += entry.count
	check(items > table.draws.y, "a large box rolls extra draws",
			"%d items, past the table's own %d draws" % [items, table.draws.y])
	large.queue_free()


# Every entry has to be reachable, and nothing priceless should be in the bag.
func check_table():
	var seen: Dictionary = {}
	for i in SAMPLES:
		var entry: LootEntryData = TABLE.draw()
		if entry:
			seen[entry.item.name] = seen.get(entry.item.name, 0) + 1
	check(seen.size() == TABLE.entries.size(),
			"every table entry can come up over %d rolls" % SAMPLES,
			"%d of %d: %s" % [seen.size(), TABLE.entries.size(), seen])
	var priceless: Array = TABLE.entries.filter(
			func(e): return e.item.price <= 0).map(func(e): return e.item.name)
	check(priceless.is_empty(), "everything scavenged is worth selling",
			"zero-price: %s" % str(priceless))
	var crate: StorageData = load("res://data/storage/crate_layout.tres")
	var toobig: Array = []
	for entry in TABLE.entries:
		if entry.item.size.x > crate.size.x or entry.item.size.y > crate.size.y:
			toobig.append(entry.item.name)
	check(toobig.is_empty(), "and everything fits a crate", str(toobig))


# The loop closes only if the trucker actually pays for what was in the crate.
func check_sale(p_game: Node, p_crate: LootContainer):
	var service: DeliveryService = find_first(p_game, "DeliveryService")
	if service.truck == null:
		check(false, "the truck is here to sell to", "no truck")
		return
	var ai: DeliveryAI = null
	for child in service.truck.get_children():
		if child is DeliveryAI:
			ai = child
	var worth: int = 0
	for entry in p_crate.storage.entries:
		worth += entry.item.price * entry.count
	PlayerData.current_money = 0
	for entry in p_crate.storage.entries.duplicate():
		ai.goods.add(entry.item, entry.count)
	ai.settle_sale()
	check(PlayerData.current_money == worth and worth > 0,
			"the trucker buys the whole crate",
			"$%d for a haul worth $%d" % [PlayerData.current_money, worth])
