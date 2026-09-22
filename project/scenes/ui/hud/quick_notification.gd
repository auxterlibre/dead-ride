class_name QuickNotification
extends PanelContainer

const TEXT_COLOR: Dictionary = {
	Enums.MessageType.NEUTRAL: LivePalette.DARK_BLUE,
	Enums.MessageType.POSITIVE: LivePalette.DARK_BLUE,
	Enums.MessageType.NEGATIVE: LivePalette.WHITE,
	}

const FRAME_COLOR: Dictionary = {
	Enums.MessageType.NEUTRAL: LivePalette.WHITE,
	Enums.MessageType.POSITIVE: LivePalette.LIGHT_GREEN,
	Enums.MessageType.NEGATIVE: LivePalette.RED,
	}

@onready var label: Label = $Label

var tween: Tween


func _ready() -> void:
	hide()
	Signals.notification_requested.connect(show_message)
	Signals.player_died.connect(hide_message)


func show_message(p_text: String, p_type: Enums.MessageType = Enums.MessageType.NEUTRAL) -> void:
	if visible and label.text == p_text and modulate.a > 0.9:
		if tween: tween.kill()
		tween = create_tween()
		tween.tween_callback(hide_message).set_delay(3.0)
		return
	label.text = p_text
	label.modulate = TEXT_COLOR[p_type]
	self_modulate = FRAME_COLOR[p_type]
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	await  get_tree().process_frame
	reset_size()
	show()
	if tween: tween.kill()
	tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_callback(hide_message).set_delay(3.0)


func hide_message() -> void:
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(hide)
