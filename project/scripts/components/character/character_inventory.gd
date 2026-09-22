class_name CharacterInventory
extends Node
# The backpack grid plus the quick slots over it. The slots are REAL storage,
# not references into the grid: an item on the bar occupies its slot and
# nothing else, equipping moves it out of the pack, stowing moves it back.

const WEAPON_SLOTS: int = 2  # quick slots 0-1; the rest are the item slots

@export var weapons: CharacterWeapons

var backpack: BackpackData
var inventory: Inventory = Inventory.new()
var quick_slots: Array[InventoryEntry] = []
var active_slot: int = -1
var holstered_slot: int = -1  # what the hands put away, to draw again
var prop_return_slot: int = -1  # what the held item displaced; -1 IS a memory: empty hands


func setup(p_backpack: BackpackData, p_weapons: Array[WeaponData],
		p_items: Array[ItemData] = [], p_start_index: int = 0):
	backpack = p_backpack
	if backpack == null or backpack.storage == null:
		return
	inventory.setup(backpack.storage)
	quick_slots.clear()
	quick_slots.resize(backpack.slots)
	# Runtime copies: WeaponData carries live ammo, and two characters sharing
	# a .tres would otherwise share a magazine.
	for i in p_weapons.size():
		var copy: WeaponData = p_weapons[i].duplicate()
		if i < WEAPON_SLOTS:
			quick_slots[i] = InventoryEntry.new(copy, InventoryEntry.NO_CELL)
		else:
			inventory.add_one(copy)  # no slot for it; it rides in the pack
	for item in p_items:
		# Stackables are granted as a full stack - a starting loadout listing
		# ammo means a magazine's worth, not one loose round.
		var copy: ItemData = item.duplicate()
		var count: int = maxi(copy.get_max_stack(), 1)
		# Anything you HOLD opens on the bar; ammo and tools ride in the pack
		# until you put them there yourself. The item says whether it is held,
		# so a loadout never needs to name slots and this never switches on type.
		var slot: int = free_item_slot() if copy.get_held_scene() != null else -1
		if slot >= 0:
			quick_slots[slot] = InventoryEntry.new(copy, InventoryEntry.NO_CELL, count)
		else:
			inventory.add(copy, count)
	if weapons:
		weapons.carried = self  # every reload from here on comes out of the pack
	load_magazines()
	push_weapons()
	# The bar's highlight is the only thing reporting what is in hand, so it has
	# to open pointing at the weapon set_weapons just drew.
	active_slot = equipped_slot()
	# An authored holstered start (CharacterData.current_weapon_idx = -1): the
	# weapons keep their slots, the hands open empty, V draws as usual.
	if p_start_index < 0:
		holster()
	if is_player():
		inventory.changed.connect(func(): Signals.inventory_changed.emit(inventory))
	notify_slots()


# Equipping from the pack MOVES the weapon out of the grid into a weapon slot.
# A displaced weapon goes back into the grid; if the pack cannot take it even
# with the equipped one's cells freed, the equip is refused outright - neither
# gun may silently vanish.
func equip(p_entry: InventoryEntry):
	if p_entry == null or not (p_entry.item is WeaponData):
		return
	var slot: int = quick_slots.find(p_entry)
	if slot >= 0:  # already on the bar: just draw it
		select_slot(slot)
		return
	slot = free_weapon_slot()
	var displaced: InventoryEntry = quick_slots[slot]
	var origin: Vector2i = p_entry.origin
	inventory.remove(p_entry)
	if displaced and inventory.add(displaced.item, displaced.count) > 0:
		inventory.place(p_entry.item, origin, p_entry.count)  # no room: put it back
		return
	p_entry.origin = InventoryEntry.NO_CELL
	quick_slots[slot] = p_entry
	push_weapons()
	select_slot(slot)


# Dropping altogether: a slotted stack empties its slot, a grid stack leaves
# the grid. The caller has already moved the goods wherever they went.
func drop(p_entry: InventoryEntry):
	if p_entry == null:
		return
	var slot: int = quick_slots.find(p_entry)
	if slot >= 0:
		clear_slot(slot)
	else:
		inventory.remove(p_entry)
		notify_slots()


