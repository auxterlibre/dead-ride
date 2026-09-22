class_name EnemyAI
extends Node
# The enemy brain: a code-driven StateMachine over the enemy components.

const ENGAGED_STATES:Array[String] = ["chase", "attack", "investigate", "cover"]
const MELEE_RANGE:float = 2.0
const RANGE_FACTOR:float = 0.8  # engage inside this fraction of weapon range
const SHOUT_RANGE:float = 30.0  # m allies hear a called contact from
const COVER_RETRY_TIME:float = 6.0  # sec before hunting for cover again

@export var movement:EnemyMovement
@export var vision:CharacterVision
@export var weapons:EnemyWeapons
@export var aim:EnemyAim
@export var cover:CharacterCover
@export var patrol_route: PatrolRoute  # set = this enemy walks it instead of standing guard
@export var roam: bool = false  # scavenger: drifts between loot containers when idle

var state_machine:StateMachine
var guard_position:Vector3
var guard_facing:Vector3
var quarry:Character  # who this fight is about - Investigate tracks its trail
var cover_blocked_until:float = 0.0
var cover_requested:bool = false  # taking fire; the combat states act on it
var post_captured:bool = false

@onready var character:Character = get_parent()


func _ready():
	capture_guard_post()
	state_machine = StateMachine.new()
	state_machine.actor = self
	add_child(state_machine)
	state_machine.state_changed.connect(func(p_state:String):
			if character.debug_label:
				character.debug_label.text = p_state)
	state_machine.add_state("guard", GuardState.new())
	state_machine.add_state("patrol", PatrolState.new())
	state_machine.add_state("roam", RoamState.new())
	state_machine.add_state("chase", ChaseState.new())
	state_machine.add_state("attack", AttackState.new())
	state_machine.add_state("investigate", InvestigateState.new())
	state_machine.add_state("cover", CoverState.new())
	state_machine.change_state_to(home_state())
	vision.spotted.connect(on_spotted)
	character.damaged.connect(on_damaged)
	Signals.noise_emitted.connect(on_noise)
	Signals.alert_raised.connect(on_alert)
	character.died.connect(func():
			state_machine.process_mode = Node.PROCESS_MODE_DISABLED
			if character.debug_label:
				character.debug_label.text = "dead")
	# The initial "guard" fires before the parent's onready vars exist -
	# stamp the label once everything is ready.
	(func():
		if character.debug_label:
			character.debug_label.text = state_machine.current_state_name).call_deferred()


func _process(_delta):
	if character.debug_label:
		character.debug_label.visible = Globals.debug_labels


func _physics_process(_delta):
	# Spawners add_child() before placing, so the post is re-read on the first physics frame.
	if not post_captured:
		post_captured = true
		capture_guard_post()


# Where this enemy belongs: the spot and facing it returns to when nothing
# else is going on.
func capture_guard_post():
	guard_position = character.global_position
	guard_facing = movement.visual.global_basis.z
	guard_facing.y = 0.0
	guard_facing = guard_facing.normalized()


func on_spotted(p_target):
	# The quarry is always a CHARACTER - spotting an occupied vehicle hunts
	# its driver, so the trail hand-off survives them bailing out.
	var hunted:Character = p_target.driver if p_target is Vehicle else p_target
	if hunted:
		quarry = hunted
	# Re-spots while engaged are handled inside the engaged states.
	if state_machine.current_state_name in ENGAGED_STATES:
		return
	if weapons:
		weapons.begin_engagement()
	if quarry:
		Signals.alert_raised.emit(character, quarry)  # call the contact out
	state_machine.change_state_to("chase",
			{return_state = state_machine.current_state_name})


# Getting hit reveals the attacker; no warning-shot miss is owed.
func on_damaged(p_attack:AttackData):
	if weapons:
		weapons.stagger()
	# The combat states consume this on their own tick - never change state in a damage signal.
	cover_requested = true
	var origin:Vector3 = p_attack.attacker.global_position \
			if p_attack.attacker is Character else p_attack.knockback_origin
	vision.alertness = 1.0
	if p_attack.attacker is Character:
		quarry = p_attack.attacker
	if vision.target:
		return  # already sees a target; the fight is on
	if state_machine.current_state_name == "chase":
		state_machine.states["chase"].redirect(origin)
		return
	if state_machine.current_state_name in ENGAGED_STATES:
		return  # attack with no vision target hands itself to chase
	if p_attack.attacker is Character:
		Signals.alert_raised.emit(character, p_attack.attacker)
	state_machine.change_state_to("chase",
			{return_state = state_machine.current_state_name, last_seen = origin})


# An idle enemy investigates; a blind searcher re-points. Sight always outranks sound.
func on_noise(p_position:Vector3, p_range:float, p_source:Node3D):
	if character.is_dead:
		return
	if character.global_position.distance_to(p_position) > p_range:
		return
	if p_source is Character:
		if not character.is_hostile_to(p_source):
			return  # own or allied gunfire
		quarry = p_source
	vision.alertness = 1.0
	if vision.target:
		return  # already watching someone; the fight has priority
	match state_machine.current_state_name:
		"chase":
			state_machine.states["chase"].redirect(p_position)
		"investigate":
			state_machine.states["investigate"].redirect(p_position)
		"attack":
			pass  # transient: with no vision target it hands itself to chase
		_:
			state_machine.change_state_to("investigate",
					{return_state = resumable_state(), origin = p_position})


# An ally called out a contact: join the hunt if the shout was in earshot.
func on_alert(p_source:Character, p_quarry:Character):
	if character.is_dead or p_source == character:
		return
	if character.is_hostile_to(p_source) or not character.is_hostile_to(p_quarry):
		return  # not our side's shout, or not about our enemy
	if character.global_position.distance_to(p_source.global_position) > SHOUT_RANGE:
		return
	vision.alertness = 1.0
	if vision.target:
		return
	quarry = p_quarry
	match state_machine.current_state_name:
		"chase":
			state_machine.states["chase"].redirect(p_quarry.global_position)
		"investigate":
			state_machine.states["investigate"].redirect(p_quarry.global_position)
		"attack":
			pass
		_:
			state_machine.change_state_to("chase",
					{return_state = resumable_state(),
					last_seen = p_quarry.global_position})


# The idle this enemy belongs in when nothing is going on.
func home_state() -> String:
	if roam:
		return "roam"
	if patrol_route:
		return "patrol"
	return "guard"


# What an interrupted enemy goes back to. Cover is TACTICAL, not a task: its
# spot was chosen for a threat position that is stale by the time anything
# resumes, and re-entering needs a spot no resume has.
func resumable_state() -> String:
	if state_machine.current_state_name == "cover":
		return home_state()
	return state_machine.current_state_name


# A burst of raycasts, so a failure parks it for COVER_RETRY_TIME.
func try_cover(p_return_state:String, p_threat:Vector3) -> bool:
	if cover == null or now() < cover_blocked_until:
		return false
	var found:Dictionary = cover.find(p_threat)
	if found.is_empty():
		block_cover()
		return false
	state_machine.change_state_to("cover", {return_state = p_return_state,
			spot = found.spot, peek = found.peek})
	return true


func consume_cover_request() -> bool:
	var requested:bool = cover_requested
	cover_requested = false
	return requested


func block_cover():
	cover_blocked_until = now() + COVER_RETRY_TIME


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


# How close this enemy wants to be before opening fire.
func attack_range() -> float:
	var weapon:WeaponData = weapons.current_weapon if weapons else null
	if weapon and weapon.is_ranged:
		return weapon.effective_range_value * RANGE_FACTOR
	return MELEE_RANGE
