extends ProbeBase
# Windowed only - headless renders blank. Opens the pack and saves the panel
# for the eyeball pass against the Figma frame, asserting the geometry that
# must match the mockup's literal pixels.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	if not windowed("the backpack panel"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(8)
	var screen: BackpackScreen = game.find_children("*", "BackpackScreen", true, false).front()
	screen.open()
	await settle(8)  # layout passes, the blur, the slot widths applied at setup

	var panel: BackpackPanelUI = screen.backpack_panel
	check(panel.size.x == 896.0, "the panel is the mockup's 896 wide",
			str(panel.size))
	var weapon_tray: Control = panel.find_child("WeaponTray", true, false)
	var item_tray: Control = panel.find_child("ItemTray", true, false)
	check(weapon_tray.size == Vector2(576.0, 164.0),
			"the weapon tray is the mockup's 576x164", str(weapon_tray.size))
	check(item_tray.size == Vector2(640.0, 164.0),
			"the item tray is the mockup's 640x164", str(item_tray.size))
	var shot: Image = await capture()
	save_shot(shot, "backpack_panel")
	finish()
