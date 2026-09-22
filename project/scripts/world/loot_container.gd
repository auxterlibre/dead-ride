class_name LootContainer
extends StorageLocker

@export var loot: LootTableData
@export var extra_draws: int = 0  # bigger boxes roll more on top of the table's range

var searched: bool = false


func open(p_player = null):
	if not searched:
		searched = true
		fill()
		mark_searched()
	super(p_player)


# A searched crate keeps its remainder; an unsearched one saves nothing and
# stays a fresh roll for whoever opens it after the load.
func save_state() -> Dictionary:
	var state: Dictionary = super()
	state["searched"] = searched
	return state


func load_state(p_state: Dictionary):
	super(p_state)
	searched = bool(p_state.get("searched", false))
	if searched:
		mark_searched()


# A picked-over crate advertises hollow; the offer itself still stands.
func mark_searched():
	for area in find_children("*", "InteractiveArea"):
		area.spent = true


func fill():
	if loot == null or layout == null:
		return
	for i in loot.roll_draws() + extra_draws:
		var entry: LootEntryData = loot.draw()
		if entry == null:
			continue
		var count: int = entry.roll_count()
		# Stateful items (a magazine, a can's fill) must each be their OWN
		# instance: the canonical .tres would share one state map-wide, and
		# Inventory.add reuses one resource across the entries a count > 1
		# makes - so they go in one fresh duplicate at a time.
		if entry.item.has_own_state():
			for j in count:
				storage.add(entry.item.duplicate(), 1)
		else:
			storage.add(entry.item, count)
