extends KinematicBody

export (int) var speed = 4
export (int) var max_health = 100
var health = max_health
onready var player = null

func _ready():
	# assume enemy is added as child of Main alongside Player
	if get_parent() and get_parent().has_node("Player"):
		player = get_parent().get_node("Player")

func _physics_process(_delta):
	if player == null:
		return
	var dir = (player.global_transform.origin - global_transform.origin)
	if dir.length() > 0.1:
		dir = dir.normalized()
		var vel = dir * speed
		move_and_slide(vel, Vector3.UP)

func apply_damage(amount):
	health -= amount
	_spawn_hit_fx()
	if health <= 0:
		queue_free()

func _spawn_hit_fx():
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var flash = MeshInstance.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.10
	sphere.height = 0.20
	flash.mesh = sphere
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(1, 0.45, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.35, 0.1)
	flash.material_override = mat
	flash.translation = global_transform.origin
	current.add_child(flash)
	yield(get_tree().create_timer(0.10), "timeout")
	if is_instance_valid(flash):
		flash.queue_free()
