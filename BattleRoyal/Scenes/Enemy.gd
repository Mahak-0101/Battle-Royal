extends KinematicBody

export (int) var speed = 5
export (int) var max_health = 115
export (int) var attack_damage = 18
export (float) var attack_range = 1.85
export (float) var chase_range = 38.0
export (float) var attack_cooldown = 1.18
export (float) var attack_windup = 0.34
export (float) var turn_speed = 8.5
export (int) var xp_reward = 35
export (float) var special_reward = 24.0

var health = max_health
var player = null
var velocity = Vector3.ZERO
var gravity = 20.0
var attack_timer = 0.0
var attack_recovery = 0.0
var attack_has_hit = false
var hit_reaction_timer = 0.0
var strafe_timer = 0.0
var strafe_side = 1.0
var desired_look_direction = Vector3(0, 0, 1)
var display_name = "Enemy Warrior"
var health_root = null
var health_fill = null
var style_root = null
var last_damage_source = null
var health_update_timer = 0.0
var dead = false

func _ready():
	add_to_group("enemies")
	health = max_health
	if get_parent() and get_parent().has_node("Player"):
		player = get_parent().get_node("Player")
	_build_enemy_style()
	_build_health_bar()
	_pick_new_strafe()

func _physics_process(delta):
	_find_player()
	_update_timers(delta)
	health_update_timer -= delta
	if health_update_timer <= 0.0:
		health_update_timer = 0.08
		_update_health_bar(delta)
	if player == null or not is_instance_valid(player):
		return

	var to_player = player.global_transform.origin - global_transform.origin
	var distance = to_player.length()
	var flat_to_player = to_player
	flat_to_player.y = 0
	if flat_to_player.length() > 0.05:
		desired_look_direction = flat_to_player.normalized()

	if hit_reaction_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)
	elif attack_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, speed * 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 12.0 * delta)
	elif distance <= attack_range and attack_recovery <= 0.0:
		_start_attack()
	elif distance < chase_range:
		_move_tactically(flat_to_player, distance, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 3.0 * delta)

	if is_on_floor():
		velocity.y = -0.2
	else:
		velocity.y -= gravity * delta
	velocity = move_and_slide(velocity, Vector3.UP)
	_update_facing(delta)

func _find_player():
	if player and is_instance_valid(player):
		return
	if get_parent() and get_parent().has_node("Player"):
		player = get_parent().get_node("Player")

func _update_timers(delta):
	if attack_recovery > 0.0:
		attack_recovery = max(0.0, attack_recovery - delta)
	if hit_reaction_timer > 0.0:
		hit_reaction_timer = max(0.0, hit_reaction_timer - delta)
	if strafe_timer > 0.0:
		strafe_timer -= delta
	else:
		_pick_new_strafe()
	if attack_timer > 0.0:
		var elapsed = attack_cooldown - attack_timer
		if not attack_has_hit and elapsed >= attack_windup:
			_apply_attack_hit()
			attack_has_hit = true
		attack_timer = max(0.0, attack_timer - delta)

func _move_tactically(flat_to_player, distance, delta):
	var desired = Vector3.ZERO
	if flat_to_player.length() > 0.05:
		var forward = flat_to_player.normalized()
		var tangent = Vector3(-forward.z, 0, forward.x) * strafe_side
		if distance > attack_range * 1.25:
			desired += forward
		elif distance < attack_range * 0.74:
			desired -= forward * 0.8
		desired += tangent * (0.42 if distance < 4.4 else 0.18)
	if desired.length() > 0.05:
		desired = desired.normalized()
	var target_speed = speed
	if distance < 3.2:
		target_speed *= 0.82
	velocity.x = move_toward(velocity.x, desired.x * target_speed, speed * 5.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z * target_speed, speed * 5.0 * delta)

func _pick_new_strafe():
	strafe_timer = rand_range(0.7, 1.6)
	strafe_side = -1.0 if randf() < 0.5 else 1.0

func _start_attack():
	attack_timer = attack_cooldown
	attack_recovery = attack_cooldown + 0.16
	attack_has_hit = false
	_spawn_attack_telegraph()

func _apply_attack_hit():
	if player == null or not is_instance_valid(player):
		return
	var to_player = player.global_transform.origin - global_transform.origin
	var flat = to_player
	flat.y = 0
	if flat.length() > attack_range + 0.35:
		return
	if desired_look_direction.dot(flat.normalized()) < 0.2:
		return
	if player.has_method("apply_damage"):
		player.apply_damage(attack_damage, self)
	_spawn_weapon_spark(player.global_transform.origin + Vector3.UP * 1.15)

func _update_facing(delta):
	if desired_look_direction.length() <= 0.05:
		return
	var target_yaw = atan2(desired_look_direction.x, -desired_look_direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))

