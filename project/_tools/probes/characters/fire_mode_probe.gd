extends ProbeBase
# MANUAL weapons cycle their action between shots: fire, wait out the cock,
# hear the eject partway - and the states that skip it skip it on purpose.

const EXPECTED_CHECKS: int = 17

var weapons: CharacterWeapons


func _ready():
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	await physics_frames(3)
	var mannequin: Character = gym.get_node("Player")
	for child in mannequin.get_children():
		if child is CharacterWeapons:
			weapons = child
	check(weapons != null, "the mannequin has weapons", str(weapons))
	# The pack arms the component a few frames in; wait for it, not a guess.
	var patience: int = 120
	while weapons.inventory.is_empty() and patience > 0:
		await get_tree().physics_frame
		patience -= 1
	check(not weapons.inventory.is_empty(), "and the pack armed it",
			str(weapons.inventory.map(func(w): return w.name)))

	# The probe ARMS ITSELF from here: the kit in player.tres is the
	# designer's to rearrange - it has already lost this probe its sniper
	# once - and the subject is the fire CYCLE, not the loadout. A probe
	# must rely on nothing the designer can change.
	var sniper: WeaponData = (load("res://data/items/weapons/ranged/sniper_rifle.tres") \
			as WeaponData).duplicate()
	var smg_dup: WeaponData = (load("res://data/items/weapons/ranged/smg.tres") \
			as WeaponData).duplicate()
	weapons.set_weapons([sniper, smg_dup], 0)
	check(sniper.fire_mode == Enums.FireMode.MANUAL, "the sniper rifle is manual",
			str(sniper.fire_mode))
	check((weapons.weapon_model as WeaponRanged).audio_eject != null,
			"and its model carries an eject sound", "AudioEject")

	check(weapons.can_fire(), "ready before the first shot", "")
	fire()
	check(weapons.needs_cocking and not weapons.can_fire(),
			"fired: the action wants cycling", "cock %.1fs" % sniper.cock_time)
	await seconds(sniper.cock_time * EJECT_SHARE() + 0.2)
	check(weapons.eject_played
			and (weapons.weapon_model as WeaponRanged).audio_eject.playing,
			"the case flies partway through", "")
	check(upper_state() == "ranged_2h_reload",
			"and the bolt work is visible - the reload clip, scaled",
			upper_state())
	await seconds(sniper.cock_time)
	check(not weapons.needs_cocking and weapons.can_fire(),
			"cycled: ready again", "")
	check(upper_state() == "ranged_2h_aiming", "back in the hold pose",
			upper_state())

	# A reload works the action itself - no separate cock owed after it.
	fire()
	weapons.reload()
	check(weapons.is_reloading and not weapons.needs_cocking,
			"a reload absorbs the pending cock", "")
	weapons.cancel_reload()

	# The last round leaves nothing to chamber; the cock waits for the reload.
	weapons.current_weapon.current_ammo = 1
	weapons.fire_cooldown = 0.0
	weapons.needs_cocking = false
	fire()
	check(not weapons.needs_cocking, "an emptied magazine skips the cock", "")

	weapons.equip(1)
	check(weapons.current_weapon == smg_dup, "the automatic takes the hand",
			weapons.current_weapon.name)
	weapons.fire_cooldown = 0.0
	fire()
	check(not weapons.needs_cocking and weapons.current_weapon.current_ammo > 0,
			"a non-manual weapon never cocks", weapons.current_weapon.name)

	# The SMG completes the GDD weapon table: a light-fed automatic that
	# handles faster than the assault rifle and runs the shared fire cycle.
	var smg: WeaponData = load("res://data/items/weapons/ranged/smg.tres")
	check(smg.fire_mode == Enums.FireMode.AUTOMATIC \
			and smg.ammo_type == Enums.AmmoType.LIGHT,
			"the SMG is a light-fed automatic",
			"mode %d, ammo %d" % [smg.fire_mode, smg.ammo_type])
	var rifle_data: WeaponData = load("res://data/items/weapons/ranged/assault_rifle.tres")
	check(smg.fire_rate_value > rifle_data.fire_rate_value \
			and smg.reload_time_value < rifle_data.reload_time_value \
			and smg.damage_value < rifle_data.damage_value,
			"faster and lighter than the assault rifle",
			"%.0f/s %.1fs %.0fdmg vs %.0f/s %.1fs %.0fdmg" % [
			smg.fire_rate_value, smg.reload_time_value, smg.damage_value,
			rifle_data.fire_rate_value, rifle_data.reload_time_value,
			rifle_data.damage_value])
	weapons.set_weapons([smg.duplicate()])
	weapons.current_weapon.current_ammo = 5
	weapons.fire_cooldown = 0.0
	fire()
	check(not weapons.needs_cocking and weapons.current_weapon.current_ammo == 4 \
			and weapons.weapon_model is WeaponRanged,
			"and it fires clean through the shared cycle",
			"%d rounds left" % weapons.current_weapon.current_ammo)

	print("DBG %d passed, %d failed, %d of %d checks ran" % [
			passed, failed, passed + failed, EXPECTED_CHECKS])
	get_tree().quit()


func fire():
	var from: Vector3 = weapons.body.global_position + Vector3.UP
	weapons.fire_shot(from, from + Vector3.FORWARD * 10.0)


func EJECT_SHARE() -> float:
	return CharacterWeapons.EJECT_SHARE


func upper_state() -> String:
	return weapons.animator.animation_tree.get("parameters/upper_state/current_state")


func physics_frames(p_count: int):
	for i in p_count:
		await get_tree().physics_frame


func seconds(p_span: float):
	await physics_frames(int(p_span * 60.0))