# Moves an entry INTO a slot - from the grid, from another slot, or from an
# open container (p_from). A displaced occupant swaps back to wherever the
# arrival came from, and the whole move is refused when it cannot: with real
# storage an overwrite would destroy the occupant, so there is no overwrite.
func assign_quick_slot(p_entry: InventoryEntry, p_slot: int,
		p_from: Inventory = null):
	if p_slot < 0 or p_slot >= quick_slots.size():
		return
	if p_entry == null:
		clear_slot(p_slot)
		return
	if quick_slots[p_slot] == p_entry or not slot_accepts(p_entry.item, p_slot):
		return
	var previous: int = quick_slots.find(p_entry)
	var displaced: InventoryEntry = quick_slots[p_slot]
	# A slot-to-slot swap must respect the source slot's type rule too.
	if displaced and previous >= 0 and not slot_accepts(displaced.item, previous):
		return
	# Take the arrival out of wherever it lives.
	var home: Inventory = null  # a grid the displaced occupant should go to
	if previous >= 0:
		quick_slots[previous] = null
	elif p_from and p_from.entries.has(p_entry):
		home = p_from
		p_from.remove(p_entry)
	elif inventory.entries.has(p_entry):
		home = inventory
		inventory.remove(p_entry)
	if displaced:
		if previous >= 0:
			quick_slots[previous] = displaced
		elif (home if home else inventory).add(displaced.item, displaced.count) > 0:
			# The occupant fits nowhere: undo the removal and refuse the move.
			if home:
				home.add(p_entry.item, p_entry.count)
			return
	p_entry.origin = InventoryEntry.NO_CELL
	quick_slots[p_slot] = p_entry
	if previous == active_slot and previous != p_slot:
		active_slot = -1
	if p_slot < WEAPON_SLOTS or previous < WEAPON_SLOTS \
			or (displaced != null and displaced.item is WeaponData):
		push_weapons()
	notify_slots()


# Empties a slot WITHOUT moving the item - bookkeeping for after the stack has
# already gone elsewhere (a drag that landed, the last grenade thrown).
func clear_slot(p_slot: int):
	if p_slot < 0 or p_slot >= quick_slots.size():
		return
	var was_weapon: bool = quick_slots[p_slot] != null \
			and quick_slots[p_slot].item is WeaponData
	quick_slots[p_slot] = null
	if p_slot == active_slot:
		active_slot = -1
		if p_slot < WEAPON_SLOTS and weapons:
			weapons.holster()
		elif weapons:
			weapons.clear_prop()  # the last grenade thrown leaves the hand empty
	if p_slot < WEAPON_SLOTS or was_weapon:
		push_weapons()
	notify_slots()


# Moves a slot's stack back into the grid - the right-click path. Stacks pour
# into their kind first; whatever the pack has no room for stays on the slot.
func stow_slot(p_slot: int):
	if p_slot < 0 or p_slot >= quick_slots.size() or quick_slots[p_slot] == null:
		return
	var entry: InventoryEntry = quick_slots[p_slot]
	var leftover: int = inventory.add(entry.item, entry.count)
	if leftover >= entry.count:
		return  # no room at all; the slot keeps it
	entry.count = leftover
	if leftover <= 0:
		clear_slot(p_slot)
	else:
		notify_slots()


# Fills off the loadout's own rounds, so the granted stacks are the whole allowance.
func load_magazines():
	for entry in weapon_entries():
		var weapon: WeaponData = entry.item as WeaponData
		if weapon and weapon.is_ranged and weapon.current_ammo == -1:
			weapon.current_ammo = weapon.max_ammo


# The active ITEM slot's item - null while a weapon is drawn or holstered.
func held_item() -> ItemData:
	if active_slot < WEAPON_SLOTS or active_slot >= quick_slots.size():
		return null
	var entry: InventoryEntry = quick_slots[active_slot]
	return entry.item if entry else null


# Every stack carried anywhere - the grid plus the item slots. The weapon
# slots stay out: a gun is a gun, not luggage.
func carried_entries() -> Array[InventoryEntry]:
	var result: Array[InventoryEntry] = inventory.entries.duplicate()
	for i in range(WEAPON_SLOTS, quick_slots.size()):
		if quick_slots[i] != null:
			result.append(quick_slots[i])
	return result


# Kind-wise count across grid and item slots - the garden's seed arithmetic
# obeys the same rule as the ammo reserve: parked on the bar is still carried.
func count_kind(p_item: ItemData) -> int:
	var total: int = 0
	for entry in carried_entries():
		if entry.item.same_kind(p_item):
			total += entry.count
	return total


# Kind-wise withdrawal, grid first, slots after. Returns what was taken.
func take_kind(p_item: ItemData, p_count: int) -> int:
	var taken: int = inventory.take(p_item, p_count)
	for i in range(WEAPON_SLOTS, quick_slots.size()):
		if taken >= p_count:
			break
		var entry: InventoryEntry = quick_slots[i]
		if entry == null or not entry.item.same_kind(p_item):
			continue
		var slice: int = mini(entry.count, p_count - taken)
		entry.count -= slice
		taken += slice
		if entry.count <= 0:
			clear_slot(i)
	if taken > 0:
		notify_slots()
	return taken


# Every carried stack of a calibre - ammo a player parked on the bar is still
# reserve, and a reload finds it there.
func ammo_entries(p_type: Enums.AmmoType) -> Array[InventoryEntry]:
	var result: Array[InventoryEntry] = []
	for entry in carried_entries():
		var ammo: AmmoData = entry.item as AmmoData
		if ammo and ammo.ammo_type == p_type:
			result.append(entry)
	return result


