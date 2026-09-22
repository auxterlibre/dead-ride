@tool
extends EditorPlugin

var inspector: EditorInspectorPlugin = preload("storage_inspector.gd").new()


func _enter_tree():
	add_inspector_plugin(inspector)


func _exit_tree():
	remove_inspector_plugin(inspector)
