class_name PlantingPanelUI
extends ContainerPanelUI
# The bare crop spot's menu, opened beside the pack: one slot to place seed
# rounds in, a readout of what they would grow, and the button that commits.
# THE SLOT IS REAL STORAGE, like the quick slots are - what rests in it is out
# of the pack and belongs to nothing that saves, so `release` pours it back the
# moment the screen closes and nothing is ever left stranded in here.

signal planted

@onready var status_label: Label = %StatusLabel
@onready var plant_button: InputKeyButton = %PlantButton

var slot: Inventory = Inventory.new()
var plot: CropPlot
var spot: int = -1


func _ready():
	var mask: StorageData = StorageData.new()
	mask.layout = "."  # the single slot the card asks for
	slot.setup(mask)
	setup("Plant", slot)
	slot.changed.connect(refresh)
	plant_button.pressed.connect(plant)
	refresh()


# Never clears the slot: a stack still sitting in it is the player's, and the
# close that follows is what hands it back.
func open_for(p_plot: CropPlot, p_spot: int):
	plot = p_plot
	spot = p_spot
	refresh()


# What the placed rounds would grow HERE - the plot's own species list decides,
# so a plot that grows no heavy vines simply has no answer for heavy rounds.
func species_for(p_item: ItemData) -> CropData:
	if plot == null or p_item == null:
		return null
	for kind in plot.species:
		if kind.seed_item and kind.seed_item.same_kind(p_item):
			return kind
	return null


func held() -> InventoryEntry:
	return slot.entries[0] if not slot.entries.is_empty() else null


# The button offers only what is actually payable, and the line under it says
# why when it does not - the offers' conditional advertising, indoors.
func refresh():
	var entry: InventoryEntry = held()
	var kind: CropData = species_for(entry.item) if entry else null
	plant_button.disabled = kind == null or entry.count < kind.seed_count
	if entry == null:
		status_label.text = "Place seed rounds in the slot"
	elif kind == null:
		status_label.text = "%s grows nothing here" % entry.item.name
	elif entry.count < kind.seed_count:
		status_label.text = "%s needs %d %s - %d placed" % [kind.name,
				kind.seed_count, kind.seed_item.name, entry.count]
	else:
		status_label.text = "%s - %d %s" % [kind.name, kind.seed_count,
				kind.seed_item.name]


# Spot first, then the seeds: a refused plant must not eat them, the order
# plant_from_pack has always used. The change is only WHO chooses the species.
func plant():
	var entry: InventoryEntry = held()
	var kind: CropData = species_for(entry.item) if entry else null
	if kind == null or entry.count < kind.seed_count:
		return
	if plot == null or plot.plant(kind, spot) == null:
		return
	entry.count -= kind.seed_count
	if entry.count <= 0:
		slot.remove(entry)
	else:
		slot.changed.emit()
	planted.emit()


# Whatever the player placed goes home. The cells it came from are still free -
# nothing can enter the pack while this panel is the one open beside it - so
# the round trip fits; a leftover that somehow did not stays in the slot rather
# than being destroyed, and is still here the next time a spot is opened.
func release(p_pack: Inventory):
	var entry: InventoryEntry = held()
	if entry == null or p_pack == null:
		return
	var leftover: int = p_pack.add(entry.item, entry.count)
	if leftover <= 0:
		slot.remove(entry)
	elif leftover != entry.count:
		entry.count = leftover
		slot.changed.emit()