# Rounds of a calibre carried outside the magazines. This is the RESERVE -
# what is already loaded is not in the pack.
func ammo_count(p_type: Enums.AmmoType) -> int:
	var total: int = 0
	for entry in ammo_entries(p_type):
		total += entry.count
	return total


# Takes up to p_amount rounds of a calibre out of the pack for a reload.
# Returns how many were actually available and taken.
func spend_ammo(p_type: Enums.AmmoType, p_amount: int) -> int:
	var left: int = p_amount
	for entry in ammo_entries(p_type):
		if left <= 0:
			break
		var taken: int = mini(entry.count, left)
		entry.count -= taken
		left -= taken
		if entry.count <= 0:
			if inventory.entries.has(entry):
				inventory.remove(entry)
			else:
				clear_slot(quick_slots.find(entry))
	if left < p_amount:
		inventory.changed.emit()
		notify_slots()
	return p_amount - left


# Weapon slots hold weapons; item slots take anything else you might want on a
# number key.
func slot_accepts(p_item: ItemData, p_slot: int) -> bool:
	if p_slot < 0 or p_slot >= quick_slots.size():
		return false
	return p_item is WeaponData if p_slot < WEAPON_SLOTS else not (p_item is WeaponData)


func select_slot(p_slot: int):
	if p_slot < 0 or p_slot >= quick_slots.size() or quick_slots[p_slot] == null:
		return
	active_slot = p_slot
	if p_slot < WEAPON_SLOTS and weapons:
		weapons.equip(weapon_slot_index(p_slot))
	elif weapons:
		if quick_slots[p_slot].item.get_held_scene():
			# What this held item displaces, recorded NOW - empty hands are a
			# real answer, not a gap to fill from an older memory. The drawn
			# gun also feeds V's own memory, the way the V-toggle records it.
			prop_return_slot = equipped_slot()
			if prop_return_slot >= 0:
				holstered_slot = prop_return_slot
		# The ITEM says whether it is held, so this never switches on type: a
		# throwable takes the hand off the gun, ammo and tools do not.
		weapons.hold_prop(quick_slots[p_slot].item.get_held_scene())
	notify_slots()


# Bare hands as a STATE to land on, not a toggle: prop gone, nothing drawn,
# no slot active, V's memory untouched. holster() FLIPS - called with empty
# hands it draws the old gun, the exact opposite of returning to empty.
func bare_hands():
	if weapons:
		weapons.clear_prop()
		weapons.holster()
	active_slot = -1
	notify_slots()


# Toggles; the slot is kept internally so pressing again draws the same gun.
func holster():
	if weapons == null:
		return
	if weapons.is_holstered():
		select_slot(holstered_slot)
		return
	holstered_slot = equipped_slot()
	active_slot = -1
	weapons.holster()
	notify_slots()


# Which weapon slot holds the gun in hand. Not active_slot: that can be
# pointing at an item slot while a weapon is still drawn.
func equipped_slot() -> int:
	if weapons == null or weapons.current_weapon == null:
		return -1
	for i in mini(WEAPON_SLOTS, quick_slots.size()):
		if quick_slots[i] and quick_slots[i].item == weapons.current_weapon:
			return i
	return -1


# The weapon slots, compacted - CharacterWeapons indexes a dense array, so an
# empty slot 0 must not shift slot 1's weapon out from under it.
func weapon_entries() -> Array[InventoryEntry]:
	var result: Array[InventoryEntry] = []
	for i in mini(WEAPON_SLOTS, quick_slots.size()):
		if quick_slots[i] != null:
			result.append(quick_slots[i])
	return result


func weapon_slot_index(p_slot: int) -> int:
	return weapon_entries().find(quick_slots[p_slot])


func push_weapons():
	if weapons == null:
		return
	var carried: Array[WeaponData] = []
	for entry in weapon_entries():
		carried.append(entry.item)
	# set_weapons draws slot 0 when the hands are empty - right on first arming, wrong after.
	var stay_holstered: bool = weapons.is_holstered() \
			and not weapons.inventory.is_empty()
	weapons.set_weapons(carried)
	if stay_holstered:
		weapons.holster()


func free_weapon_slot() -> int:
	for i in WEAPON_SLOTS:
		if quick_slots[i] == null:
			return i
	return 0  # both full: the active weapon is the one being replaced


# The first empty slot past the weapon pair, or -1 when the bar is full. Unlike
# free_weapon_slot there is nothing sensible to displace, so a full bar simply
# leaves the item in the pack.
func free_item_slot() -> int:
	for i in range(WEAPON_SLOTS, quick_slots.size()):
		if quick_slots[i] == null:
			return i
	return -1


func is_player() -> bool:
	return get_parent().is_in_group("player")


func notify_slots():
	if is_player():
		Signals.quick_slots_updated.emit(quick_slots, active_slot)
