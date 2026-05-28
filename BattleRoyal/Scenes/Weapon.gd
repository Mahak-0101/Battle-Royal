extends Spatial

export(float) var fire_rate = 0.5
export(int) var damage = 34
export(PackedScene) var bullet_scene
export(float) var fire_range = 1000.0
export(AudioStream) var fire_sound = null
export(AudioStream) var hit_sound = null

var cooldown = 0.0

func _process(delta):
	cooldown = max(0, cooldown - delta)

func can_fire():
	return cooldown <= 0

func fire(origin_transform, direction):
	if not can_fire():
		return false
	# If a projectile scene is provided, spawn it. Otherwise perform a hitscan raycast.
	if bullet_scene:
		var b = bullet_scene.instance()
		b.global_transform = Transform(origin_transform.basis, origin_transform.origin)
		b.direction = direction
		b.damage = damage
		var current = get_tree().get_current_scene()
		if current:
			current.add_child(b)
		else:
			get_tree().get_root().add_child(b)
		_spawn_muzzle_flash(origin_transform)
		_play_game_sound("play_fire_sound")
	else:
		var from = origin_transform.origin
		var to = from + direction.normalized() * fire_range
		var current = get_tree().get_current_scene()
		if current == null or not current.has_method("get_world"):
			return true
		var space_state = current.get_world().direct_space_state
		var res = space_state.intersect_ray(from, to, [], 0x7FFFFFFF, true, true)
		if res:
			var collider = res.collider
			_spawn_impact_fx(res.position)
			# apply damage
			if collider and collider.has_method("apply_damage"):
				collider.apply_damage(damage)
				_play_game_sound("play_hit_sound")
	cooldown = fire_rate
	return true

func _spawn_muzzle_flash(origin_transform):
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var flash = MeshInstance.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.10
	flash.mesh = sphere
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(1, 1, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.9, 0.4)
	flash.material_override = mat
	flash.global_transform = origin_transform
	current.add_child(flash)
	yield(get_tree().create_timer(0.04), "timeout")
	if is_instance_valid(flash):
		flash.queue_free()

func _spawn_impact_fx(position):
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var fx = MeshInstance.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.10
	sphere.height = 0.20
	fx.mesh = sphere
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(1, 0.5, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.45, 0.1)
	fx.material_override = mat
	fx.translation = position
	current.add_child(fx)
	yield(get_tree().create_timer(0.10), "timeout")
	if is_instance_valid(fx):
		fx.queue_free()

func _play_game_sound(method_name):
	var current = get_tree().get_current_scene()
	if current == null or not current.has_node("GameManager"):
		return
	var gm = current.get_node("GameManager")
	if gm and gm.has_method(method_name):
		gm.call(method_name)
