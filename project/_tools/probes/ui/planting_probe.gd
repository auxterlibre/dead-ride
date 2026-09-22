extends ProbeBase
# DBG probe: the crop plot's planting menu - a bare spot opens the pack with a
# slot beside it, the slot names what the placed rounds would grow, the button
# offers only what is payable, planting spends EXACTLY the seed claim, and
# nothing left in the slot can be stranded there when the screen closes.


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await settle(8)
	var screen: BackpackScreen = find_first(game, "BackpackScreen")
	var plot: CropPlot = find_first(game, "CropPlot")
	if not check(screen != null and plot != null,
			"the station carries a garden and the pack screen",
			"%s / %s" % [screen, plot]):
		finish()
		return
	var panel: PlantingPanelUI = screen.planting_panel
	var pack: Inventory = InputManager.player.carried.inventory
	var light: CropData = load("res://data/crops/light_ammo_bush.tres")
	var bandage: ItemData = load("res://data/items/consumables/field_bandage.tres")

	var bare: int = -1
	for i in plot.spots.size():
		if plot.crop_at(i) == null:
			bare = i
			break
	if not check(bare >= 0, "and a spot standing empty to plant in", str(bare)):
		finish()
		return

	# --- the REAL path: the spot's own offer opens the menu
	var spot: CropSpot = plot.spots[bare]
	check(spot.offer.enabled and spot.offer.action_label == "Plant",
			"bare soil advertises planting with nothing in hand",
			spot.offer.action_label)
	spot.tend()
	await settle(2)
	check(screen.visible and panel.visible and get_tree().paused,
			"and taking it opens the pack with the slot beside it", "open")
	check(panel.plant_button.disabled and panel.held() == null,
			"an empty slot offers no planting", panel.status_label.text)

	# --- the slot judges what is in it
	panel.slot.add(bandage, 1)
	check(panel.plant_button.disabled \
			and panel.status_label.text.contains("grows nothing"),
			"something that seeds nothing here says so", panel.status_label.text)
	panel.slot.remove(panel.held())
	panel.slot.add(light.seed_item, light.seed_count - 1)
	check(panel.plant_button.disabled \
			and panel.status_label.text.contains("needs"),
			"one round short still refuses", panel.status_label.text)
	# One more, plus a surplus that must survive the planting untouched.
	panel.slot.add(light.seed_item, 1 + 5)
	check(not panel.plant_button.disabled \
			and panel.status_label.text.contains(light.name),
			"the exact claim arms the button and names what it grows",
			panel.status_label.text)

	# --- the card lets go when the pointer does. A one-cell grid is ALL item,
	# so there is no blank cell to slide onto and clear the selection in
	# passing - leaving has to do it, or the tooltip hangs over nothing.
	panel.grid.select(panel.held())
	screen.on_selection_changed(panel.held())
	await settle(2)
	check(screen.tooltip.visible, "hovering the slotted stack raises its card",
			"shown")
	panel.grid.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await settle(2)
	check(panel.grid.selected == null and not screen.tooltip.visible,
			"and leaving the slot drops both the selection and the card",
			"selected %s, card %s" % [panel.grid.selected, screen.tooltip.visible])

	# --- planting spends the claim and nothing more
	var banked: int = pack.count_of(light.seed_item)
	panel.plant()
	await settle(2)
	var crop: Crop = plot.crop_at(bare)
	check(crop != null and crop.data == light, "planting puts the chosen species in",
			str(crop.data.name) if crop else "nothing")
	check(not screen.visible and not get_tree().paused,
			"and closes the pack behind it", "closed")
	# The surplus rode out on the close, which is the release doing its job.
	check(pack.count_of(light.seed_item) == banked + 5,
			"the surplus goes back to the pack, the claim does not",
			"%d -> %d rounds" % [banked, pack.count_of(light.seed_item)])
	check(panel.held() == null, "leaving the slot empty", str(panel.held()))

	# --- an occupied spot is not offered again
	spot.refresh_offers()
	check(not spot.offer.enabled or spot.offer.action_label != "Plant",
			"a planted spot stops advertising the planting",
			spot.offer.action_label if spot.offer.enabled else "disabled")

	# --- NOTHING CAN BE STRANDED: a slot loaded and abandoned pours back
	var next: int = -1
	for i in plot.spots.size():
		if plot.crop_at(i) == null:
			next = i
			break
	if check(next >= 0, "another empty spot to abandon", str(next)):
		plot.spots[next].tend()
		await settle(2)
		var before: int = pack.count_of(light.seed_item)
		panel.slot.add(light.seed_item, 3)
		screen.close()
		await settle(2)
		check(panel.held() == null and pack.count_of(light.seed_item) == before + 3,
				"closing on a loaded slot hands it all back",
				"%d -> %d rounds" % [before, pack.count_of(light.seed_item)])

	finish()
