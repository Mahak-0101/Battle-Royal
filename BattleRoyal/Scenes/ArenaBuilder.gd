extends Spatial

export (int) var arena_seed = 1337
export (bool) var low_spec_mode = true
export (float) var arena_radius = 48.0
export (int) var terrain_resolution = 24
export (int) var tree_count = 8
export (int) var rock_count = 22
export (int) var grass_count = 0
export (bool) var enable_grass = false
export (bool) var enable_particles = false
export (bool) var enable_dynamic_lights = false
export (bool) var enable_ruins = true

var rng = RandomNumberGenerator.new()
var terrain_mat = null
var stone_mat = null
var bark_mat = null
var leaf_mat = null
var grass_mat = null
var bronze_mat = null
var torch_lights = []
var time = 0.0

func _ready():
	rng.seed = arena_seed
	_apply_low_spec_settings()
	_prepare_scene()
	_create_materials()
	_build_terrain()
	if enable_grass and grass_count > 0:
		_build_grass()
	if rock_count > 0:
		_build_rocks()
	if tree_count > 0:
		_build_trees()
	if enable_ruins:
		_build_ruins()
	_build_torches()
	if enable_particles:
		_build_atmosphere()

func _process(delta):
	if not enable_dynamic_lights:
		return
	time += delta
	for i in range(torch_lights.size()):
		var light = torch_lights[i]
		if light and is_instance_valid(light):
			var pulse = sin(time * (3.4 + i * 0.13) + i * 1.7) * 0.18
			light.light_energy = 2.0 + pulse + rng.randf_range(-0.025, 0.025)

func _apply_low_spec_settings():
	if not low_spec_mode:
		return
	arena_radius = min(arena_radius, 48.0)
	terrain_resolution = clamp(terrain_resolution, 12, 24)
	tree_count = min(tree_count, 8)
	rock_count = min(rock_count, 22)
	grass_count = 0
	enable_grass = false
	enable_particles = false
	enable_dynamic_lights = false

func _prepare_scene():
	if get_parent() and get_parent().has_node("Ground"):
		var ground = get_parent().get_node("Ground")
		if ground is MeshInstance:
			ground.visible = false

func _create_materials():
	terrain_mat = SpatialMaterial.new()
	terrain_mat.albedo_color = Color(0.22, 0.26, 0.18)
	if not low_spec_mode:
		terrain_mat.albedo_texture = _make_noise_texture(Color(0.18, 0.20, 0.13), Color(0.40, 0.34, 0.22), 128, 0.34)
	terrain_mat.roughness = 0.96

	stone_mat = SpatialMaterial.new()
	stone_mat.albedo_color = Color(0.34, 0.32, 0.28)
	if not low_spec_mode:
		stone_mat.albedo_texture = _make_noise_texture(Color(0.18, 0.17, 0.15), Color(0.52, 0.50, 0.44), 96, 0.42)
	stone_mat.roughness = 0.92

	bark_mat = SpatialMaterial.new()
	bark_mat.albedo_color = Color(0.25, 0.16, 0.09)
	if not low_spec_mode:
		bark_mat.albedo_texture = _make_noise_texture(Color(0.15, 0.08, 0.04), Color(0.42, 0.25, 0.13), 64, 0.50)
	bark_mat.roughness = 0.88

	leaf_mat = SpatialMaterial.new()
	leaf_mat.albedo_color = Color(0.13, 0.25, 0.13)
	leaf_mat.roughness = 0.78

	grass_mat = SpatialMaterial.new()
	grass_mat.albedo_color = Color(0.18, 0.32, 0.14)
	grass_mat.roughness = 0.92

	bronze_mat = SpatialMaterial.new()
	bronze_mat.albedo_color = Color(0.70, 0.45, 0.17)
	bronze_mat.metallic = 0.52
	bronze_mat.roughness = 0.34

func _make_noise_texture(low_color, high_color, size, contrast):
	var img = Image.new()
	img.create(size, size, false, Image.FORMAT_RGBA8)
	img.lock()
	for x in range(size):
		for y in range(size):
			var n = _hash_noise(x, y)
			var layered = n * 0.55 + _hash_noise(x * 3 + 17, y * 3 + 29) * 0.32 + _hash_noise(x * 9 + 4, y * 9 + 11) * 0.13
			layered = clamp((layered - 0.5) * (1.0 + contrast) + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, low_color.linear_interpolate(high_color, layered))
	img.unlock()
	var tex = ImageTexture.new()
	tex.create_from_image(img, 0)
	return tex

