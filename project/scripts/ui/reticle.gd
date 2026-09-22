class_name Reticle
extends Control

@export var base_size:float = 64.0
@export var max_spread:float = 128.0  # extra size per side at full spread
@export var spread_weight:float = 0.3  # display smoothing toward the real value

@onready var distance_label: Label = $DistanceLabel
@onready var assault_rifle: Control = %AssaultRifle
@onready var shotgun: Control = %Shotgun
@onready var smg: Control = %SMG
@onready var pistol: Control = %Pistol
@onready var revolver: Control = %Revolver
@onready var sniper_rifle: Control = %SniperRifle
@onready var unarmed: Control = %Unarmed
@onready var by_class: Dictionary = {
	Enums.WeaponClass.ASSAULT_RIFLE: assault_rifle,
	Enums.WeaponClass.SHOTGUN: shotgun,
	Enums.WeaponClass.SMG: smg,
	Enums.WeaponClass.PISTOL: pistol,
	Enums.WeaponClass.REVOLVER: revolver,
	Enums.WeaponClass.RIFLE: sniper_rifle,
}

var spread:float = 0.0
var target_spread:float = 0.0


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_label.grow_horizontal = Control.GROW_DIRECTION_END
	distance_label.grow_vertical = Control.GROW_DIRECTION_END
	Signals.spread_updated.connect(func(p_total): target_spread = p_total)
	Signals.drive_state_changed.connect(func(p_driving): visible = not p_driving)
	Signals.aim_distance_updated.connect(update_distance)
	Signals.weapon_setup.connect(show_for)
	show_for(null)  # the scene ships with a design-time child left visible



func show_for(p_weapon: WeaponData):
	var chosen: Control = by_class.get(p_weapon.weapon_class, unarmed) \
			if p_weapon else unarmed
	for child in by_class.values():
		child.visible = child == chosen
	unarmed.visible = chosen == unarmed


func _process(_delta):
	spread = lerpf(spread, target_spread, spread_weight)
	size = Vector2.ONE * (base_size + spread * max_spread * 2.0)
	global_position = get_global_mouse_position() - size * 0.5


func update_distance(p_value: float, p_too_far: bool = false) -> void:
	distance_label.label_settings.font_color = Palette.RED if p_too_far else Palette.WHITE
	distance_label.text = "%.1fm" % p_value
