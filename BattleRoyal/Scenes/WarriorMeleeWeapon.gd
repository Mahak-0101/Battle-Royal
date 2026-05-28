extends "res://Scenes/Weapon.gd"

export (String) var weapon_name = "Hero Blade" setget set_weapon_name

var visual_root = null

func _ready():
	fire_rate = 0.6
	damage = 36
	fire_range = 3.0
	_rebuild_visual()
	set_attachment_state("hand")

func set_weapon_name(value):
	weapon_name = str(value)
	if is_inside_tree():
		_rebuild_visual()

func _rebuild_visual():
	if visual_root and is_instance_valid(visual_root):
		visual_root.queue_free()
	visual_root = Spatial.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	if weapon_name.find("Gada") >= 0 or weapon_name.find("Vajra") >= 0:
		_build_gada()
	elif weapon_name.find("Chakra") >= 0 or weapon_name.find("Sudarshan") >= 0:
		_build_chakra()
	else:
		_build_sword()

func _build_sword():
	var steel = _make_material(Color(0.66, 0.68, 0.66), 0.68, 0.22)
	var gold = _make_material(Color(0.80, 0.58, 0.20), 0.58, 0.30)
	var leather = _make_material(Color(0.24, 0.12, 0.06), 0.05, 0.70)

	var blade = MeshInstance.new()
	var blade_mesh = CubeMesh.new()
	blade_mesh.size = Vector3(0.08, 1.22, 0.035)
	blade.mesh = blade_mesh
	blade.translation = Vector3(0, 0.46, 0)
	blade.material_override = steel
	visual_root.add_child(blade)

	var tip = MeshInstance.new()
	var tip_mesh = CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.065
	tip_mesh.height = 0.18
	tip.mesh = tip_mesh
	tip.rotation_degrees = Vector3(0, 0, 180)
	tip.translation = Vector3(0, 1.15, 0)
	tip.material_override = steel
	visual_root.add_child(tip)

	_add_cylinder("Guard", Vector3(0, -0.16, 0), Vector3(0, 0, 90), 0.035, 0.48, gold)
	_add_cylinder("Grip", Vector3(0, -0.38, 0), Vector3(0, 0, 0), 0.045, 0.34, leather)
	_add_sphere("Pommel", Vector3(0, -0.60, 0), Vector3(0.09, 0.09, 0.09), gold)

func _build_gada():
	var steel = _make_material(Color(0.48, 0.46, 0.40), 0.65, 0.28)
	var gold = _make_material(Color(0.82, 0.62, 0.24), 0.50, 0.32)
	var leather = _make_material(Color(0.24, 0.12, 0.06), 0.04, 0.74)

	_add_cylinder("Handle", Vector3(0, -0.02, 0), Vector3(0, 0, 0), 0.052, 1.10, leather)
	_add_sphere("MaceHead", Vector3(0, 0.70, 0), Vector3(0.28, 0.28, 0.28), steel)
	for i in range(8):
		var angle = float(i) / 8.0 * TAU
		_add_spike(Vector3(cos(angle) * 0.24, 0.70, sin(angle) * 0.24), angle, gold)
	_add_sphere("Pommel", Vector3(0, -0.62, 0), Vector3(0.095, 0.095, 0.095), gold)

func _build_chakra():
	var gold = _make_material(Color(0.92, 0.70, 0.22), 0.72, 0.20)
	var core = _make_material(Color(0.98, 0.85, 0.42), 0.65, 0.18)
	var ring = MeshInstance.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.44
	torus.ring_segments = 48
	ring.mesh = torus
	ring.rotation_degrees = Vector3(0, 90, 0)
	ring.material_override = gold
	visual_root.add_child(ring)
	_add_sphere("Core", Vector3.ZERO, Vector3(0.10, 0.10, 0.10), core)
	for i in range(12):
		var shard = MeshInstance.new()
		var mesh = CubeMesh.new()
		mesh.size = Vector3(0.035, 0.16, 0.020)
		shard.mesh = mesh
		var angle = float(i) / 12.0 * TAU
		shard.translation = Vector3(cos(angle) * 0.46, sin(angle) * 0.46, 0)
		shard.rotation_degrees.z = rad2deg(angle)
		shard.material_override = gold
		visual_root.add_child(shard)

func _add_cylinder(name, pos, rot, radius, height, material):
	var item = MeshInstance.new()
	item.name = name
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	item.mesh = mesh
	item.translation = pos
	item.rotation_degrees = rot
	item.material_override = material
	visual_root.add_child(item)

func _add_sphere(name, pos, scale_amount, material):
	var item = MeshInstance.new()
	item.name = name
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	item.mesh = mesh
	item.translation = pos
	item.scale = scale_amount
	item.material_override = material
	visual_root.add_child(item)

func _add_spike(pos, angle, material):
	var item = MeshInstance.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.040
	mesh.height = 0.22
	item.mesh = mesh
	item.translation = pos
	item.rotation_degrees = Vector3(90, 0, rad2deg(angle))
	item.material_override = material
	visual_root.add_child(item)

func _make_material(albedo, metallic, roughness):
	var mat = SpatialMaterial.new()
	mat.albedo_color = albedo
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func set_attachment_state(state):
	if state == "hand":
		translation = Vector3(0.06, -0.05, 0.08)
		rotation_degrees = Vector3(0, -8, 8)
	elif state == "back":
		translation = Vector3(-0.09, 0.10, -0.14)
		rotation_degrees = Vector3(10, 20, 148)
	else:
		translation = Vector3.ZERO
		rotation_degrees = Vector3.ZERO
