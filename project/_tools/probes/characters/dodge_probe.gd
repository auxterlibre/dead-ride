extends ProbeBase
# DBG probe: the dodge - SPACE rolls the body along its own intent, committed
# and untouchable for as long as the clip runs, paid for in energy and rationed
# by a cooldown. The skill is SHARED, so a bare enemy given the component
# dodges too, and dying mid-roll must leave the corpse inert.

const REVOLVER: String = "res://data/items/weapons/ranged/revolver.tres"

var player: Character
var skill: PlayerDodge
var energy: PlayerEnergy
var movement: CharacterMovement
var skeleton: Skeleton3D


func _ready():
	SaveManager.save_path = "user://probe_dodge.json"
	SaveManager.backup_path = "user://probe_dodge.bak"
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	await settle(4)
	# The gym enemy would shoot the dodger mid-measurement; hold its brain.
	var brain: Node = find_first(gym, "EnemyAI")
	if brain:
		brain.process_mode = Node.PROCESS_MODE_DISABLED
	player = InputManager.player
	skill = player.dodging as PlayerDodge
	movement = player.movement
	energy = find_first(player, "PlayerEnergy") as PlayerEnergy
	skeleton = player.find_child("Skeleton3D", true, false) as Skeleton3D
	if not check(skill != null and skill is CharacterDodge,
			"the player carries the shared skill",
			"%s (base %s)" % [skill, "CharacterDodge" if skill is CharacterDodge else "?"]):
		finish()
		return
	# The loadout is the designer's; this probe's subject is the roll, so it
	# arms its own gun to prove the trigger goes quiet.
	var revolver: WeaponData = (load(REVOLVER) as WeaponData).duplicate()
	revolver.current_ammo = revolver.max_ammo
	player.weapons.set_weapons([revolver] as Array[WeaponData], 0)
	await settle(4)

	await test_the_roll(revolver)
	await test_the_clip()
	test_the_directions()
	await test_the_rations()
	await test_the_enemy(gym)
	finish()


# --- the roll itself: input, i-frames, travel, commitment
func test_the_roll(p_weapon: WeaponData):
	var from: Vector3 = player.global_position
	press("dodge")
	await settle(2)
	release("dodge")
	if not check(skill.dodging(), "SPACE starts a roll", "window %.2fs" % skill.window):
		return
	# The i-frames, measured the way a bullet actually asks: a hurt-layer ray at
	# chest height finds nothing to hit while the roll is on.
	var health: int = player.current_health
	check(not shot_finds(), "a shot's ray finds no one to hit mid-roll",
			"layer %d, immune %s" % [player.hurt_box.collision_layer,
			player.hurt_box.immune])
	# ...and what was ALREADY in flight lands on nothing: a tracer's hit is
	# scheduled, and melee calls hit() straight past the layers.
	player.hurt_box.hit(AttackData.new(25, from + Vector3.RIGHT, 0.0, null))
	check(player.current_health == health, "and a hit already on its way is swallowed",
			"%d/%d" % [player.current_health, health])
	# The trigger is dead too - the click must not leave the barrel mid-roll.
	var ammo: int = p_weapon.current_ammo
	press("attack")
	await settle(2)
	release("attack")
	check(p_weapon.current_ammo == ammo, "and the trigger is dead until it lands",
			"%d rounds, still %d" % [ammo, p_weapon.current_ammo])
	# Committed: steering the other way mid-roll must not turn it.
	press("move_down")
	await wait(skill.duration() * 0.5)
	var heading: Vector3 = Vector3(movement.body.velocity.x, 0.0,
			movement.body.velocity.z).normalized()
	check(heading.dot(movement.dash_velocity.normalized()) > 0.99,
			"the roll cannot be steered once it starts",
			"%.2f off the launch heading" % heading.dot(movement.dash_velocity.normalized()))
	release("move_down")
	await wait(skill.duration())
	var travelled: float = from.distance_to(player.global_position)
	check(not skill.dodging(), "the clip's length is the whole roll",
			"%.2fs window" % skill.duration())
	check(absf(travelled - skill.distance) < skill.distance * 0.35,
			"it carries the authored distance",
			"%.2fm of %.2fm" % [travelled, skill.distance])
	check(player.hurt_box.collision_layer != 0 and not player.hurt_box.immune,
			"and the body is hittable again the moment it lands",
			"layer %d" % player.hurt_box.collision_layer)
	check(player.animator.upper_weight > 0.0,
			"the hands come back to the gun they were holding",
			"upper weight %.2f" % player.animator.upper_weight)


