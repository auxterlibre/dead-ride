extends ProbeBase
# DBG probe: the reticle swaps its weapon shape on weapon_setup - one child
# per class, empty hands (and classless melee) showing none. Doubles as an
# audit that every ranged .tres carries its right weapon_class.


func _ready():
	var reticle: Reticle = (load("res://scenes/ui/reticles/reticle.tscn")
			as PackedScene).instantiate()
	add_child(reticle)
	var cases: Array = [
		["res://data/items/weapons/ranged/pistol.tres", "Pistol"],
		["res://data/items/weapons/ranged/revolver.tres", "Revolver"],
		["res://data/items/weapons/ranged/shotgun.tres", "Shotgun"],
		["res://data/items/weapons/ranged/assault_rifle.tres", "AssaultRifle"],
		["res://data/items/weapons/ranged/smg.tres", "SMG"],
		["res://data/items/weapons/ranged/sniper_rifle.tres", "SniperRifle"],
	]
	for case in cases:
		Signals.weapon_setup.emit(load(case[0]))
		check(sole_visible(reticle) == case[1],
				"%s draws its own shape" % str(case[1]).to_snake_case(),
				"visible: '%s'" % sole_visible(reticle))
	Signals.weapon_setup.emit(null)
	check(sole_visible(reticle) == "Unarmed", "empty hands show the bare dot",
			"visible: '%s'" % sole_visible(reticle))
	var melee: WeaponData = WeaponData.new()
	melee.weapon_class = Enums.WeaponClass.MELEE
	Signals.weapon_setup.emit(melee)
	check(sole_visible(reticle) == "Unarmed",
			"a class with no shape yet falls back to the dot",
			"visible: '%s'" % sole_visible(reticle))
	finish()


# The one visible shape (class children + the Unarmed dot), "" for none,
# MANY if several leak through.
func sole_visible(p_reticle: Reticle) -> String:
	var seen: Array = []
	for weapon_class in p_reticle.by_class:
		if p_reticle.by_class[weapon_class].visible:
			seen.append(str(p_reticle.by_class[weapon_class].name))
	if p_reticle.unarmed.visible:
		seen.append("Unarmed")
	if seen.is_empty():
		return ""
	if seen.size() == 1:
		return seen[0]
	return "MANY " + str(seen)
