class_name HurtBox
extends Area3D

const FLASH_COLOR:Color = Color(4.0, 0.8, 0.2)  # HDR - glows under bloom
const SPARK_COLOR:Color = Color(1.0, 0.35, 0.2)

@onready var DAMAGE_LABEL:PackedScene = load("uid://ddh2lrfovvkss")
@onready var FLESH_IMPACT:GDScript = load("uid://drpgq7sy0wec4")

var flash_material:StandardMaterial3D
var flash_tween:Tween
# A dodge's i-frames. The FLAG swallows what is already on its way (a tracer's
# flight is timed, and melee calls hit() straight), while dropping the LAYER
# makes new rays miss outright, so the shot carries on to the wall behind
# instead of stopping dead in a body it cannot hurt.
var immune:bool = false : set = set_immune
var live_layer:int = 0  # the layer immunity took away, to hand back


func _ready():
	area_entered.connect(_on_area_entered)


func _on_area_entered(area):
	if not area is HitBox: return
	hit(area.attack_data)


func set_immune(p_value:bool):
	if p_value == immune:
		return
	immune = p_value
	if p_value:
		live_layer = collision_layer
		collision_layer = 0
	else:
		collision_layer = live_layer


# Single damage entry point - melee overlaps and hitscan rays both land here.
func hit(p_attack_data:AttackData):
	if immune:
		return
	spawn_damage_label(p_attack_data.damage)
	flash()
	ImpactSpark.spawn(get_tree().current_scene,
			global_position + Vector3.UP * 1.2, SPARK_COLOR,
			0.3 + p_attack_data.damage * 0.06)
	# Owners tagged with a surface (the car's metal) are hard targets: they
	# get the weapon's impact kit instead of blood.
	if owner == null or not owner.has_meta("surface"):
		spawn_flesh_impact(p_attack_data)
	if owner and owner.has_method("take_damage"):
		owner.take_damage(p_attack_data)


# Shared overlay across the owner's meshes; hits tween its alpha (Melee Arena
# style). Re-checks assignments each flash so runtime mesh swaps stay covered.
func flash():
	if flash_material == null:
		flash_material = StandardMaterial3D.new()
		flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh_instance in owner.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.material_overlay != flash_material:
			mesh_instance.material_overlay = flash_material
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	var color:Color = FLASH_COLOR
	color.a = 0.85
	flash_material.albedo_color = color
	flash_tween = create_tween()
	flash_tween.tween_property(flash_material, "albedo_color:a", 0.0, 0.18)


# Blood exits on the far side of the hit (along the attack's travel), and the
# pool lands on the floor at the owner's feet.
func spawn_flesh_impact(p_attack_data:AttackData):
	var exit:Vector3 = global_position - p_attack_data.knockback_origin
	exit.y = 0.0
	var impact:FleshImpact = FLESH_IMPACT.new()
	impact.setup(global_position + Vector3.UP * 1.1, exit,
			owner.global_position.y if owner is Node3D else global_position.y,
			p_attack_data.damage)
	get_tree().current_scene.add_child(impact)


func spawn_damage_label(p_damage:int):
	var label:Label3D = DAMAGE_LABEL.instantiate()
	get_tree().current_scene.add_child(label)
	label.global_position = global_position + Vector3.UP * randf_range(2.0, 2.4) \
			+ Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	label.text = str(p_damage)
	label.animate(label.position.y + 1.5)
