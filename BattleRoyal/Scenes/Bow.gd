extends "res://Scenes/Weapon.gd"

var visual_root = null
var right_limb = null
var left_limb = null
var grip = null
var string_line = null
var quiver = null

func _ready():
	fire_rate = 0.18
	damage = 30
	bullet_scene = preload("res://Scenes/Arrow.tscn")
	fire_range = 1000.0
	_build_visual()
	set_attachment_state("back")

func _build_visual():
	if visual_root:
		return
	visual_root = Spatial.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	var wood_material = SpatialMaterial.new()
	wood_material.albedo_color = Color(0.36, 0.22, 0.10)
	wood_material.roughness = 0.82

	var gold_material = SpatialMaterial.new()
	gold_material.albedo_color = Color(0.75, 0.58, 0.23)
	gold_material.metallic = 0.62

	gold_material.roughness = 0.30


	var string_material = SpatialMaterial.new()
	string_material.albedo_color = Color(0.94, 0.90, 0.82)
	string_material.emission_enabled = true
	string_material.emission = Color(0.12, 0.08, 0.04)

	grip = MeshInstance.new()
	var grip_mesh = CylinderMesh.new()
	grip_mesh.top_radius = 0.04
	grip_mesh.bottom_radius = 0.045

	grip_mesh.height = 0.28
	grip.mesh = grip_mesh

	grip.material_override = gold_material
	grip.rotation_degrees = Vector3(0, 0, 90)
	visual_root.add_child(grip)

	left_limb = MeshInstance.new()
	left_limb.name = "LeftLimb"
	var left_mesh = CylinderMesh.new()
	left_mesh.top_radius = 0.018
	left_mesh.bottom_radius = 0.024
	left_mesh.height = 0.95
	left_limb.mesh = left_mesh
	left_limb.material_override = wood_material
	left_limb.rotation_degrees = Vector3(0, 0, 105)
	left_limb.translation = Vector3(0, 0.56, 0)
	visual_root.add_child(left_limb)

	right_limb = MeshInstance.new()
	right_limb.name = "RightLimb"
	var right_mesh = CylinderMesh.new()
	right_mesh.top_radius = 0.018
	right_mesh.bottom_radius = 0.024
	right_mesh.height = 0.95
	right_limb.mesh = right_mesh
	right_limb.material_override = wood_material
	right_limb.rotation_degrees = Vector3(0, 0, 75)
	right_limb.translation = Vector3(0, -0.56, 0)
	visual_root.add_child(right_limb)

	string_line = MeshInstance.new()
	string_line.name = "String"
	var string_mesh = CylinderMesh.new()

	string_mesh.top_radius = 0.004
	string_mesh.bottom_radius = 0.004
	string_mesh.height = 1.22
	string_line.mesh = string_mesh
	string_line.material_override = string_material
	string_line.rotation_degrees = Vector3(0, 90, 0)
	visual_root.add_child(string_line)

	quiver = Spatial.new()
	quiver.name = "Quiver"
	quiver.translation = Vector3(-0.08, 0.0, -0.16)
	visual_root.add_child(quiver)
	for i in range(3):
		var arrow = MeshInstance.new()
		var arrow_mesh = CylinderMesh.new()
		arrow_mesh.top_radius = 0.008
		arrow_mesh.bottom_radius = 0.012
		arrow_mesh.height = 0.60
		arrow.mesh = arrow_mesh
		arrow.material_override = wood_material
		arrow.rotation_degrees = Vector3(6.0 * i, 0, 90)
		arrow.translation = Vector3(0.02 * i, 0.03 * i, 0.03 * i)
		quiver.add_child(arrow)

func set_attachment_state(state):
	if state == "hand":
		translation = Vector3(0.04, -0.04, 0.08)
		rotation_degrees = Vector3(0, -92, 88)
	elif state == "back":
		translation = Vector3(-0.08, 0.11, -0.12)
		rotation_degrees = Vector3(12, 90, 188)
	else:
		translation = Vector3.ZERO
		rotation_degrees = Vector3.ZERO
