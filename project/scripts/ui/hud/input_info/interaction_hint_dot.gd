class_name InteractionHintDot
extends Control

const APPEAR_TIME: float = 0.24  # sec - the pop in
const VANISH_TIME: float = 0.12  # sec - snappier going than coming
const RING_TIME: float = 0.18
const RING_SPREAD: float = 2.0  # how wide the ring opens before closing in

@onready var ring: TextureRect = %Ring
@onready var solid: TextureRect = %Solid
@onready var hollow: TextureRect = %Hollow

var active: bool = false
var spent: bool = false
var leaving: bool = false
var pop: Tween
var ring_pop: Tween


func _ready():
	hollow.visible = false
	ring.visible = false
	ring.modulate.a = 0.0
	appear()


# Scale rides the ROOT, whose size never changes: the hints layer positions the
# dot off `size` every frame, so scaling a sized rect would drag it off its
# anchor. The overshoot is the whole look - it lands harder than it travels.
func appear():
	leaving = false
	pop = retake(pop)
	scale = Vector2.ZERO
	modulate.a = 0.0
	pop.tween_property(self, "scale", Vector2.ONE, APPEAR_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(self, "modulate:a", 1.0, APPEAR_TIME * 0.4)


# Frees ITSELF at the end, which is why the layer hands the dot over instead of
# queue_free-ing it: an exit animation needs the node to outlive its offer.
func vanish():
	if leaving:
		return
	leaving = true
	pop = retake(pop)
	pop.tween_property(self, "scale", Vector2.ZERO, VANISH_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	pop.parallel().tween_property(self, "modulate:a", 0.0, VANISH_TIME)
	pop.tween_callback(queue_free)


# Called EVERY FRAME by the hints layer, so it acts on the CHANGE alone: a
# tween restarted sixty times a second never leaves its first frame.
# active = in reach, spent = the offer has already been taken.
func show_state(p_active: bool, p_spent: bool):
	if p_spent != spent:
		spent = p_spent
		solid.visible = not spent
		hollow.visible = spent
	if p_active == active:
		return
	active = p_active
	ring_pop = retake(ring_pop)
	if active:
		# It opens wide and closes onto the dot - the pop, run backwards. The
		# flag flips NOW and the fade owns the rest, so a caller reading it on
		# the same frame reads the state it just asked for.
		ring.visible = true
		ring.scale = Vector2.ONE * RING_SPREAD
		ring_pop.tween_property(ring, "scale", Vector2.ONE, RING_TIME) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ring_pop.parallel().tween_property(ring, "modulate:a", 1.0, RING_TIME)
	else:
		ring_pop.tween_property(ring, "scale", Vector2.ONE * RING_SPREAD,
				RING_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		ring_pop.parallel().tween_property(ring, "modulate:a", 0.0, RING_TIME)
		ring_pop.tween_callback(func(): ring.visible = false)


# One tween per property, or a dot that turned around mid-animation would have
# two of them fighting over the same scale.
func retake(p_tween: Tween) -> Tween:
	if p_tween and p_tween.is_valid():
		p_tween.kill()
	return create_tween()
