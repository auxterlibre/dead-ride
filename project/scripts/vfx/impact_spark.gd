class_name ImpactSpark
extends MeshInstance3D
# One-shot unshaded flash that expands and fades at the point of impact.
# Ported from Melee Arena.

const LIFETIME:float = 0.15


static func spawn(p_parent:Node, p_position:Vector3, p_color:Color, p_size:float = 0.5) -> void:
	var spark := ImpactSpark.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = p_color
	spark.mesh = sphere
	spark.material_override = material
	p_parent.add_child(spark)
	spark.global_position = p_position
	spark.scale = Vector3.ONE * 0.15
	var tween := spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector3.ONE * p_size, LIFETIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, LIFETIME)
	tween.chain().tween_callback(spark.queue_free)