# --- the clip reaches the SKELETON, not just the upper layer. Measured against
# the idle's own breathing drift, and with the travel dialled out so locomotion
# cannot be what moved the bones.
func test_the_clip():
	var reach: float = skill.distance
	var cooldown: float = skill.cooldown
	skill.distance = 0.05
	skill.cooldown = 0.0
	skill.ready_in = 0.0
	var before: Vector3 = bone_sample()
	await wait(0.15)
	var drift: float = before.distance_to(bone_sample())
	before = bone_sample()
	skill.dodge()
	await wait(0.05)  # the tree reads the request on ITS next process, not now
	check(player.animator.dodge_playing(), "the one-shot fires",
			"active %s" % player.animator.dodge_playing())
	var opening: Vector3 = bone_sample()
	await wait(0.1)
	var late: Vector3 = bone_sample()
	var moved: float = before.distance_to(late)
	check(moved > maxf(drift, 0.001) * 4.0,
			"and the roll reaches the skeleton, not just the arms",
			"%.3f of pose against a %.3f idle drift" % [moved, drift])

	# A one-shot fired twice must REPLAY, not resume: the transition cannot
	# reset an input it is already sitting on, so a second roll the same way
	# would otherwise start wherever the last one stopped - a visible hitch.
	# The bar is the pose's own travel across the clip, not a hand-picked number.
	var span: float = opening.distance_to(late)
	await wait(skill.duration())
	skill.ready_in = 0.0
	skill.dodge()
	await wait(0.05)
	var again: Vector3 = bone_sample()
	check(opening.distance_to(again) < span * 0.25,
			"and a second roll the same way starts from the top",
			"%.3f apart at the same beat, against %.3f of travel"
			% [opening.distance_to(again), span])
	await wait(skill.duration())
	skill.distance = reach
	skill.cooldown = cooldown


# --- four intents, four clips, in the rig's own frame (+Z forward, -X right)
func test_the_directions():
	var basis: Basis = movement.visual.global_transform.basis
	var picked: Array[String] = [skill.clip_for(basis.z), skill.clip_for(-basis.z),
			skill.clip_for(-basis.x), skill.clip_for(basis.x)]
	var expected: Array[String] = [CharacterDodge.CLIP_FORWARD,
			CharacterDodge.CLIP_BACKWARD, CharacterDodge.CLIP_RIGHT,
			CharacterDodge.CLIP_LEFT]
	check(picked == expected, "each way round picks its own clip", ", ".join(picked))
	movement.move_direction = Vector3.ZERO
	check(skill.dodge_direction().dot(-basis.z) > 0.99,
			"and standing still it hops backward, away from the aim",
			str(skill.dodge_direction().snappedf(0.01)))


# --- what it costs and how often
func test_the_rations():
	skill.ready_in = 0.0
	energy.set_energy(energy.max_energy)
	var before: float = energy.current
	check(skill.dodge(), "a rested dodger rolls", "%.0f energy" % before)
	check(is_equal_approx(before - energy.current, skill.energy_cost),
			"the roll is paid for in energy",
			"%.0f -> %.0f, cost %.0f" % [before, energy.current, skill.energy_cost])
	await wait(skill.duration())
	check(not skill.can_dodge(), "the next one waits out the cooldown",
			"%.2fs left" % skill.ready_in)
	await wait(skill.cooldown)
	check(skill.can_dodge(), "and is offered again when it expires",
			"%.2fs left" % skill.ready_in)
	energy.set_energy(skill.energy_cost - 1.0)
	check(not skill.can_dodge(), "an empty battery refuses the roll",
			"%.0f energy against a %.0f cost" % [energy.current, skill.energy_cost])
	energy.set_energy(energy.max_energy)


# --- SHARED means shared: the bare component on an enemy, with no player-only
# parts wired, and a death mid-roll that must not hand a corpse its layer back.
func test_the_enemy(p_gym: Node):
	var brain: Node = find_first(p_gym, "EnemyAI")
	if not check(brain != null, "the gym lends an enemy to try it on", str(brain)):
		return
	var enemy: Character = brain.get_parent() as Character
	var borrowed: CharacterDodge = CharacterDodge.new()
	borrowed.movement = enemy.movement
	borrowed.animator = enemy.animator
	borrowed.weapons = enemy.weapons
	enemy.add_child(borrowed)
	await settle(2)
	enemy.movement.move_direction = -enemy.global_transform.basis.z
	check(borrowed.dodge() and borrowed.dodging() and enemy.hurt_box.immune,
			"an enemy handed the bare component dodges too, and for free",
			"window %.2fs, no battery wired" % borrowed.window)
	enemy.take_damage(AttackData.new(9999, enemy.global_position, 0.0, null))
	check(enemy.is_dead and enemy.hurt_box.collision_layer == 0
			and not enemy.hurt_box.immune, "dying mid-roll closes the i-frames at once",
			"layer %d, immune %s" % [enemy.hurt_box.collision_layer,
			enemy.hurt_box.immune])
	await wait(borrowed.duration() + 0.1)
	check(enemy.hurt_box.collision_layer == 0,
			"and the roll's own end never hands a corpse its hurt box back",
			"layer %d after the window" % enemy.hurt_box.collision_layer)


# A hurt-layer ray through the chest, cast exactly as WeaponRanged casts one.
func shot_finds() -> bool:
	var chest: Vector3 = player.global_position + Vector3.UP * 1.1
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			chest + Vector3.RIGHT * 5.0, chest, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# The HIPS, and only the hips: they are the one bone the upper layer's filter
# leaves alone, so nothing but locomotion or a full-body clip can move them -
# and the travel is dialled out while this runs.
func bone_sample() -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	return skeleton.get_bone_global_pose(skeleton.find_bone("hips")).origin


# Physics frames are the only clock that runs at a fixed rate headless.
func wait(p_seconds: float):
	await settle_physics(int(ceilf(p_seconds * 60.0)) + 1)


func settle_physics(p_frames: int):
	for i in p_frames:
		await get_tree().physics_frame


func press(p_action: String):
	Input.action_press(p_action)


func release(p_action: String):
	Input.action_release(p_action)
