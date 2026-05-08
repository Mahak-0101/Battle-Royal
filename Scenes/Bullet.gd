extends Area

export (float) var speed = 40.0
export (int) var damage = 34
var direction = Vector3()

func _ready():
	set_deferred("monitoring", true)
	connect("body_entered", self, "_on_body_entered")

func _physics_process(delta):
	translate(direction * speed * delta)
	if global_transform.origin.y < -50:
		queue_free()

func _on_body_entered(body):
	if body == null:
		return
	if body.has_method("apply_damage"):
		body.apply_damage(damage)
	_spawn_impact_vfx()
	queue_free()

func _spawn_impact_vfx():
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var flash = MeshInstance.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	flash.mesh = sphere
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(1, 0.7, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.5, 0.1)
	flash.material_override = mat
	flash.translation = global_transform.origin
	current.add_child(flash)
	yield(get_tree().create_timer(0.12), "timeout")
	if is_instance_valid(flash):
		flash.queue_free()
