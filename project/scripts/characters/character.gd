class_name Character
extends CharacterBody3D

signal died
signal damaged(attack)

@export var data:CharacterData

var current_health:int
var stored_collision_layer:int
var is_dead:bool = false

var movement:CharacterMovement
var animator:CharacterAnimator
var aim:PlayerAim
var weapons:CharacterWeapons
var carried:CharacterInventory
var trail:CharacterTrail
var heat:PlayerHeat
var dodging:CharacterDodge

@onready var camera_spot:Marker3D = get_node_or_null("CameraSpot")
@onready var body_container:Node3D = %BodyContainer
@onready var hurt_box:HurtBox = get_node_or_null("%HurtBox")
@onready var debug_label: Label3D = get_node_or_null("%DebugLabel")


func _ready():
	add_to_group("character")
	for child in get_children():
		if child is CharacterMovement:
			movement = child
		elif child is CharacterAnimator:
			animator = child
		elif child is PlayerAim:
			aim = child
		elif child is CharacterWeapons:
			weapons = child
		elif child is CharacterInventory:
			carried = child
		elif child is CharacterTrail:
			trail = child
		elif child is PlayerHeat:
			heat = child
		elif child is CharacterDodge:
			dodging = child
	if is_in_group("player"):
		InputManager.player = self
		if Globals.camera_follow:
			Globals.camera_follow.target = self
	if movement:
		movement.face_movement = aim == null  # PlayerAim owns facing when present
	apply_data()


func apply_data():
	if data == null: return
	await get_tree().process_frame
	body_container.update_meshes(data.body_path)
	body_container.update_backpack(data.backpack)
	current_health = data.max_health
	# First fill for the HUD bar - it read 0/max until the first hit.
	if is_in_group("player"):
		Signals.health_updated.emit(current_health, data.max_health)
	if movement:
		movement.speed = data.speed
	if carried:
		carried.setup(data.backpack, data.weapon_inventory, data.starting_items,
				data.current_weapon_idx)
	elif weapons:
		weapons.setup(data.weapon_inventory, data.current_weapon_idx)


func get_faction() -> Enums.Faction:
	return data.faction if data else Enums.Faction.PLAYER


# Different faction = hostile. Anything exposing get_faction() can be a target.
func is_hostile_to(p_other) -> bool:
	if p_other == null or not p_other.has_method("get_faction"):
		return false
	var other_faction:int = p_other.get_faction()
	return other_faction != -1 and int(get_faction()) != other_faction


func take_damage(p_attack:AttackData):
	if is_dead:
		return
	current_health = maxi(current_health - p_attack.damage, 0)
	if is_in_group("player"):
		Signals.health_updated.emit(current_health, data.max_health if data else 0)
	if movement and p_attack.knockback_distance > 0.0:
		movement.apply_knockback(p_attack.knockback_origin, p_attack.knockback_distance)
	damaged.emit(p_attack)
	if current_health <= 0:
		die()


# The consumables' entry point: clamped to full, and never a revival.
func heal(p_amount:int):
	if is_dead or data == null or p_amount <= 0:
		return
	current_health = mini(current_health + p_amount, data.max_health)
	if is_in_group("player"):
		Signals.health_updated.emit(current_health, data.max_health)


# Basic death: the corpse stays - dead clip held on its last frame, combat
# and locomotion off. Hit reactions and cleanup arrive with the AI work.
func die():
	is_dead = true
	if animator:
		animator.play_death(data.dead_animation if data else "death_a")
	if movement:
		movement.become_corpse()  # momentum (a ramming car) still plays out
	if weapons:
		weapons.cancel_reload()
		weapons.process_mode = Node.PROCESS_MODE_DISABLED  # no aiming/firing/reloading
	if aim:
		aim.process_mode = Node.PROCESS_MODE_DISABLED
	if hurt_box:
		# Hand back what a dodge in flight borrowed BEFORE death takes it for
		# good, or the roll's own end would restore a live layer on a corpse.
		hurt_box.immune = false
		hurt_box.monitoring = false
		hurt_box.collision_layer = 0
	collision_layer = 0
	died.emit()
	if is_in_group("player"):
		Signals.player_died.emit()  # the bus signal; died stays for local brains


func enter_vehicle(_p_vehicle:Vehicle):
	stored_collision_layer = collision_layer
	collision_layer = 0
	if hurt_box:
		hurt_box.monitorable = false  # the car soaks the shots, not the seat
	visible = false
	reparent(_p_vehicle)
	process_mode = Node.PROCESS_MODE_DISABLED


func exit_vehicle():
	collision_layer = stored_collision_layer
	if hurt_box:
		hurt_box.monitorable = true
	reparent(get_tree().current_scene)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