func _hash_noise(x, y):
	var v = sin(float(x) * 12.9898 + float(y) * 78.233 + float(arena_seed) * 0.3719) * 43758.5453
	return v - floor(v)

func _build_terrain():
	var mesh = ArrayMesh.new()
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	var uvs = PoolVector2Array()
	var indices = PoolIntArray()
	var size = arena_radius * 2.0
	var step = size / float(terrain_resolution)

	for z in range(terrain_resolution + 1):
		for x in range(terrain_resolution + 1):
			var wx = -arena_radius + float(x) * step
			var wz = -arena_radius + float(z) * step
			var dist = Vector2(wx, wz).length() / arena_radius
			var height = _terrain_height(wx, wz) * clamp(dist * 1.7, 0.15, 1.0)
			vertices.append(Vector3(wx, height, wz))
			normals.append(Vector3.UP)
			uvs.append(Vector2(float(x) / 8.0, float(z) / 8.0))

	for z in range(terrain_resolution):
		for x in range(terrain_resolution):
			var a = z * (terrain_resolution + 1) + x
			var b = a + 1
			var c = a + terrain_resolution + 1
			var d = c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var terrain = MeshInstance.new()
	terrain.name = "HighDetailTerrain"
	terrain.mesh = mesh
	terrain.material_override = terrain_mat
	add_child(terrain)

	var ring = MeshInstance.new()
	ring.name = "ArenaBoundaryStones"
	var torus = TorusMesh.new()
	torus.inner_radius = arena_radius - 1.2
	torus.outer_radius = arena_radius + 0.4
	torus.ring_segments = 48 if low_spec_mode else 160
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.translation.y = 0.08
	ring.material_override = stone_mat
	add_child(ring)

func _terrain_height(x, z):
	var broad = sin(x * 0.055 + arena_seed) * 0.34 + cos(z * 0.048 - arena_seed) * 0.28
	var detail = sin((x + z) * 0.18) * 0.08 + cos((x - z) * 0.21) * 0.06
	var center_flatten = clamp(Vector2(x, z).length() / 24.0, 0.0, 1.0)
	return (broad + detail) * center_flatten

func _build_grass():
	var blade_mesh = QuadMesh.new()
	blade_mesh.size = Vector2(0.22, 0.72)
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade_mesh
	multimesh.instance_count = grass_count

	for i in range(grass_count):
		var pos = _random_ring_position(8.0, arena_radius - 4.0)
		pos.y = _terrain_height(pos.x, pos.z) + 0.36
		var angle = rng.randf_range(0.0, TAU)
		var basis = Basis(Vector3.UP, angle)
		basis = basis.scaled(Vector3(rng.randf_range(0.75, 1.45), rng.randf_range(0.62, 1.35), 1.0))
		multimesh.set_instance_transform(i, Transform(basis, pos))

	var grass = MultiMeshInstance.new()
	grass.name = "WindGrass"
	grass.multimesh = multimesh
	grass.material_override = grass_mat
	add_child(grass)

func _build_rocks():
	var rock_mesh = SphereMesh.new()
	rock_mesh.radial_segments = 6 if low_spec_mode else 10
	rock_mesh.rings = 3 if low_spec_mode else 5
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = rock_mesh
	multimesh.instance_count = rock_count

	for i in range(rock_count):
		var pos = _random_ring_position(10.0, arena_radius - 6.0)
		pos.y = _terrain_height(pos.x, pos.z) + 0.18
		var scale = Vector3(rng.randf_range(0.45, 1.75), rng.randf_range(0.20, 0.82), rng.randf_range(0.38, 1.38))
		var basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(scale)
		multimesh.set_instance_transform(i, Transform(basis, pos))

	var rocks = MultiMeshInstance.new()
	rocks.name = "ScatteredRocks"
	rocks.multimesh = multimesh
	rocks.material_override = stone_mat
	add_child(rocks)

func _build_trees():
	for _i in range(tree_count):
		var pos = _random_ring_position(22.0, arena_radius - 5.0)
		pos.y = _terrain_height(pos.x, pos.z)
		_add_tree(pos, rng.randf_range(0.78, 1.45))

