extends ProbeBase
# Windowed only - headless renders blank. A lineup of the humanoid base: dressed
# and at rest, mid-stride on the running blend, and aiming a pistol from the
# prop bone, each saved to user:// for a look.

const OUTFITS: PackedStringArray = ["res://data/outfits/survivor_a.tres",
		"res://data/outfits/policeman.tres"]


func _ready():
	if not windowed("the humanoid lineup"):
		finish()
		return
	var stage: Node3D = Node3D.new()
	add_child(stage)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.17, 0.19)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(12.0, 12.0)
	stage.add_child(floor_mesh)
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.6, 4.2), Vector3(0.0, 0.95, 0.0))
	camera.current = true

	var bodies: Array = []
	for i in OUTFITS.size():
		var body: Character = (load("res://scenes/characters/humanoid_base.tscn") as PackedScene).instantiate()
		var data: CharacterData = CharacterData.new()
		data.body_path = OUTFITS[i]
		data.weapon_inventory = [load("res://data/items/weapons/ranged/pistol.tres")]
		body.data = data
		var movement: CharacterMovement = CharacterMovement.new()
		movement.name = "CharacterMovement"
		movement.visual = body.get_node("BodyContainer")
		body.add_child(movement)
		var animator: CharacterAnimator = body.get_node("CharacterAnimator")
		animator.movement = movement
		var weapons: EnemyWeapons = EnemyWeapons.new()
		weapons.name = "EnemyWeapons"
		weapons.animator = animator
		weapons.hand_slot = body.get_node("%HandSlotRight")
		body.add_child(weapons)
		stage.add_child(body)
		movement.enabled = false
		body.position = Vector3(-0.9 + i * 1.8, 0.0, 0.0)
		bodies.append(body)
	await settle(20)
	for body in bodies:
		body.get_node("CharacterAnimator").set_physics_process(false)
		body.weapons.holster()
	await settle(10)
	var rest: Image = await capture()
	save_shot(rest, "humanoid_rest")

	for body in bodies:
		var tree: AnimationTree = body.get_node("BodyContainer/AnimationTree")
		tree.set(CharacterAnimator.PACE_PARAM, 1.0)
		tree.set(CharacterAnimator.TORSO_PACE_PARAM, 1.0)
	await settle(14)
	save_shot(await capture(), "humanoid_running")

	for body in bodies:
		var tree: AnimationTree = body.get_node("BodyContainer/AnimationTree")
		tree.set(CharacterAnimator.PACE_PARAM, 0.0)
		tree.set(CharacterAnimator.TORSO_PACE_PARAM, 0.0)
		body.weapons.equip(0)
	await settle(30)
	var aiming: Image = await capture()
	save_shot(aiming, "humanoid_aiming")
	check(changed_mean(rest, aiming).a >= 0.0, "the lineup rendered",
			"three shots under user://")
	finish()
