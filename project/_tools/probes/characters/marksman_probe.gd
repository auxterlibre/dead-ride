extends ProbeBase
# Every enemy arms the weapon its data gives it, and wears its own meshes. The
# arming half is a REGRESSION GUARD: set_weapons once had its equip() commented
# out and every enemy in the game stood there unarmed.

const ENEMIES: Array[String] = ["survivalist", "marksman"]


func _ready():
	for name in ENEMIES:
		var data: CharacterData = load("res://data/enemies/%s.tres" % name)
		var enemy: Character = load("res://scenes/characters/enemy.tscn").instantiate()
		enemy.data = data
		add_child(enemy)
		for i in 6:
			await get_tree().process_frame
		var weapons: CharacterWeapons = null
		var ai: EnemyAI = null
		for child in enemy.get_children():
			if child is CharacterWeapons:
				weapons = child
			if child is EnemyAI:
				ai = child

		check(enemy.current_health == data.max_health,
				"%s spawns on its own health" % name,
				"%d/%d" % [enemy.current_health, data.max_health])
		var body: MeshInstance3D = enemy.find_child("Body", true, false)
		var wearing: String = body.mesh.resource_path if body and body.mesh else "<none>"
		check(wearing.contains("/%s/" % name), "and wears its own meshes", wearing)
		# By NAME, not identity: setup() duplicates each WeaponData so two
		# characters off one .tres cannot share a magazine.
		var wanted: String = data.weapon_inventory[0].name
		check(weapons.current_weapon != null and weapons.current_weapon.name == wanted,
				"and has %s in hand" % wanted,
				weapons.current_weapon.name if weapons.current_weapon else "<UNARMED>")
		check(weapons.weapon_model != null, "with a model in the hand slot",
				str(weapons.weapon_model))
		# Off the WEAPON, not the 2m melee fallback an unarmed enemy drops to.
		var reach: float = ai.attack_range() if ai else 0.0
		check(reach > 2.0, "and engages at weapon range, not melee range",
				"%.1fm" % reach)
		enemy.queue_free()

	# Not a check - the numbers are the author's call, but a marksman that does
	# not out-reach a rifleman is worth saying out loud.
	var sniper: WeaponData = load("res://data/items/weapons/ranged/sniper_rifle.tres")
	var rifle: WeaponData = load("res://data/items/weapons/ranged/assault_rifle.tres")
	print("DBG sniper %d dmg / %.0fm / %.0f deg  vs  rifle %d dmg / %.0fm / %.0f deg"
			% [sniper.damage_value, sniper.effective_range_value,
			sniper.accuracy_cone_value, rifle.damage_value,
			rifle.effective_range_value, rifle.accuracy_cone_value])

	finish()