func _add_tree(pos, scale_amount):
	var root = Spatial.new()
	root.name = "AncientTree"
	root.translation = pos
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)
	root.scale = Vector3(scale_amount, scale_amount, scale_amount)
	add_child(root)

	var trunk = MeshInstance.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.20
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 3.6
	trunk_mesh.radial_segments = 6 if low_spec_mode else 9
	trunk.mesh = trunk_mesh
	trunk.translation.y = 1.8
	trunk.material_override = bark_mat
	root.add_child(trunk)

	var canopy_count = 1 if low_spec_mode else 3
	for j in range(canopy_count):
		var canopy = MeshInstance.new()
		var canopy_mesh = SphereMesh.new()
		canopy_mesh.radius = 1.35 - j * 0.16
		canopy_mesh.height = 1.55
		canopy_mesh.radial_segments = 6 if low_spec_mode else 12
		canopy_mesh.rings = 3 if low_spec_mode else 6
		canopy.mesh = canopy_mesh
		canopy.translation = Vector3(rng.randf_range(-0.34, 0.34), 3.35 + j * 0.62, rng.randf_range(-0.30, 0.30))
		canopy.scale = Vector3(1.1, 0.62, 1.0)
		canopy.material_override = leaf_mat
		root.add_child(canopy)

func _build_ruins():
	if low_spec_mode:
		_add_temple(Vector3(0, _terrain_height(0, -30.0), -30.0), 0.0)
		for i in range(5):
			var angle = float(i) / 5.0 * TAU + 0.12
			var pos = Vector3(cos(angle) * 34.0, 0.0, sin(angle) * 34.0)
			pos.y = _terrain_height(pos.x, pos.z)
			_add_column(pos, rng.randf_range(1.0, 1.8), rng.randf_range(0.24, 0.38), rad2deg(-angle) + 90.0)
		return
	_add_temple(Vector3(0, _terrain_height(0, -42.0), -42.0), 0.0)
	_add_temple(Vector3(43.0, _terrain_height(43.0, 16.0), 16.0), -55.0)
	_add_temple(Vector3(-47.0, _terrain_height(-47.0, 22.0), 22.0), 42.0)

	for i in range(14):
		var angle = float(i) / 14.0 * TAU + 0.12
		var pos = Vector3(cos(angle) * 58.0, 0.0, sin(angle) * 58.0)
		pos.y = _terrain_height(pos.x, pos.z)
		_add_column(pos, rng.randf_range(1.4, 2.8), rng.randf_range(0.32, 0.58), rad2deg(-angle) + 90.0)

func _add_temple(pos, yaw):
	var root = Spatial.new()
	root.name = "RuinedStoneShrine"
	root.translation = pos
	root.rotation_degrees.y = yaw
	add_child(root)

	_add_block(root, Vector3(0, 0.22, 0), Vector3(6.6, 0.42, 5.2), stone_mat)
	_add_block(root, Vector3(0, 3.05, -2.0), Vector3(7.0, 0.58, 0.58), stone_mat)
	_add_block(root, Vector3(-3.2, 1.42, -2.0), Vector3(0.52, 2.5, 0.52), stone_mat)
	_add_block(root, Vector3(3.2, 1.42, -2.0), Vector3(0.52, 2.5, 0.52), stone_mat)
	_add_block(root, Vector3(-2.4, 0.96, 1.9), Vector3(0.42, 1.8, 0.42), stone_mat)
	_add_block(root, Vector3(2.4, 0.96, 1.9), Vector3(0.42, 1.8, 0.42), stone_mat)
	_add_block(root, Vector3(0, 0.82, 2.3), Vector3(4.2, 1.1, 0.32), stone_mat)

	for x in [-2.35, 2.35]:
		for z in [-1.35, 0.95]:
			var column = _make_column(2.3, 0.20)
			column.translation = Vector3(x, 1.45, z)
			root.add_child(column)

func _make_column(height, radius):
	var column = MeshInstance.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.86
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6 if low_spec_mode else 12
	column.mesh = mesh
	column.material_override = stone_mat
	return column

func _add_column(pos, height, radius, yaw):
	var root = Spatial.new()
	root.name = "BrokenPillar"
	root.translation = pos
	root.rotation_degrees = Vector3(rng.randf_range(-4.0, 4.0), yaw, rng.randf_range(-4.0, 4.0))
	add_child(root)
	var column = _make_column(height, radius)
	column.translation.y = height * 0.5
	root.add_child(column)
	_add_block(root, Vector3(0, height + 0.12, 0), Vector3(radius * 3.0, 0.22, radius * 3.0), stone_mat)

func _add_block(parent, pos, scale_amount, material):
	var block = MeshInstance.new()
	var mesh = CubeMesh.new()
	mesh.size = Vector3(1, 1, 1)
	block.mesh = mesh
	block.translation = pos
	block.scale = scale_amount
	block.material_override = material
	parent.add_child(block)
	return block

func _build_torches():
	var torch_positions = [Vector3(-8, 0, -8), Vector3(8, 0, -8)]
	if not low_spec_mode:
		torch_positions.append(Vector3(-8, 0, 8))
		torch_positions.append(Vector3(8, 0, 8))
		torch_positions.append(Vector3(-28, 0, -20))
		torch_positions.append(Vector3(28, 0, 20))
	for pos in torch_positions:
		pos.y = _terrain_height(pos.x, pos.z)
		_add_torch(pos)

