@tool
extends EditorInspectorPlugin

const GridProperty: GDScript = preload("storage_grid_property.gd")


func _can_handle(p_object: Object) -> bool:
	return p_object is StorageData


# The layout keeps its ASCII string - every authored .tres stays valid and the
# diffs stay readable - but the INSPECTOR draws it as the checkbox grid the
# finicky multiline box should always have been.
func _parse_property(p_object: Object, p_type: Variant.Type, p_name: String,
		_p_hint: PropertyHint, _p_hint_text: String, _p_usage: int,
		_p_wide: bool) -> bool:
	if p_name != "layout":
		return false
	add_property_editor(p_name, GridProperty.new())
	return true  # the default multiline editor stays out of it