func apply_damage(amount, source = null, stagger = 0.28):
	if dead:
		return
	last_damage_source = source
	health -= amount
	hit_reaction_timer = max(hit_reaction_timer, stagger)
	attack_timer = 0.0
	attack_recovery = max(attack_recovery, 0.26)
	if source and is_instance_valid(source):
		var away = global_transform.origin - source.global_transform.origin
		away.y = 0
		if away.length() > 0.05:
			velocity.x = away.normalized().x * 4.5
			velocity.z = away.normalized().z * 4.5
	_spawn_hit_fx()
	_update_health_bar(0.0)
	_play_hit_sound()
	if health <= 0:
		_die()

func configure(profile):
	if profile == null:
		return
	display_name = str(profile.get("name", display_name))
	max_health = int(profile.get("health", max_health))
	health = max_health
	attack_damage = int(profile.get("damage", attack_damage))
	speed = int(profile.get("speed", speed))
	xp_reward = int(profile.get("xp", xp_reward))
	special_reward = float(profile.get("special", special_reward))
	_update_health_bar(0.0)

func get_display_name():
	return display_name

func _die():
	if dead:
		return
	dead = true
	var current = get_tree().get_current_scene()
	if current and current.has_node("GameManager"):
		var gm = current.get_node("GameManager")
		if gm and gm.has_method("notify_enemy_defeated"):
			gm.notify_enemy_defeated(self, last_damage_source, xp_reward, special_reward)
	_play_death_sound()
	_spawn_death_fx()
	remove_from_group("enemies")
	set_physics_process(false)
	visible = false
	yield(get_tree().create_timer(0.08), "timeout")
	if is_instance_valid(self):
		queue_free()

func _build_enemy_style():
	if has_node("EnemyStyle"):
		style_root = get_node("EnemyStyle")
		return
	style_root = Spatial.new()
	style_root.name = "EnemyStyle"
	add_child(style_root)

	var armor_mat = SpatialMaterial.new()
	armor_mat.albedo_color = Color(0.12, 0.13, 0.17)
	armor_mat.metallic = 0.26
	armor_mat.roughness = 0.52
	var cloth_mat = SpatialMaterial.new()
	cloth_mat.albedo_color = Color(0.38, 0.04, 0.05)
	cloth_mat.roughness = 0.84
	var gold_mat = SpatialMaterial.new()
	gold_mat.albedo_color = Color(0.78, 0.58, 0.22)
	gold_mat.metallic = 0.52
	gold_mat.roughness = 0.30
	var steel_mat = SpatialMaterial.new()
	steel_mat.albedo_color = Color(0.60, 0.61, 0.58)
	steel_mat.metallic = 0.65
	steel_mat.roughness = 0.24

	_add_style_part("LeftPauldron", SphereMesh.new(), Vector3(-0.52, 1.53, 0.0), Vector3(0, 0, 0), Vector3(0.42, 0.18, 0.34), armor_mat)
	_add_style_part("RightPauldron", SphereMesh.new(), Vector3(0.52, 1.53, 0.0), Vector3(0, 0, 0), Vector3(0.42, 0.18, 0.34), armor_mat)

	var chest = CubeMesh.new()
	chest.size = Vector3(0.72, 0.62, 0.10)
	_add_style_part("LayeredChest", chest, Vector3(0, 1.24, 0.34), Vector3(-7, 0, 0), Vector3(1, 1, 1), armor_mat)
	for i in range(3):
		var strip = CubeMesh.new()
		strip.size = Vector3(0.76 - i * 0.10, 0.08, 0.08)
		_add_style_part("ChestStrip%d" % i, strip, Vector3(0, 1.42 - i * 0.14, 0.40), Vector3(-7, 0, 0), Vector3(1, 1, 1), gold_mat)

	var cape = CubeMesh.new()
	cape.size = Vector3(0.86, 1.05, 0.035)
	_add_style_part("TornCape", cape, Vector3(0, 1.05, -0.38), Vector3(8, 0, 0), Vector3(1, 1, 1), cloth_mat)

	var blade = CubeMesh.new()
	blade.size = Vector3(0.08, 0.96, 0.04)
	_add_style_part("SwordBlade", blade, Vector3(0.74, 1.10, 0.16), Vector3(0, 0, -30), Vector3(1, 1, 1), steel_mat)
	var grip = CylinderMesh.new()
	grip.top_radius = 0.035
	grip.bottom_radius = 0.035
	grip.height = 0.28
	_add_style_part("SwordGrip", grip, Vector3(0.58, 0.84, 0.14), Vector3(0, 0, -30), Vector3(1, 1, 1), gold_mat)

	var brow = CubeMesh.new()
	brow.size = Vector3(0.24, 0.045, 0.028)
	_add_style_part("StrongBrow", brow, Vector3(0, 1.99, 0.225), Vector3(0, 0, 0), Vector3(1, 1, 1), armor_mat)

func _add_style_part(name, mesh, pos, rot, scale_amount, material):
	var part = MeshInstance.new()
	part.name = name
	part.mesh = mesh
	part.translation = pos
	part.rotation_degrees = rot
	part.scale = scale_amount
	part.material_override = material
	style_root.add_child(part)

