class_name ContainerPanelUI
extends PanelContainer
# One titled storage panel. The backpack screen instances it once for the pack
# and again for whatever container is open beside it.

@onready var title_label: Label = %TitleLabel
@onready var grid: InventoryGridUI = %Grid


func setup(p_title: String, p_inventory: Inventory):
	title_label.text = p_title.to_upper()
	grid.setup(p_inventory)
