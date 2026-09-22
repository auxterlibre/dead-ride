class_name InputInfoUI
extends VBoxContainer

@onready var label_list:Array = get_children()

var input_list:Dictionary = {}


func _ready():
	Signals.input_info_added.connect(add_input)
	Signals.input_info_removed.connect(remove_input)
	Signals.player_died.connect(fade_out)
	for label:InputLabel in label_list:
		label.visible = false

func add_input(p_keys:Array, p_action:String, p_placement:int,
		_p_input_action:String):
	# The quiet channel: standing help like the driving controls. Offers beside
	# the character are CharacterPromptsUI's.
	if p_placement != Enums.PromptPlacement.CORNER:
		return
	# Re-announcing a key (prompt swap between overlapping areas) reuses its
	# label so the old one can't stay visible orphaned.
	var label = input_list.get(p_keys)
	if label == null:
		label = get_empty_label()
	if label == null:
		return
	input_list[p_keys] = label
	label.set_text(p_keys, p_action.to_upper())
	fade_in_label(label)


func remove_input(p_keys):
	if not input_list.has(p_keys):
		return
	input_list[p_keys].visible = false
	input_list.erase(p_keys)


func get_empty_label() -> InputLabel:
	for label in label_list:
		if not label.visible:
			return label
	return null


func fade_in_label(p_label):
	p_label.modulate.a = 0.0
	p_label.visible = true
	var tween := create_tween()
	tween.tween_property(p_label, "modulate:a", 1.0, 0.3)


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(hide)


func fade_in() -> void:
	self.modulate.a = 0
	show()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)