func _build_health_bar():
	health_root = Spatial.new()
	health_root.name = "EnemyHealthBar"
	health_root.translation = Vector3(0, 2.55, 0)
	add_child(health_root)

	var bg = MeshInstance.new()
	var bg_mesh = CubeMesh.new()
	bg_mesh.size = Vector3(1.12, 0.075, 0.035)
	bg.mesh = bg_mesh
	var bg_mat = SpatialMaterial.new()
	bg_mat.albedo_color = Color(0.08, 0.02, 0.02, 0.88)
	bg_mat.flags_transparent = true
	bg.material_override = bg_mat
	health_root.add_child(bg)

	health_fill = MeshInstance.new()
	var fill_mesh = CubeMesh.new()
	fill_mesh.size = Vector3(1.06, 0.052, 0.04)
	health_fill.mesh = fill_mesh
	health_fill.translation = Vector3(0, 0, 0.012)
	var fill_mat = SpatialMaterial.new()
	fill_mat.albedo_color = Color(0.92, 0.14, 0.08, 0.92)
	fill_mat.emission_enabled = true
	fill_mat.emission = Color(0.55, 0.04, 0.02)
	fill_mat.flags_transparent = true
	health_fill.material_override = fill_mat
	health_root.add_child(health_fill)

func _update_health_bar(_delta):
	if health_root == null or health_fill == null:
		return
	var current = get_tree().get_current_scene()
	if current and current.has_node("Camera"):
		var cam = current.get_node("Camera")
		health_root.look_at(cam.global_transform.origin, Vector3.UP)
		health_root.rotate_y(PI)
	var fraction = clamp(float(health) / float(max(max_health, 1)), 0.0, 1.0)
	health_fill.scale.x = max(0.01, fraction)
	health_fill.translation.x = -0.53 + 0.53 * fraction

func _spawn_attack_telegraph():
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var glow = MeshInstance.new()
	var mesh = TorusMesh.new()
	mesh.inner_radius = 0.26
	mesh.outer_radius = 0.34
	mesh.ring_segments = 28
	glow.mesh = mesh
	glow.translation = global_transform.origin + Vector3.UP * 0.08 + desired_look_direction * 0.9
	glow.rotation_degrees = Vector3(90, 0, 0)
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(1.0, 0.18, 0.08, 0.42)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.08, 0.03)
	mat.flags_transparent = true
	glow.material_override = mat
	current.add_child(glow)
	yield(get_tree().create_timer(attack_windup), "timeout")
	if is_instance_valid(glow):
		glow.queue_free()

func _spawn_weapon_spark(position):
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var spark = MeshInstance.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	spark.mesh = sphere
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(1, 0.52, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.28, 0.05)
	spark.material_override = mat
	spark.translation = position
	current.add_child(spark)
	yield(get_tree().create_timer(0.10), "timeout")
	if is_instance_valid(spark):
		spark.queue_free()

func _spawn_hit_fx():
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var fx = Particles.new()
	fx.name = "EnemyHitSparks"
	fx.amount = 8
	fx.lifetime = 0.34
	fx.one_shot = true
	fx.explosiveness = 0.84
	fx.translation = global_transform.origin + Vector3.UP * 1.25
	var material = ParticlesMaterial.new()
	material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.20
	material.gravity = Vector3(0, -2.0, 0)
	material.initial_velocity = 2.3
	material.initial_velocity_random = 0.7
	material.scale = 0.085
	material.scale_random = 0.55
	material.color = Color(1.0, 0.55, 0.16, 0.82)
	fx.process_material = material
	var mesh = SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	fx.draw_pass_1 = mesh
	current.add_child(fx)
	fx.emitting = true
	yield(get_tree().create_timer(0.48), "timeout")
	if is_instance_valid(fx):
		fx.queue_free()

func _spawn_death_fx():
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var burst = Particles.new()
	burst.name = "EnemyDeathBurst"
	burst.amount = 12
	burst.lifetime = 0.78
	burst.one_shot = true
	burst.explosiveness = 0.96
	burst.translation = global_transform.origin + Vector3.UP * 1.0
	var material = ParticlesMaterial.new()
	material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.32
	material.gravity = Vector3(0, -3.6, 0)
	material.initial_velocity = 4.2
	material.initial_velocity_random = 0.72
	material.scale = 0.11
	material.scale_random = 0.7
	material.color = Color(1.0, 0.72, 0.28, 0.74)
	burst.process_material = material
	var mesh = SphereMesh.new()
	mesh.radius = 0.065
	mesh.height = 0.13
	burst.draw_pass_1 = mesh
	current.add_child(burst)
	burst.emitting = true
	yield(get_tree().create_timer(1.0), "timeout")
	if is_instance_valid(burst):
		burst.queue_free()

func _play_hit_sound():
	var current = get_tree().get_current_scene()
	if current == null or not current.has_node("GameManager"):
		return
	var gm = current.get_node("GameManager")
	if gm and gm.has_method("play_hit_sound"):
		gm.play_hit_sound()

func _play_death_sound():
	var current = get_tree().get_current_scene()
	if current == null or not current.has_node("GameManager"):
		return
	var gm = current.get_node("GameManager")
	if gm and gm.has_method("play_death_sound"):
		gm.play_death_sound()
