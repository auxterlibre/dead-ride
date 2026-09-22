class_name CropSpot
extends Marker3D

@onready var offer: InteractiveArea = $TendArea
@onready var dry_soil: MeshInstance3D = $Soil
@onready var wet_soil: MeshInstance3D = $SoilWet

var plot: CropPlot  # wired by the plot claiming the marker
var index: int = -1


func _ready():
	add_to_group(GrassField.NO_GRASS)
	offer.noticed.connect(refresh_offers)
	Signals.quick_slots_updated.connect(func(_p_entries, _p_active): refresh_offers())
	refresh_offers()


# One offer; the hand picks its job, and a can in hand outranks the harvest.
func refresh_offers():
	var crop: Crop = plot.crop_at(index) if plot else null
	var alive: bool = crop != null and not crop.dead
	offer.enabled = true
	if alive and not crop.watered_today and plot.watering_can() != null:
		offer.action_label = "Water (%dL)" % roundi(plot.water_liters)
	elif alive and crop.fruit_ready:
		offer.action_label = "Harvest (%d %s)" % [crop.pending_produce,
				crop.data.produce.name]
	elif not alive:
		# Bare soil ALWAYS offers, seeds or none: the menu is where you find out
		# what the plot could grow, so hiding it until you already carry the
		# rounds would hide the answer behind the question.
		offer.action_label = "Plant"
	else:
		offer.enabled = false  # growing, watered, nothing in hand to give it
	offer.refresh()
	wet_soil.visible = alive and crop.watered_today
	dry_soil.visible = not wet_soil.visible


# Same order the label advertises.
func tend(p_player = null):
	if plot == null:
		return
	var crop: Crop = plot.crop_at(index)
	var alive: bool = crop != null and not crop.dead
	if alive and not crop.watered_today and plot.watering_can() != null:
		plot.water(index, p_player)
	elif alive and crop.fruit_ready:
		plot.harvest(index, p_player)
	elif not alive:
		# The player picks the species now: the pack opens with a slot to place
		# the rounds in, and the plot is spent from there.
		Signals.planting_opened.emit(plot, index)
