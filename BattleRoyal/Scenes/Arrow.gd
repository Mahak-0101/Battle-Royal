extends Area

export (float) var speed = 58.0
export (int) var damage = 30
export (float) var lifetime = 4.0

var direction = Vector3(0, 0, -1)
var age = 0.0
var mesh_instance = null

func _ready():
	monitoring = true
	collision_layer = 2
	collision_mask = 1
	connect("body_entered", self, "_on_body_entered")
	_build_visual()
	_sync_orientation()

func _physics_process(delta):
	if direction.length() > 0.001:
		global_translate(direction.normalized() * speed * delta)
		_sync_orientation()
	age += delta
	if age >= lifetime:
		queue_free()

func _build_visual():
	if has_node("CollisionShape"):
		return
	var shape = CollisionShape.new()
	var capsule = CapsuleShape.new()
	capsule.radius = 0.03
	capsule.height = 0.95
	shape.shape = capsule
	add_child(shape)

	mesh_instance = MeshInstance.new()
	var shaft = CylinderMesh.new()
	shaft.top_radius = 0.014
	shaft.bottom_radius = 0.016
	shaft.height = 0.95
	mesh_instance.mesh = shaft
	var wood = SpatialMaterial.new()
	wood.albedo_color = Color(0.52, 0.32, 0.14)
	wood.roughness = 0.68
	mesh_instance.material_override = wood
	mesh_instance.rotation_degrees = Vector3(90, 0, 0)
	add_child(mesh_instance)

	var tip = MeshInstance.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.03
	cone.height = 0.14
	tip.mesh = cone
	var metal = SpatialMaterial.new()
	metal.albedo_color = Color(0.82, 0.76, 0.62)
	metal.metallic = 0.65
	metal.roughness = 0.22
	tip.material_override = metal
	tip.rotation_degrees = Vector3(90, 0, 0)
	tip.translation = Vector3(0, 0.55, 0)
	add_child(tip)

func _sync_orientation():
	if direction.length() <= 0.001:
		return
	look_at(global_transform.origin + direction.normalized(), Vector3.UP)
	rotate_object_local(Vector3(1, 0, 0), PI / 2)

func _on_body_entered(body):
	if body == null:
		return
	if body.has_method("apply_damage"):
		body.apply_damage(damage)
		_play_hit_sound()
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

func _play_hit_sound():
	var current = get_tree().get_current_scene()
	if current == null or not current.has_node("GameManager"):
		return
	var gm = current.get_node("GameManager")
	if gm and gm.has_method("play_hit_sound"):
		gm.play_hit_sound()