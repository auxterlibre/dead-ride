class_name InventoryDrag
# Shared shape of a drag payload: entry, source, slot, owner, grab cell, preview widget.


static func begin(p_entry: InventoryEntry, p_grab: Vector2i) -> Dictionary:
	return {"entry": p_entry, "source": null, "slot": -1, "owner": null,
			"grab": p_grab, "preview": null}


static func is_drag(p_data: Variant) -> bool:
	return p_data is Dictionary and p_data.has("entry") and p_data.entry != null


# The grabbed cell rides under the cursor, so a 3x2 dropped from its right end
# lands where it looks like it will.
static func build_preview(p_data: Dictionary, p_scene: PackedScene,
		p_cell: int) -> Control:
	var holder: Control = Control.new()
	var widget: InventoryItemUI = p_scene.instantiate()
	holder.add_child(widget)
	widget.setup(p_data.entry, p_cell)
	widget.position = -(Vector2(p_data.grab) + Vector2(0.5, 0.5)) * p_cell
	p_data.preview = widget
	return holder


static func mark(p_data: Dictionary, p_valid: bool):
	if p_data.preview != null and is_instance_valid(p_data.preview):
		p_data.preview.set_invalid(not p_valid)
