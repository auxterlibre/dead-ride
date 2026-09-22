class_name SandDrift
extends GPUParticles3D

@export var lull_density: float = 0.4  # share of `amount` still alive between gusts
@export var speed_spread: float = 0.5  # +/- share of the wind speed a grain takes

var grains: ParticleProcessMaterial
var ground_offset: float = 0.0  # half the slab's height: stands its floor on the surface


func _ready():
	grains = process_material as ParticleProcessMaterial
	if grains:
		ground_offset = grains.emission_box_extents.y


func _process(_delta):
	var wind: Wind = Globals.wind
	var view: Node3D = Globals.camera_follow
	if grains == null or wind == null or view == null:
		emitting = false  # unwired (the gym, a probe scene) = inert
		return
	emitting = true
	# Rides the view; the slab is flat, so it must climb terraces or grains blow through the hillside.
	global_position = view.global_position + Vector3.UP * ground_offset
	# The node is never rotated, so the material's local direction IS world.
	grains.direction = wind.direction
	grains.initial_velocity_min = wind.strength * (1.0 - speed_spread)
	grains.initial_velocity_max = wind.strength * (1.0 + speed_spread)
	# A gust is felt as DENSITY as much as speed - a lull thins the field out
	# rather than merely slowing it, so the ground clears between them.
	amount_ratio = lerpf(lull_density, 1.0, wind.gust)