func _add_torch(pos):
	var root = Spatial.new()
	root.name = "CinematicTorch"
	root.translation = pos
	add_child(root)

	var pole = MeshInstance.new()
	var pole_mesh = CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.10
	pole_mesh.height = 2.2
	pole_mesh.radial_segments = 6 if low_spec_mode else 10
	pole.mesh = pole_mesh
	pole.translation.y = 1.1
	pole.material_override = bronze_mat
	root.add_child(pole)

	if enable_dynamic_lights:
		var light = OmniLight.new()
		light.name = "TorchLight"
		light.translation.y = 2.35
		light.light_color = Color(1.0, 0.52, 0.21)
		light.light_energy = 1.25 if low_spec_mode else 2.1
		light.omni_range = 7.0 if low_spec_mode else 12.0
		light.shadow_enabled = false
		root.add_child(light)
		torch_lights.append(light)

	if not enable_particles:
		var flame_mesh_instance = MeshInstance.new()
		var flame_static_mesh = SphereMesh.new()
		flame_static_mesh.radius = 0.16
		flame_static_mesh.height = 0.32
		flame_mesh_instance.mesh = flame_static_mesh
		flame_mesh_instance.translation.y = 2.25
		var flame_mat = SpatialMaterial.new()
		flame_mat.albedo_color = Color(1.0, 0.38, 0.10, 0.72)
		flame_mat.flags_transparent = true
		flame_mesh_instance.material_override = flame_mat
		root.add_child(flame_mesh_instance)
		return

	var flame = Particles.new()
	flame.name = "FlameParticles"
	flame.amount = 12 if low_spec_mode else 42
	flame.lifetime = 0.55
	flame.preprocess = 0.2
	flame.emitting = true
	flame.local_coords = false
	flame.translation.y = 2.25
	var flame_material = ParticlesMaterial.new()
	flame_material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_SPHERE
	flame_material.emission_sphere_radius = 0.16
	flame_material.gravity = Vector3(0, 1.8, 0)
	flame_material.initial_velocity = 0.95
	flame_material.initial_velocity_random = 0.45
	flame_material.scale = 0.18
	flame_material.scale_random = 0.55
	flame_material.spread = 42.0
	flame_material.color = Color(1.0, 0.42, 0.12, 0.78)
	flame.process_material = flame_material
	var flame_mesh = SphereMesh.new()
	flame_mesh.radius = 0.09
	flame_mesh.height = 0.18
	flame.draw_pass_1 = flame_mesh
	root.add_child(flame)

func _build_atmosphere():
	var dust = Particles.new()
	dust.name = "GroundFogDust"
	dust.amount = 40 if low_spec_mode else 260
	dust.lifetime = 7.5
	dust.preprocess = 5.0
	dust.emitting = true
	dust.local_coords = false
	var material = ParticlesMaterial.new()
	material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(arena_radius * 0.72, 1.0, arena_radius * 0.72)
	material.gravity = Vector3(0, 0.03, 0)
	material.initial_velocity = 0.26
	material.initial_velocity_random = 0.85
	material.scale = 0.26
	material.scale_random = 0.72
	material.color = Color(0.82, 0.70, 0.56, 0.28)
	dust.process_material = material
	var mesh = SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	dust.draw_pass_1 = mesh
	add_child(dust)

	var fog_layers = 1 if low_spec_mode else 5
	for i in range(fog_layers):
		var fog = MeshInstance.new()
		fog.name = "LowFogLayer"
		var plane = PlaneMesh.new()
		plane.size = Vector2(arena_radius * rng.randf_range(0.55, 0.95), arena_radius * rng.randf_range(0.40, 0.80))
		fog.mesh = plane
		fog.translation = Vector3(rng.randf_range(-15, 15), 0.08 + i * 0.035, rng.randf_range(-15, 15))
		fog.rotation_degrees.y = rng.randf_range(0, 360)
		var fog_mat = SpatialMaterial.new()
		fog_mat.flags_transparent = true
		fog_mat.albedo_color = Color(0.58, 0.50, 0.42, 0.055)
		fog_mat.roughness = 1.0
		fog.material_override = fog_mat
		add_child(fog)

func _random_ring_position(min_radius, max_radius):
	var angle = rng.randf_range(0.0, TAU)
	var dist = sqrt(rng.randf_range(min_radius * min_radius, max_radius * max_radius))
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
