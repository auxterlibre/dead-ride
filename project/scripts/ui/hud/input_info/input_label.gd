class_name InputLabel
extends HBoxContainer

@onready var action:Label = $Action
@onready var key_1:Label = %Key_1
@onready var key_2:Label = %Key_2
@onready var key_3:Label = %Key_3
@onready var key_0:Label = %Key_0
@onready var key_labels:Array[Label] = [key_0, key_1, key_2, key_3]


func set_text(p_keys:Array, p_action:String):
	action.text = p_action
	var label:Label
	for i in key_labels.size():
		label = key_labels[i]
		if i < p_keys.size():
			label.text = p_keys[i]
			label.visible = true
		else:
			label.visible = false
