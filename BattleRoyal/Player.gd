extends KinematicBody

export (int) var walk_speed = 8
export (int) var run_speed = 14
var speed = walk_speed
export (int) var jump_speed = 7
var velocity = Vector3()
var gravity = 20
export (bool) var low_spec_mode = true

export (int) var max_health = 100
var health = max_health

onready var bullet_scene = preload("res://Scenes/Bullet.tscn")
var shoot_cooldown = 0.28
var shoot_timer = 0.0

var anim_player = null
var pose_anim_player = null
var camera = null
var inventory = []
var equipped_index = -1
var equipped_weapon = null
var character_name = "Arjun"
var weapon_display_name = "Gandiva Bow"
var character_data = {}
var visual_model = null
var skeleton = null
var weapon_hand_socket = null
var weapon_back_socket = null
var current_locomotion_animation = ""

export (float) var move_acceleration = 30.0
export (float) var move_deceleration = 26.0
export (float) var air_control = 0.35
export (float) var turn_lerp_speed = 12.0
export (float) var fall_gravity_multiplier = 1.35
export (float) var sprint_turn_boost = 2.6

export (bool) var use_warrior_style = true
export (Color) var warrior_skin_tone = Color(0.89, 0.77, 0.66, 1.0)
export (Color) var warrior_cloth_tone = Color(0.16, 0.18, 0.26, 1.0)
export (Color) var warrior_wrap_tone = Color(0.86, 0.77, 0.66, 1.0)
export (Color) var warrior_hair_tone = Color(0.18, 0.12, 0.08, 1.0)

export (int) var melee_damage = 32
export (float) var melee_range = 2.65
export (float) var melee_arc_degrees = 108.0
export (float) var combo_reset_time = 0.86
export (float) var dodge_speed = 18.0
export (float) var dodge_duration = 0.28
export (float) var dodge_cooldown = 0.62
export (float) var guard_max = 100.0
export (float) var guard_regen = 22.0
export (float) var block_damage_multiplier = 0.18
export (float) var target_scan_range = 15.0
export (float) var attack_move_multiplier = 0.9
export (bool) var full_angle_melee = true

onready var warrior_hybrid_shader = preload("res://Assets/Shaders/WarriorHybrid.shader")
var warrior_style_root = null

var desired_look_direction = Vector3(0, 0, -1)
var combat_target = null
var combat_scan_timer = 0.0
var attack_timer = 0.0
var current_attack_duration = 0.0
var current_attack_windup = 0.12
var attack_has_applied = false
var combo_index = 0
var combo_timer = 0.0
var dodge_timer = 0.0
var dodge_cooldown_timer = 0.0
var dodge_direction = Vector3.ZERO
var invincible_timer = 0.0
var hit_reaction_timer = 0.0
var is_blocking = false
var guard_value = guard_max
var last_hud_target = null
var respawn_position = Vector3(0, 3, 0)
var player_level = 1
var xp = 0
var xp_next = 100
var special_meter = 35.0
var special_max = 100.0
var special_cooldown = 0.0
var low_spec_hand_socket = null
var low_spec_back_socket = null
var low_spec_anim_time = 0.0

func _ready():
	add_to_group("player")
	health = max_health
	guard_value = guard_max
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_health"):
			hud.call_deferred("set_health", health)
		if hud and hud.has_method("set_guard"):
			hud.call_deferred("set_guard", guard_value, guard_max)
	if current and current.has_node("Camera"):
		camera = current.get_node("Camera")
	else:
		camera = null
	if has_node("Idle"):
		var idle_node = get_node("Idle")
		anim_player = idle_node.find_node("AnimationPlayer", true, false)
	_apply_character_defaults()
	_setup_character_visuals()
	_update_hud_character()
	_update_hud_progression()

func _physics_process(delta):
	_refresh_camera()
	_refresh_combat_target(delta)
	_update_combat_timers(delta)

	var input_vector = _get_input_vector()
	var direction = _get_camera_relative_direction(input_vector)
	var wants_run = Input.is_key_pressed(KEY_SHIFT) and not is_blocking and attack_timer <= 0.0
	speed = run_speed if wants_run else walk_speed

	if _wants_dodge() and _can_dodge():
		_start_dodge(direction)

	if Input.is_mouse_button_pressed(BUTTON_RIGHT) and _can_block():
		is_blocking = true
	else:
		is_blocking = false

	if Input.is_mouse_button_pressed(BUTTON_LEFT) and _can_attack():
		_start_melee_attack()

	shoot_timer -= delta
	if Input.is_key_pressed(KEY_F) and shoot_timer <= 0.0:
		shoot()
		shoot_timer = shoot_cooldown

	var target_speed = speed
	if is_blocking:
		target_speed *= 0.42
	elif attack_timer > 0.0:
		target_speed *= attack_move_multiplier
	if hit_reaction_timer > 0.0:
		target_speed = 0.0

	if dodge_timer > 0.0:
		velocity.x = dodge_direction.x * dodge_speed
		velocity.z = dodge_direction.z * dodge_speed
	else:
		var target_velocity = direction * target_speed
		var control_rate = move_acceleration if is_on_floor() else move_acceleration * air_control
		if direction.length() > 0.0:
			velocity.x = move_toward(velocity.x, target_velocity.x, control_rate * delta)
			velocity.z = move_toward(velocity.z, target_velocity.z, control_rate * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, move_deceleration * delta)
			velocity.z = move_toward(velocity.z, 0, move_deceleration * delta)

	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE) and attack_timer <= 0.0 and dodge_timer <= 0.0:
			velocity.y = jump_speed
			_play_action_pose("Jump")
	else:
		var gravity_scale = fall_gravity_multiplier if velocity.y < 0 else 1.0
		velocity.y -= gravity * gravity_scale * delta

	velocity = move_and_slide(velocity, Vector3.UP)
	_update_facing(direction, delta)
	_update_animation(direction, attack_timer > 0.0 or is_blocking)
	_update_low_spec_motion_animation(direction, attack_timer > 0.0 or is_blocking, delta)
	_refresh_weapon_attachments()
	_update_hud_guard()

func _refresh_camera():
	if camera and is_instance_valid(camera):
		return
	var current = get_tree().get_current_scene()
	if current and current.has_node("Camera"):
		camera = current.get_node("Camera")

func _get_input_vector():
	var input_vector = Vector3.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_vector.z += 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_vector.z -= 1.0
	return input_vector.normalized()

func _get_camera_relative_direction(input_vector):
	if input_vector.length() <= 0.001:
		return Vector3.ZERO
	var forward = Vector3(0, 0, -1)
	var right = Vector3(1, 0, 0)
	if camera and is_instance_valid(camera):
		forward = -camera.global_transform.basis.z
		forward.y = 0
		if forward.length() > 0.001:
			forward = forward.normalized()
		right = camera.global_transform.basis.x
		right.y = 0
		if right.length() > 0.001:
			right = right.normalized()
	return (right * input_vector.x + forward * input_vector.z).normalized()

func _update_facing(direction, delta):
	var look_dir = Vector3.ZERO
	if direction.length() > 0.05:
		look_dir = direction
	elif attack_timer > 0.0 and camera:
		look_dir = -camera.global_transform.basis.z
		look_dir.y = 0
	elif is_blocking and camera:
		look_dir = -camera.global_transform.basis.z
		look_dir.y = 0
	if look_dir.length() > 0.05:
		desired_look_direction = look_dir.normalized()
	if visual_model:
		var target_yaw = atan2(desired_look_direction.x, -desired_look_direction.z)
		var turn_speed = turn_lerp_speed + (sprint_turn_boost if speed == run_speed else 0.0)
		if attack_timer > 0.0 or is_blocking:
			turn_speed += 6.0
		visual_model.rotation.y = lerp_angle(visual_model.rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))

func _update_combat_timers(delta):
	if combo_timer > 0.0:
		combo_timer -= delta
	else:
		combo_index = 0
	if attack_timer > 0.0:
		var elapsed = current_attack_duration - attack_timer
		if not attack_has_applied and elapsed >= current_attack_windup:
			_perform_melee_trace()
			attack_has_applied = true
		attack_timer = max(0.0, attack_timer - delta)
	if dodge_timer > 0.0:
		dodge_timer = max(0.0, dodge_timer - delta)
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer = max(0.0, dodge_cooldown_timer - delta)
	if invincible_timer > 0.0:
		invincible_timer = max(0.0, invincible_timer - delta)
	if hit_reaction_timer > 0.0:
		hit_reaction_timer = max(0.0, hit_reaction_timer - delta)
	if not is_blocking and guard_value < guard_max:
		guard_value = min(guard_max, guard_value + guard_regen * delta)
	if special_cooldown > 0.0:
		special_cooldown = max(0.0, special_cooldown - delta)

func _wants_dodge():
	return Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_CONTROL)

func _can_dodge():
	return is_on_floor() and dodge_timer <= 0.0 and dodge_cooldown_timer <= 0.0 and attack_timer <= 0.22 and hit_reaction_timer <= 0.0

func _start_dodge(direction):
	if direction.length() <= 0.05:
		direction = -_get_forward_vector()
	dodge_direction = direction.normalized()
	dodge_timer = dodge_duration
	dodge_cooldown_timer = dodge_cooldown
	invincible_timer = dodge_duration + 0.08
	is_blocking = false
	_play_action_pose("Dodge")
	_spawn_dodge_dust()
	_shake_camera(0.10, 0.10, 1.2)
	_notify_combat("Dodge", Color(0.60, 0.84, 1.0))

func _can_block():
	return guard_value > 8.0 and dodge_timer <= 0.0 and hit_reaction_timer <= 0.0

func _can_attack():
	return attack_timer <= 0.0 and dodge_timer <= 0.0 and hit_reaction_timer <= 0.0

func _start_melee_attack():
	var input_vector = _get_input_vector()
	var input_dir = _get_camera_relative_direction(input_vector)
	if input_dir.length() > 0.05:
		desired_look_direction = input_dir
	elif camera:
		var cam_forward = -camera.global_transform.basis.z
		cam_forward.y = 0
		if cam_forward.length() > 0.05:
			desired_look_direction = cam_forward.normalized()

	combo_index += 1
	if combo_index > 3 or combo_timer <= 0.0:
		combo_index = 1
	combo_timer = combo_reset_time
	var durations = [0.44, 0.50, 0.62]
	var windups = [0.10, 0.12, 0.17]
	current_attack_duration = durations[combo_index - 1]
	current_attack_windup = windups[combo_index - 1]
	attack_timer = current_attack_duration
	attack_has_applied = false
	is_blocking = false
	_play_action_pose("Attack%d" % combo_index)
	_spawn_slash_vfx(false)
	_shake_camera(0.06 + combo_index * 0.025, 0.08, 1.8 + combo_index)

func _perform_melee_trace():
	var forward = _get_forward_vector()
	var origin = global_transform.origin + Vector3.UP * 0.95
	var best_hit = null
	var hit_count = 0
	var damage_amount = melee_damage + (combo_index - 1) * 7
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_enemy = enemy.global_transform.origin + Vector3.UP * 0.9 - origin
		var flat = to_enemy
		flat.y = 0
		var distance = flat.length()
		if distance > melee_range or distance <= 0.05:
			continue
		if not full_angle_melee:
			var arc_dot = cos(deg2rad(melee_arc_degrees * 0.5))
			var dot = forward.dot(flat.normalized())
			if dot < arc_dot:
				continue
		if enemy.has_method("apply_damage"):
			enemy.apply_damage(damage_amount, self, 0.28 + combo_index * 0.08)
			hit_count += 1
			if best_hit == null or distance < global_transform.origin.distance_to(best_hit.global_transform.origin):
				best_hit = enemy

	if hit_count > 0:
		combat_target = best_hit
		_spawn_slash_vfx(true)
		_shake_camera(0.18 + combo_index * 0.05, 0.13, 4.4)
		_notify_combat("Clean hit x%d" % hit_count, Color(1.0, 0.82, 0.38))
	else:
		_spawn_slash_vfx(false)

func _get_forward_vector():
	if visual_model:
		return Vector3(sin(visual_model.rotation.y), 0, -cos(visual_model.rotation.y)).normalized()
	return desired_look_direction.normalized()

func _refresh_combat_target(delta):
	combat_scan_timer -= delta
	if combat_scan_timer > 0.0 and combat_target and is_instance_valid(combat_target):
		_update_hud_target()
		return
	combat_scan_timer = 0.18
	var best_target = null
	var best_score = 9999.0
	var forward = _get_forward_vector()
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_enemy = enemy.global_transform.origin - global_transform.origin
		to_enemy.y = 0
		var distance = to_enemy.length()
		if distance > target_scan_range or distance <= 0.05:
			continue
		var alignment = max(0.0, forward.dot(to_enemy.normalized()))
		var score = distance - alignment * 4.0
		if score < best_score:
			best_score = score
			best_target = enemy
	combat_target = best_target
	_update_hud_target()

func get_combat_target():
	if combat_target and is_instance_valid(combat_target):
		return combat_target
	return null

func shoot():
	if equipped_weapon != null and equipped_weapon.has_method("fire"):
		var origin = Transform()
		var dir = -global_transform.basis.z
		var current = get_tree().get_current_scene()
		if current and current.has_node("Camera"):
			var cam = current.get_node("Camera")
			origin = cam.global_transform
			dir = (cam.global_transform.basis.z * -1).normalized()
		else:
			origin = global_transform
			dir = -global_transform.basis.z
		equipped_weapon.fire(origin, dir)
		_play_action_pose("Attack1")
		_pulse_combat_feedback()
	else:
		var b = bullet_scene.instance()
		var cam = null
		var current = get_tree().get_current_scene()
		if current and current.has_node("Camera"):
			cam = current.get_node("Camera")
		if cam:
			var spawn_pos = cam.global_transform.origin + cam.global_transform.basis.z * -1.5 + Vector3(0, -0.5, 0)
			b.global_transform = Transform(cam.global_transform.basis, spawn_pos)
			b.direction = (cam.global_transform.basis.z * -1).normalized()
		else:
			b.global_transform.origin = global_transform.origin
			b.direction = -global_transform.basis.z
		get_parent().add_child(b)
		_play_fire_sound()
		_play_action_pose("Attack1")
		_pulse_combat_feedback()

func pickup_weapon(packed_scene, name="Weapon"):
	if not packed_scene:
		return
	var instance = null
	if typeof(packed_scene) == TYPE_OBJECT and packed_scene is PackedScene:
		instance = packed_scene.instance()
	elif typeof(packed_scene) == TYPE_STRING:
		var ps = load(packed_scene)
		if ps:
			instance = ps.instance()
	if instance:
		add_child(instance)
		instance.owner = get_tree().get_current_scene()
		instance.set_physics_process(true)
		inventory.append({"node": instance, "name": name})
		if equipped_index == -1:
			equip_weapon(0)
		_refresh_weapon_attachments()
		var current = get_tree().get_current_scene()
		if current and current.has_node("HUD"):
			var hud = current.get_node("HUD")
			if hud and hud.has_method("add_weapon_slot"):
				hud.call_deferred("add_weapon_slot", name, inventory.size() - 1)

func apply_character_preset(data, starter_weapon_scene = null):
	if data == null:
		return
	character_data = data
	character_name = str(data.get("display_name", character_name))
	weapon_display_name = str(data.get("weapon_name", weapon_display_name))
	max_health = int(data.get("max_health", max_health))
	walk_speed = int(data.get("walk_speed", walk_speed))
	run_speed = int(data.get("run_speed", run_speed))
	shoot_cooldown = float(data.get("fire_rate", shoot_cooldown))
	melee_damage = int(data.get("melee_damage", data.get("damage", melee_damage)))
	health = max_health
	guard_value = guard_max
	_apply_character_defaults()
	_setup_character_visuals()
	_update_hud_character()
	_update_hud_progression()
	if starter_weapon_scene:
		if inventory.size() == 0:
			pickup_weapon(starter_weapon_scene, weapon_display_name)
			if equipped_index == -1:
				equip_weapon(0)
		if inventory.size() > 0:
			var starter_weapon = inventory[0]["node"]
			if starter_weapon:
				starter_weapon.set("fire_rate", float(data.get("fire_rate", shoot_cooldown)))
				starter_weapon.set("damage", int(data.get("damage", 34)))
				if starter_weapon.has_method("set_weapon_name"):
					starter_weapon.call("set_weapon_name", weapon_display_name)

func _apply_character_defaults():
	if character_name == "Arjun":
		weapon_display_name = "Gandiva Bow"
	elif character_name == "Krishna":
		weapon_display_name = "Sudarshan Chakra"
	elif character_name == "Bhima":
		weapon_display_name = "Vajra Gada"
	elif character_name == "Karna":
		weapon_display_name = "Vijaya Bow"

func _update_hud_character():
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("show_selected_character"):
			hud.call_deferred("show_selected_character", {
				"display_name": character_name,
				"weapon_name": weapon_display_name,
				"max_health": max_health,
				"walk_speed": walk_speed,
				"run_speed": run_speed,
				"melee_damage": melee_damage
			})
		if hud and hud.has_method("set_guard"):
			hud.call_deferred("set_guard", guard_value, guard_max)

func equip_weapon(idx):
	if idx < 0 or idx >= inventory.size():
		return
	equipped_index = idx
	equipped_weapon = inventory[idx]["node"]
	_refresh_weapon_attachments()
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_weapon"):
			hud.call_deferred("set_weapon", inventory[idx]["name"])
		if hud and hud.has_method("set_selected_weapon"):
			hud.call_deferred("set_selected_weapon", equipped_index)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_1:
			equip_weapon(0)
		elif event.scancode == KEY_2:
			equip_weapon(1)
		elif event.scancode == KEY_Q:
			_try_special_ability()

func _update_animation(direction, action_active):
	if not anim_player:
		return
	var speed_val = Vector2(velocity.x, velocity.z).length()
	var target_animation = "Idle"
	if not is_on_floor():
		target_animation = "Idle"
	elif speed_val > run_speed * 0.58:
		target_animation = "Run" if anim_player.has_animation("Run") else "Walk"
	elif speed_val > 0.35 or direction.length() > 0.05:
		target_animation = "Walk"
	if action_active and speed_val < 1.5:
		target_animation = "Idle"
	_play_locomotion_animation(target_animation)

func _update_low_spec_motion_animation(direction, action_active, delta):
	if not low_spec_mode or visual_model == null:
		return
	low_spec_anim_time += delta
	var move_speed = Vector2(velocity.x, velocity.z).length()
	var moving = move_speed > 0.35 and direction.length() > 0.05
	var pace = 7.5 if move_speed > walk_speed + 1.0 else 5.2
	var phase = low_spec_anim_time * pace
	var swing = sin(phase)
	var counter = cos(phase)
	var idle_breath = sin(low_spec_anim_time * 2.2) * 0.025
	var bob = abs(swing) * 0.045 if moving else idle_breath

	if not action_active:
		visual_model.translation = Vector3(0, 1.05 + bob, 0)

	if visual_model.has_node("Head"):
		var head = visual_model.get_node("Head")
		head.rotation_degrees = Vector3(idle_breath * 16.0, swing * 2.0 if moving else 0.0, 0)
	if visual_model.has_node("LeftArm"):
		var left_arm = visual_model.get_node("LeftArm")
		if moving:
			left_arm.rotation_degrees = Vector3(swing * 20.0, 0, 76 + counter * 5.0)
		elif is_blocking:
			left_arm.rotation_degrees = Vector3(-18, 0, 64)
		else:
			left_arm.rotation_degrees = Vector3(idle_breath * 18.0, 0, 78)
	if visual_model.has_node("RightArm"):
		var right_arm = visual_model.get_node("RightArm")
		if moving:
			right_arm.rotation_degrees = Vector3(-swing * 20.0, 0, 104 - counter * 5.0)
		elif is_blocking:
			right_arm.rotation_degrees = Vector3(-22, 0, 116)
		else:
			right_arm.rotation_degrees = Vector3(-idle_breath * 18.0, 0, 102)
	if visual_model.has_node("LeftLeg"):
		var left_leg = visual_model.get_node("LeftLeg")
		left_leg.rotation_degrees = Vector3(-swing * 16.0 if moving else 0, 0, 0)
	if visual_model.has_node("RightLeg"):
		var right_leg = visual_model.get_node("RightLeg")
		right_leg.rotation_degrees = Vector3(swing * 16.0 if moving else 0, 0, 0)
	if visual_model.has_node("LowSpecHeroStyle"):
		var style = visual_model.get_node("LowSpecHeroStyle")
		style.rotation_degrees.z = swing * 1.6 if moving else idle_breath * 10.0

func _setup_character_visuals():
	if low_spec_mode:
		if has_node("Idle"):
			get_node("Idle").visible = false
		if has_node("Body"):
			visual_model = get_node("Body")
			visual_model.visible = true
			_build_low_spec_hero_style()
		else:
			visual_model = null
		skeleton = null
		anim_player = null
		warrior_style_root = null
		_ensure_low_spec_weapon_sockets()
		_build_pose_player()
		_refresh_weapon_attachments()
		return
	if has_node("Idle"):
		visual_model = get_node("Idle")
	else:
		visual_model = null
	if has_node("Body"):
		get_node("Body").visible = visual_model == null
	if visual_model == null:
		return
	if use_warrior_style:
		visual_model.scale = Vector3(1.04, 1.04, 1.04)
		visual_model.translation = Vector3(0, 0.01, 0)
		visual_model.rotation_degrees = Vector3(-1.5, 0, 0)
	skeleton = visual_model.find_node("Skeleton", true, false)
	anim_player = visual_model.find_node("AnimationPlayer", true, false)
	if anim_player:
		anim_player.playback_default_blend_time = 0.16
		_register_locomotion_animations()
	_build_warrior_style()
	_ensure_weapon_sockets()
	_build_pose_player()
	_refresh_weapon_attachments()
	_play_locomotion_animation("Idle")

func _register_locomotion_animations():
	if anim_player == null:
		return
	var animation_scenes = character_data.get("animation_scenes", {})
	var idle_scene_path = str(animation_scenes.get("idle", "res://Assets/Characters/Idle.fbx"))
	var walk_scene_path = str(animation_scenes.get("walk", "res://Assets/Characters/Walk.fbx"))
	var run_scene_path = str(animation_scenes.get("run", "res://Assets/Characters/Fast Run.fbx"))
	if anim_player.has_animation("Take 001") and not anim_player.has_animation("Idle"):
		anim_player.add_animation("Idle", anim_player.get_animation("Take 001").duplicate(true))
	if not anim_player.has_animation("Idle"):
		_load_animation_from_scene(idle_scene_path, "Idle")
	_load_animation_from_scene(walk_scene_path, "Walk")
	_load_animation_from_scene(run_scene_path, "Run")
	if not anim_player.has_animation("Walk") and anim_player.has_animation("Idle"):
		anim_player.add_animation("Walk", anim_player.get_animation("Idle").duplicate(true))
	if not anim_player.has_animation("Run") and anim_player.has_animation("Walk"):
		anim_player.add_animation("Run", anim_player.get_animation("Walk").duplicate(true))

func _load_animation_from_scene(scene_path, animation_name):
	if scene_path == "" or anim_player == null or anim_player.has_animation(animation_name):
		return
	var scene_resource = load(scene_path)
	if scene_resource == null or not scene_resource is PackedScene:
		return
	var instance = scene_resource.instance()
	if instance == null:
		return
	var source_player = instance.find_node("AnimationPlayer", true, false)
	if source_player == null:
		instance.queue_free()
		return
	var animation_list = source_player.get_animation_list()
	if animation_list.size() == 0:
		instance.queue_free()
		return
	var source_animation = source_player.get_animation(animation_list[0])
	if source_animation:
		anim_player.add_animation(animation_name, source_animation.duplicate(true))
	instance.queue_free()

func _build_warrior_style():
	if not use_warrior_style or visual_model == null:
		return
	if visual_model.has_node("WarriorStyle"):
		warrior_style_root = visual_model.get_node("WarriorStyle")
		if warrior_style_root.get_child_count() > 0:
			return
	else:
		warrior_style_root = Spatial.new()
		warrior_style_root.name = "WarriorStyle"
		visual_model.add_child(warrior_style_root)

	warrior_style_root.translation = Vector3.ZERO
	warrior_style_root.rotation_degrees = Vector3(-1.5, 0, 0)

	var skin_mat = _make_warrior_material(warrior_skin_tone, 0.62, 0.10)
	var cloth_mat = _make_warrior_material(warrior_cloth_tone, 0.78, 0.14)
	var wrap_mat = _make_warrior_material(warrior_wrap_tone, 0.70, 0.08)
	var hair_mat = _make_warrior_material(warrior_hair_tone, 0.40, 0.06)
	var mark_mat = _make_warrior_material(Color(0.78, 0.12, 0.09, 1.0), 0.45, 0.22)
	var gold_mat = _make_warrior_material(Color(0.82, 0.67, 0.26, 1.0), 0.32, 0.18, 0.65)
	var steel_mat = _make_warrior_material(Color(0.54, 0.56, 0.56, 1.0), 0.26, 0.16, 0.55)

	var torso_mesh = CapsuleMesh.new()
	torso_mesh.radius = 0.32
	torso_mesh.mid_height = 0.54
	_add_warrior_part("TorsoShell", torso_mesh, Vector3(0, 1.23, 0.02), Vector3(0, 0, 0), Vector3(1.36, 1.06, 0.70), skin_mat)

	var abs_mesh = CubeMesh.new()
	abs_mesh.size = Vector3(0.48, 0.32, 0.09)
	_add_warrior_part("AbsShell", abs_mesh, Vector3(0, 0.96, 0.20), Vector3(3, 0, 0), Vector3(1, 1, 1), skin_mat)

	var pec_mesh = SphereMesh.new()
	pec_mesh.radius = 0.13
	pec_mesh.height = 0.17
	_add_warrior_part("PecLeft", pec_mesh, Vector3(-0.13, 1.15, 0.23), Vector3(0, 0, 0), Vector3(1.05, 0.80, 0.60), skin_mat)
	_add_warrior_part("PecRight", pec_mesh, Vector3(0.13, 1.15, 0.23), Vector3(0, 0, 0), Vector3(1.05, 0.80, 0.60), skin_mat)

	var shoulder_mesh = CapsuleMesh.new()
	shoulder_mesh.radius = 0.11
	shoulder_mesh.mid_height = 0.28
	_add_warrior_part("ShoulderLeft", shoulder_mesh, Vector3(-0.47, 1.38, 0.01), Vector3(0, 0, 86), Vector3(1.08, 1.0, 1.0), skin_mat)
	_add_warrior_part("ShoulderRight", shoulder_mesh, Vector3(0.47, 1.38, 0.01), Vector3(0, 0, 94), Vector3(1.08, 1.0, 1.0), skin_mat)

	var mantle_mesh = CubeMesh.new()
	mantle_mesh.size = Vector3(0.48, 0.16, 0.04)
	_add_warrior_part("MantleLeft", mantle_mesh, Vector3(-0.34, 1.50, -0.08), Vector3(-8, -18, 0), Vector3(1.0, 1.0, 1.0), cloth_mat)
	_add_warrior_part("MantleRight", mantle_mesh, Vector3(0.34, 1.50, -0.08), Vector3(-8, 18, 0), Vector3(1.0, 1.0, 1.0), cloth_mat)
	_add_warrior_part("MantleCenter", mantle_mesh, Vector3(0, 1.48, -0.13), Vector3(-12, 0, 0), Vector3(1.08, 1.25, 1.0), cloth_mat)

	var armor_plate = CubeMesh.new()
	armor_plate.size = Vector3(0.24, 0.20, 0.045)
	for i in range(4):
		_add_warrior_part("ChestArmor%dL" % i, armor_plate, Vector3(-0.14, 1.31 - i * 0.09, 0.255), Vector3(-7, 0, 0), Vector3(1.04 - i * 0.04, 0.84, 1), steel_mat)
		_add_warrior_part("ChestArmor%dR" % i, armor_plate, Vector3(0.14, 1.31 - i * 0.09, 0.255), Vector3(-7, 0, 0), Vector3(1.04 - i * 0.04, 0.84, 1), steel_mat)

	var emblem_mesh = CylinderMesh.new()
	emblem_mesh.top_radius = 0.0
	emblem_mesh.bottom_radius = 0.11
	emblem_mesh.height = 0.04
	_add_warrior_part("ChestEmblem", emblem_mesh, Vector3(0, 1.22, 0.26), Vector3(90, 0, 0), Vector3(1, 1, 1), gold_mat)

	var forearm_mesh = CylinderMesh.new()
	forearm_mesh.top_radius = 0.078
	forearm_mesh.bottom_radius = 0.088
	forearm_mesh.height = 0.29
	_add_warrior_part("ForearmWrapL", forearm_mesh, Vector3(-0.54, 0.92, 0.04), Vector3(90, 0, 90), Vector3(1, 1, 1), wrap_mat)
	_add_warrior_part("ForearmWrapR", forearm_mesh, Vector3(0.54, 0.92, 0.04), Vector3(90, 0, 90), Vector3(1, 1, 1), wrap_mat)

	var waist_cloth = CubeMesh.new()
	waist_cloth.size = Vector3(0.58, 0.34, 0.045)
	_add_warrior_part("WaistWrapFront", waist_cloth, Vector3(0, 0.69, 0.20), Vector3(-8, 0, 0), Vector3(1, 1, 1), cloth_mat)
	_add_warrior_part("WaistWrapBack", waist_cloth, Vector3(0, 0.70, -0.19), Vector3(6, 0, 0), Vector3(1.0, 0.86, 1), cloth_mat)
	_add_warrior_part("WaistWrapSideL", waist_cloth, Vector3(-0.24, 0.73, 0.02), Vector3(0, 18, 0), Vector3(0.35, 0.70, 1), cloth_mat)
	_add_warrior_part("WaistWrapSideR", waist_cloth, Vector3(0.24, 0.73, 0.02), Vector3(0, -18, 0), Vector3(0.35, 0.70, 1), cloth_mat)

	var shin_mesh = CylinderMesh.new()
	shin_mesh.top_radius = 0.095
	shin_mesh.bottom_radius = 0.115
	shin_mesh.height = 0.35
	_add_warrior_part("ShinGuardL", shin_mesh, Vector3(-0.21, 0.34, 0.08), Vector3(0, 0, 0), Vector3(0.75, 0.84, 0.72), steel_mat)
	_add_warrior_part("ShinGuardR", shin_mesh, Vector3(0.21, 0.34, 0.08), Vector3(0, 0, 0), Vector3(0.75, 0.84, 0.72), steel_mat)

	var bun_mesh = SphereMesh.new()
	bun_mesh.radius = 0.12
	bun_mesh.height = 0.24
	_add_warrior_part("HairBun", bun_mesh, Vector3(0, 1.86, -0.18), Vector3(0, 0, 0), Vector3(1.04, 1.00, 1.02), hair_mat)
	var hair_tail = CylinderMesh.new()
	hair_tail.top_radius = 0.028
	hair_tail.bottom_radius = 0.022
	hair_tail.height = 0.26
	_add_warrior_part("HairTail", hair_tail, Vector3(0, 1.71, -0.18), Vector3(12, 0, 0), Vector3(1, 1, 1), hair_mat)

	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.024
	eye_mesh.height = 0.048
	var eye_mat = _make_warrior_material(Color(0.03, 0.025, 0.02, 1.0), 0.20, 0.10)
	_add_warrior_part("EyeLeft", eye_mesh, Vector3(-0.052, 1.915, 0.248), Vector3(0, 0, 0), Vector3(1, 0.72, 1), eye_mat)
	_add_warrior_part("EyeRight", eye_mesh, Vector3(0.052, 1.915, 0.248), Vector3(0, 0, 0), Vector3(1, 0.72, 1), eye_mat)

	var nose_mesh = CubeMesh.new()
	nose_mesh.size = Vector3(0.03, 0.12, 0.02)
	_add_warrior_part("NoseBridge", nose_mesh, Vector3(0, 1.83, 0.255), Vector3(-8, 0, 0), Vector3(1, 1, 1), skin_mat)

	var face_mark = CubeMesh.new()
	face_mark.size = Vector3(0.04, 0.16, 0.02)
	_add_warrior_part("ForeheadMark", face_mark, Vector3(0, 1.605, 0.265), Vector3(0, 0, 0), Vector3(1, 1, 1), mark_mat)

	var jaw_mesh = SphereMesh.new()
	jaw_mesh.radius = 0.095
	jaw_mesh.height = 0.13
	_add_warrior_part("Jawline", jaw_mesh, Vector3(0, 1.725, 0.215), Vector3(0, 0, 0), Vector3(1.12, 0.80, 0.84), skin_mat)

	var brow_mesh = CubeMesh.new()
	brow_mesh.size = Vector3(0.22, 0.05, 0.03)
	_add_warrior_part("BrowRidge", brow_mesh, Vector3(0, 1.895, 0.245), Vector3(0, 0, 0), Vector3(1, 1, 1), skin_mat)

	var armband_mesh = CylinderMesh.new()
	armband_mesh.top_radius = 0.07
	armband_mesh.bottom_radius = 0.07
	armband_mesh.height = 0.11
	_add_warrior_part("ArmbandLeft", armband_mesh, Vector3(-0.49, 1.16, 0.03), Vector3(90, 0, 90), Vector3(1, 1, 1), gold_mat)
	_add_warrior_part("ArmbandRight", armband_mesh, Vector3(0.49, 1.16, 0.03), Vector3(90, 0, 90), Vector3(1, 1, 1), gold_mat)

func _make_warrior_material(albedo_color, roughness, rim_strength, metallic_value = 0.0):
	var mat = ShaderMaterial.new()
	mat.shader = warrior_hybrid_shader
	mat.set_shader_param("albedo_tint", albedo_color)
	mat.set_shader_param("roughness_value", roughness)
	mat.set_shader_param("rim_strength", rim_strength)
	mat.set_shader_param("metallic_value", metallic_value)
	return mat

func _add_warrior_part(part_name, mesh, pos, rot, scl, material):
	var part = MeshInstance.new()
	part.name = part_name
	part.mesh = mesh
	part.translation = pos
	part.rotation_degrees = rot
	part.scale = scl
	part.material_override = material
	warrior_style_root.add_child(part)

func _build_low_spec_hero_style():
	if visual_model == null:
		return
	var body = visual_model
	body.mesh = null
	body.scale = Vector3(1.0, 1.0, 1.0)

	var skin_mat = _make_low_spec_material(warrior_skin_tone, 0.82)
	var cloth_mat = _make_low_spec_material(warrior_cloth_tone, 0.92)
	var sash_mat = _make_low_spec_material(Color(0.72, 0.08, 0.08, 1.0), 0.86)
	var gold_mat = _make_low_spec_material(Color(0.92, 0.70, 0.24, 1.0), 0.34, 0.36)
	var steel_mat = _make_low_spec_material(Color(0.62, 0.64, 0.62, 1.0), 0.30, 0.42)
	var hair_mat = _make_low_spec_material(warrior_hair_tone, 0.66)
	var eye_mat = _make_low_spec_material(Color(0.025, 0.020, 0.018, 1.0), 0.38)
	var mark_mat = _make_low_spec_material(Color(0.86, 0.12, 0.08, 1.0), 0.58)

	body.material_override = cloth_mat
	if body.has_node("Head"):
		var head = body.get_node("Head")
		head.translation = Vector3(0, 1.02, 0.03)
		head.scale = Vector3(0.38, 0.46, 0.36)
		head.material_override = skin_mat
	if body.has_node("LeftArm"):
		var left_arm = body.get_node("LeftArm")
		left_arm.translation = Vector3(-0.54, 0.20, 0.04)
		left_arm.rotation_degrees = Vector3(0, 0, 78)
		left_arm.scale = Vector3(0.22, 0.82, 0.22)
		left_arm.material_override = skin_mat
	if body.has_node("RightArm"):
		var right_arm = body.get_node("RightArm")
		right_arm.translation = Vector3(0.54, 0.20, 0.04)
		right_arm.rotation_degrees = Vector3(0, 0, 102)
		right_arm.scale = Vector3(0.22, 0.82, 0.22)
		right_arm.material_override = skin_mat
	if body.has_node("LeftLeg"):
		var left_leg = body.get_node("LeftLeg")
		left_leg.translation = Vector3(-0.20, -0.95, 0.01)
		left_leg.scale = Vector3(0.28, 1.10, 0.27)
		left_leg.material_override = skin_mat
	if body.has_node("RightLeg"):
		var right_leg = body.get_node("RightLeg")
		right_leg.translation = Vector3(0.20, -0.95, 0.01)
		right_leg.scale = Vector3(0.28, 1.10, 0.27)
		right_leg.material_override = skin_mat

	if body.has_node("LowSpecHeroStyle"):
		return
	var root = Spatial.new()
	root.name = "LowSpecHeroStyle"
	body.add_child(root)

	var chest = CapsuleMesh.new()
	chest.radius = 0.32
	chest.mid_height = 0.42
	_add_low_spec_part(root, "HeroChest", chest, Vector3(0, 0.28, 0.16), Vector3(0, 0, 0), Vector3(1.28, 0.92, 0.62), skin_mat)

	var chest_plate = CubeMesh.new()
	chest_plate.size = Vector3(0.25, 0.18, 0.04)
	for i in range(3):
		_add_low_spec_part(root, "ChestPlate%dL" % i, chest_plate, Vector3(-0.13, 0.45 - i * 0.11, 0.39), Vector3(-8, 0, 0), Vector3(1.0 - i * 0.08, 0.78, 1), steel_mat)
		_add_low_spec_part(root, "ChestPlate%dR" % i, chest_plate, Vector3(0.13, 0.45 - i * 0.11, 0.39), Vector3(-8, 0, 0), Vector3(1.0 - i * 0.08, 0.78, 1), steel_mat)

	var collar = CubeMesh.new()
	collar.size = Vector3(0.68, 0.12, 0.055)
	_add_low_spec_part(root, "HeroCollarGold", collar, Vector3(0, 0.68, 0.34), Vector3(-8, 0, 0), Vector3(1, 1, 1), gold_mat)

	var shoulder = SphereMesh.new()
	shoulder.radius = 0.16
	shoulder.height = 0.24
	_add_low_spec_part(root, "LeftHeroShoulder", shoulder, Vector3(-0.55, 0.43, 0.06), Vector3(0, 0, 0), Vector3(1.24, 0.70, 1.0), gold_mat)
	_add_low_spec_part(root, "RightHeroShoulder", shoulder, Vector3(0.55, 0.43, 0.06), Vector3(0, 0, 0), Vector3(1.24, 0.70, 1.0), gold_mat)

	var abs_line = CubeMesh.new()
	abs_line.size = Vector3(0.045, 0.34, 0.03)
	_add_low_spec_part(root, "HeroAbCenter", abs_line, Vector3(0, 0.03, 0.42), Vector3(-5, 0, 0), Vector3(1, 1, 1), _make_low_spec_material(Color(0.64, 0.47, 0.38, 1.0), 0.88))
	var ab_cut = CubeMesh.new()
	ab_cut.size = Vector3(0.20, 0.030, 0.03)
	for j in range(3):
		_add_low_spec_part(root, "HeroAbCut%dL" % j, ab_cut, Vector3(-0.12, 0.14 - j * 0.12, 0.43), Vector3(-5, 0, -8), Vector3(1, 1, 1), skin_mat)
		_add_low_spec_part(root, "HeroAbCut%dR" % j, ab_cut, Vector3(0.12, 0.14 - j * 0.12, 0.43), Vector3(-5, 0, 8), Vector3(1, 1, 1), skin_mat)

	var sash = CubeMesh.new()
	sash.size = Vector3(0.72, 0.22, 0.055)
	_add_low_spec_part(root, "HeroWaistSash", sash, Vector3(0, -0.43, 0.33), Vector3(-8, 0, 0), Vector3(1, 1, 1), sash_mat)
	_add_low_spec_part(root, "HeroDrape", sash, Vector3(0.18, -0.70, 0.36), Vector3(-10, 0, -7), Vector3(0.42, 1.22, 1), sash_mat)

	var bracer = CylinderMesh.new()
	bracer.top_radius = 0.090
	bracer.bottom_radius = 0.095
	bracer.height = 0.24
	bracer.radial_segments = 8
	_add_low_spec_part(root, "LeftBracer", bracer, Vector3(-0.62, -0.02, 0.10), Vector3(90, 0, 90), Vector3(1, 1, 1), gold_mat)
	_add_low_spec_part(root, "RightBracer", bracer, Vector3(0.62, -0.02, 0.10), Vector3(90, 0, 90), Vector3(1, 1, 1), gold_mat)

	var eye = SphereMesh.new()
	eye.radius = 0.025
	eye.height = 0.045
	_add_low_spec_part(root, "HeroEyeLeft", eye, Vector3(-0.065, 1.08, 0.36), Vector3(0, 0, 0), Vector3(1.0, 0.70, 1.0), eye_mat)
	_add_low_spec_part(root, "HeroEyeRight", eye, Vector3(0.065, 1.08, 0.36), Vector3(0, 0, 0), Vector3(1.0, 0.70, 1.0), eye_mat)

	var brow = CubeMesh.new()
	brow.size = Vector3(0.23, 0.035, 0.024)
	_add_low_spec_part(root, "HeroBrow", brow, Vector3(0, 1.12, 0.355), Vector3(0, 0, 0), Vector3(1, 1, 1), hair_mat)

	var nose = CubeMesh.new()
	nose.size = Vector3(0.035, 0.11, 0.026)
	_add_low_spec_part(root, "HeroNose", nose, Vector3(0, 1.01, 0.385), Vector3(-8, 0, 0), Vector3(1, 1, 1), skin_mat)

	var jaw = SphereMesh.new()
	jaw.radius = 0.10
	jaw.height = 0.13
	_add_low_spec_part(root, "HeroJaw", jaw, Vector3(0, 0.91, 0.315), Vector3(0, 0, 0), Vector3(1.20, 0.72, 0.82), skin_mat)

	var face_mark = CubeMesh.new()
	face_mark.size = Vector3(0.035, 0.14, 0.018)
	_add_low_spec_part(root, "HeroTilak", face_mark, Vector3(0, 1.15, 0.39), Vector3(0, 0, 0), Vector3(1, 1, 1), mark_mat)

	var hair = SphereMesh.new()
	hair.radius = 0.18
	hair.height = 0.20
	_add_low_spec_part(root, "HeroHairCap", hair, Vector3(0, 1.27, -0.02), Vector3(0, 0, 0), Vector3(1.20, 0.55, 1.06), hair_mat)
	var bun = SphereMesh.new()
	bun.radius = 0.12
	bun.height = 0.20
	_add_low_spec_part(root, "HeroHairBun", bun, Vector3(0, 1.34, -0.22), Vector3(0, 0, 0), Vector3(1.0, 1.0, 1.0), hair_mat)

	var necklace = TorusMesh.new()
	necklace.inner_radius = 0.20
	necklace.outer_radius = 0.235
	necklace.ring_segments = 24
	_add_low_spec_part(root, "HeroNecklace", necklace, Vector3(0, 0.76, 0.25), Vector3(74, 0, 0), Vector3(1, 0.70, 1), gold_mat)

func _make_low_spec_material(albedo_color, roughness = 0.8, metallic_value = 0.0):
	var mat = SpatialMaterial.new()
	mat.albedo_color = albedo_color
	mat.roughness = roughness
	mat.metallic = metallic_value
	return mat

func _add_low_spec_part(parent, part_name, mesh, pos, rot, scl, material):
	var part = MeshInstance.new()
	part.name = part_name
	part.mesh = mesh
	part.translation = pos
	part.rotation_degrees = rot
	part.scale = scl
	part.material_override = material
	parent.add_child(part)
	return part

func _build_pose_player():
	if pose_anim_player == null:
		if has_node("PosePlayer"):
			pose_anim_player = get_node("PosePlayer")
		else:
			pose_anim_player = AnimationPlayer.new()
			pose_anim_player.name = "PosePlayer"
			add_child(pose_anim_player)
	pose_anim_player.playback_default_blend_time = 0.10
	var pose_names = ["Attack1", "Attack2", "Attack3", "Jump", "Victory", "Hit", "Dodge", "Block"]
	for pose_name in pose_names:
		if not pose_anim_player.has_animation(pose_name):
			pose_anim_player.add_animation(pose_name, _create_pose_animation(pose_name))

func _animation_property_path(node, property_name):
	if node == null:
		return NodePath("Idle:%s" % property_name)
	return NodePath("%s:%s" % [str(get_path_to(node)), property_name])

func _create_pose_animation(animation_name):
	var animation = Animation.new()
	animation.length = 0.50
	animation.loop = false

	var model_path = NodePath("Idle:rotation_degrees")
	var model_translation_path = NodePath("Idle:translation")
	var hand_path = NodePath("Idle:rotation_degrees")
	var back_path = NodePath("Idle:rotation_degrees")

	if visual_model:
		model_path = _animation_property_path(visual_model, "rotation_degrees")
		model_translation_path = _animation_property_path(visual_model, "translation")
	if weapon_hand_socket:
		hand_path = _animation_property_path(weapon_hand_socket, "rotation_degrees")
	if weapon_back_socket:
		back_path = _animation_property_path(weapon_back_socket, "rotation_degrees")

	var model_rotation_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(model_rotation_track, model_path)
	var model_translation_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(model_translation_track, model_translation_path)
	var hand_rotation_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(hand_rotation_track, hand_path)
	var back_rotation_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(back_rotation_track, back_path)
	var model_base_translation = visual_model.translation if visual_model else Vector3.ZERO

	if animation_name.begins_with("Attack"):
		var attack_id = int(animation_name.replace("Attack", ""))
		var twist = 9.0 + attack_id * 8.0
		var dip = 0.025 + attack_id * 0.012
		animation.length = 0.44 + attack_id * 0.06
		animation.track_insert_key(model_rotation_track, 0.0, Vector3(0, 0, 0))
		animation.track_insert_key(model_rotation_track, 0.12, Vector3(-4 - attack_id, twist, 0))
		animation.track_insert_key(model_rotation_track, animation.length, Vector3(0, 0, 0))
		animation.track_insert_key(model_translation_track, 0.0, model_base_translation)
		animation.track_insert_key(model_translation_track, 0.12, model_base_translation + Vector3(0, -dip, 0.05 + attack_id * 0.02))
		animation.track_insert_key(model_translation_track, animation.length, model_base_translation)
		animation.track_insert_key(hand_rotation_track, 0.0, Vector3(0, 0, 0))
		animation.track_insert_key(hand_rotation_track, 0.12, Vector3(-20, 4 + attack_id * 4, 13 + attack_id * 8))
		animation.track_insert_key(hand_rotation_track, animation.length, Vector3(0, 0, 0))
		animation.track_insert_key(back_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(back_rotation_track, animation.length, Vector3.ZERO)
	elif animation_name == "Dodge":
		animation.length = 0.30
		animation.track_insert_key(model_rotation_track, 0.0, Vector3(0, 0, 0))
		animation.track_insert_key(model_rotation_track, 0.12, Vector3(-12, 0, -9))
		animation.track_insert_key(model_rotation_track, 0.30, Vector3.ZERO)
		animation.track_insert_key(model_translation_track, 0.0, model_base_translation)
		animation.track_insert_key(model_translation_track, 0.12, model_base_translation + Vector3(0, -0.16, -0.08))
		animation.track_insert_key(model_translation_track, 0.30, model_base_translation)
		animation.track_insert_key(hand_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(hand_rotation_track, 0.30, Vector3.ZERO)
		animation.track_insert_key(back_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(back_rotation_track, 0.30, Vector3.ZERO)
	elif animation_name == "Hit":
		animation.length = 0.34
		animation.track_insert_key(model_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(model_rotation_track, 0.08, Vector3(8, -12, 0))
		animation.track_insert_key(model_rotation_track, 0.34, Vector3.ZERO)
		animation.track_insert_key(model_translation_track, 0.0, model_base_translation)
		animation.track_insert_key(model_translation_track, 0.08, model_base_translation + Vector3(0, 0.02, -0.08))
		animation.track_insert_key(model_translation_track, 0.34, model_base_translation)
		animation.track_insert_key(hand_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(hand_rotation_track, 0.34, Vector3.ZERO)
		animation.track_insert_key(back_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(back_rotation_track, 0.34, Vector3.ZERO)
	elif animation_name == "Jump":
		animation.length = 0.45
		animation.track_insert_key(model_rotation_track, 0.0, Vector3(0, 0, 0))
		animation.track_insert_key(model_rotation_track, 0.12, Vector3(-10, 0, 0))
		animation.track_insert_key(model_rotation_track, 0.45, Vector3(0, 0, 0))
		animation.track_insert_key(model_translation_track, 0.0, model_base_translation)
		animation.track_insert_key(model_translation_track, 0.12, model_base_translation + Vector3(0, -0.08, 0))
		animation.track_insert_key(model_translation_track, 0.24, model_base_translation + Vector3(0, 0.08, 0))
		animation.track_insert_key(model_translation_track, 0.45, model_base_translation)
		animation.track_insert_key(hand_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(hand_rotation_track, 0.45, Vector3.ZERO)
		animation.track_insert_key(back_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(back_rotation_track, 0.45, Vector3.ZERO)
	else:
		animation.track_insert_key(model_rotation_track, 0.0, Vector3(0, 0, 0))
		animation.track_insert_key(model_rotation_track, 0.18, Vector3(-6, 20, 0))
		animation.track_insert_key(model_rotation_track, 0.45, Vector3(-2, 12, 0))
		animation.track_insert_key(model_translation_track, 0.0, model_base_translation)
		animation.track_insert_key(model_translation_track, 0.18, model_base_translation + Vector3(0, -0.02, 0.02))
		animation.track_insert_key(model_translation_track, 0.45, model_base_translation)
		animation.track_insert_key(hand_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(hand_rotation_track, 0.18, Vector3(-12, 0, 24))
		animation.track_insert_key(hand_rotation_track, 0.45, Vector3(-6, 0, 12))
		animation.track_insert_key(back_rotation_track, 0.0, Vector3.ZERO)
		animation.track_insert_key(back_rotation_track, 0.45, Vector3.ZERO)
	return animation

func _ensure_weapon_sockets():
	if skeleton == null:
		return
	if weapon_hand_socket == null:
		if skeleton.has_node("RightHandSocket"):
			weapon_hand_socket = skeleton.get_node("RightHandSocket")
		else:
			weapon_hand_socket = BoneAttachment.new()
			weapon_hand_socket.name = "RightHandSocket"
			weapon_hand_socket.bone_name = "mixamorigRightHand"
			weapon_hand_socket.translation = Vector3(0.04, -0.03, 0.07)
			skeleton.add_child(weapon_hand_socket)
	if weapon_back_socket == null:
		if skeleton.has_node("BackSocket"):
			weapon_back_socket = skeleton.get_node("BackSocket")
		else:
			weapon_back_socket = BoneAttachment.new()
			weapon_back_socket.name = "BackSocket"
			weapon_back_socket.bone_name = "mixamorigSpine2"
			weapon_back_socket.translation = Vector3(-0.10, 0.08, -0.14)
			weapon_back_socket.rotation_degrees = Vector3(12, 0, 20)
			skeleton.add_child(weapon_back_socket)

func _refresh_weapon_attachments():
	if inventory.size() == 0:
		return
	if weapon_hand_socket == null and weapon_back_socket == null:
		return
	for idx in range(inventory.size()):
		var weapon = inventory[idx]["node"]
		if weapon == null:
			continue
		var target_socket = weapon_back_socket
		if idx == equipped_index:
			target_socket = weapon_hand_socket
		if target_socket == null:
			continue
		if weapon.get_parent() != target_socket:
			var previous_parent = weapon.get_parent()
			if previous_parent:
				previous_parent.remove_child(weapon)
			target_socket.add_child(weapon)
		if weapon is Spatial:
			weapon.translation = Vector3.ZERO
			weapon.rotation_degrees = Vector3.ZERO
			weapon.scale = Vector3(1, 1, 1)
			if weapon.has_method("set_attachment_state"):
				weapon.call("set_attachment_state", "hand" if idx == equipped_index else "back")

func _play_locomotion_animation(animation_name):
	if anim_player == null:
		return
	var chosen_animation = animation_name
	if not anim_player.has_animation(chosen_animation):
		if anim_player.has_animation("Idle"):
			chosen_animation = "Idle"
		elif anim_player.get_animation_list().size() > 0:
			chosen_animation = str(anim_player.get_animation_list()[0])
	if chosen_animation == current_locomotion_animation:
		return
	current_locomotion_animation = chosen_animation
	anim_player.play(chosen_animation)

func _play_action_pose(pose_name):
	if pose_anim_player == null:
		return
	if not pose_anim_player.has_animation(pose_name) and pose_name.begins_with("Attack"):
		pose_name = "Attack1"
	if not pose_anim_player.has_animation(pose_name):
		return
	pose_anim_player.play(pose_name)

func play_victory_pose():
	_play_action_pose("Victory")

func _ensure_low_spec_weapon_sockets():
	if not has_node("Body"):
		return
	var body = get_node("Body")
	if low_spec_hand_socket == null or not is_instance_valid(low_spec_hand_socket):
		if body.has_node("LowSpecHandSocket"):
			low_spec_hand_socket = body.get_node("LowSpecHandSocket")
		else:
			low_spec_hand_socket = Spatial.new()
			low_spec_hand_socket.name = "LowSpecHandSocket"
			low_spec_hand_socket.translation = Vector3(0.60, 0.18, 0.34)
			low_spec_hand_socket.rotation_degrees = Vector3(0, -10, 6)
			body.add_child(low_spec_hand_socket)
	if low_spec_back_socket == null or not is_instance_valid(low_spec_back_socket):
		if body.has_node("LowSpecBackSocket"):
			low_spec_back_socket = body.get_node("LowSpecBackSocket")
		else:
			low_spec_back_socket = Spatial.new()
			low_spec_back_socket.name = "LowSpecBackSocket"
			low_spec_back_socket.translation = Vector3(-0.18, 0.34, -0.46)
			low_spec_back_socket.rotation_degrees = Vector3(8, 28, 145)
			body.add_child(low_spec_back_socket)
	weapon_hand_socket = low_spec_hand_socket
	weapon_back_socket = low_spec_back_socket

func add_progression_reward(xp_amount = 25, special_amount = 18):
	xp += int(xp_amount)
	special_meter = min(special_max, special_meter + float(special_amount))
	var leveled = false
	while xp >= xp_next:
		xp -= xp_next
		player_level += 1
		xp_next = int(float(xp_next) * 1.22) + 20
		max_health += 8
		health = min(max_health, health + 22)
		melee_damage += 2
		leveled = true
	if leveled:
		_notify_combat("Level %d" % player_level, Color(0.96, 0.78, 0.30))
		_play_action_pose("Victory")
	_update_hud_character()
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_health"):
			hud.call_deferred("set_health", health)
	_update_hud_progression()

func _try_special_ability():
	if special_meter < special_max or special_cooldown > 0.0 or dodge_timer > 0.0 or hit_reaction_timer > 0.0:
		if special_meter < special_max:
			_notify_combat("Resolve not ready", Color(0.78, 0.90, 0.92))
		return
	special_meter = 0.0
	special_cooldown = 1.4
	var radius = 7.2
	var damage_amount = melee_damage + 58 + player_level * 4
	var healed = int(max_health * 0.18)
	health = min(max_health, health + healed)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var flat = enemy.global_transform.origin - global_transform.origin
		flat.y = 0
		if flat.length() <= radius and enemy.has_method("apply_damage"):
			enemy.apply_damage(damage_amount, self, 0.72)
	_spawn_special_vfx(radius)
	_play_action_pose("Victory")
	_shake_camera(0.34, 0.22, 5.0)
	_notify_combat("%s awakened" % character_name, Color(0.96, 0.78, 0.30))
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_health"):
			hud.call_deferred("set_health", health)
	_update_hud_progression()

func _spawn_special_vfx(radius):
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var root = Spatial.new()
	root.name = "ResolveBurst"
	root.translation = global_transform.origin + Vector3.UP * 0.22
	current.add_child(root)
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(0.96, 0.72, 0.22, 0.42)
	mat.emission_enabled = true
	mat.emission = Color(0.96, 0.48, 0.08)
	mat.flags_transparent = true
	var ring = MeshInstance.new()
	var torus = TorusMesh.new()
	torus.inner_radius = radius * 0.44
	torus.outer_radius = radius * 0.50
	torus.ring_segments = 36 if low_spec_mode else 72
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.material_override = mat
	root.add_child(ring)
	for i in range(8 if low_spec_mode else 16):
		var ray = MeshInstance.new()
		var mesh = CubeMesh.new()
		mesh.size = Vector3(0.06, 0.035, radius * 0.82)
		ray.mesh = mesh
		var angle = float(i) / float(8 if low_spec_mode else 16) * TAU
		ray.translation = Vector3(sin(angle), 0.04, -cos(angle)) * radius * 0.22
		ray.rotation_degrees.y = rad2deg(angle)
		ray.material_override = mat
		root.add_child(ray)
	yield(get_tree().create_timer(0.36), "timeout")
	if is_instance_valid(root):
		root.queue_free()

func _update_hud_progression():
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_progression"):
			hud.call_deferred("set_progression", player_level, xp, xp_next, special_meter, special_max)

func get_progression_state():
	return {
		"level": player_level,
		"xp": xp,
		"xp_next": xp_next,
		"special": special_meter,
		"health": health,
		"max_health": max_health,
		"melee_damage": melee_damage
	}

func restore_progression_state(data):
	if data == null:
		return
	player_level = int(data.get("level", player_level))
	xp = int(data.get("xp", xp))
	xp_next = int(data.get("xp_next", xp_next))
	special_meter = float(data.get("special", special_meter))
	max_health = int(data.get("max_health", max_health))
	health = int(data.get("health", health))
	melee_damage = int(data.get("melee_damage", melee_damage))
	_update_hud_character()
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_health"):
			hud.call_deferred("set_health", health)
	_update_hud_progression()

func set_checkpoint_position(pos):
	respawn_position = pos

func reset_progression():
	player_level = 1
	xp = 0
	xp_next = 100
	special_meter = 35.0
	special_cooldown = 0.0
	health = max_health
	guard_value = guard_max
	_update_hud_character()
	_update_hud_progression()

func apply_damage(dmg, source = null):
	if invincible_timer > 0.0:
		_spawn_evade_fx()
		return
	var blocked = false
	var final_damage = dmg
	if is_blocking and guard_value > 0.0 and _is_source_in_front(source):
		blocked = true
		guard_value = max(0.0, guard_value - float(dmg) * 1.35)
		final_damage = int(ceil(float(dmg) * block_damage_multiplier))
		_spawn_block_fx()
		_play_damage_sound()
		_shake_camera(0.12, 0.10, 1.0)
		_notify_combat("Blocked", Color(0.58, 0.86, 1.0))
		if guard_value <= 0.0:
			blocked = false
			final_damage = dmg
			hit_reaction_timer = 0.42
			_notify_combat("Guard broken", Color(1.0, 0.32, 0.18))
	if not blocked:
		hit_reaction_timer = 0.28
		_play_action_pose("Hit")
		_spawn_damage_fx()
		_shake_camera(0.24, 0.16, 3.2)
	health -= final_damage
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_health"):
			hud.call_deferred("set_health", health)
		if hud and hud.has_method("pulse_crosshair"):
			hud.call_deferred("pulse_crosshair")
		if hud and hud.has_method("set_guard"):
			hud.call_deferred("set_guard", guard_value, guard_max)
	_play_damage_sound()
	if health <= 0:
		die()

func _is_source_in_front(source):
	if source == null or not is_instance_valid(source):
		return true
	var to_source = source.global_transform.origin - global_transform.origin
	to_source.y = 0
	if to_source.length() <= 0.05:
		return true
	return _get_forward_vector().dot(to_source.normalized()) > 0.20

func die():
	health = max_health
	guard_value = guard_max
	translation = respawn_position
	velocity = Vector3.ZERO
	_play_death_sound()
	_notify_combat("You were overwhelmed. The checkpoint flame restores you.", Color(1.0, 0.45, 0.28))
	var gm_scene = get_tree().get_current_scene()
	if gm_scene and gm_scene.has_node("GameManager"):
		var gm = gm_scene.get_node("GameManager")
		if gm and gm.has_method("on_player_defeated"):
			gm.on_player_defeated()
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_health"):
			hud.call_deferred("set_health", health)
		if hud and hud.has_method("set_guard"):
			hud.call_deferred("set_guard", guard_value, guard_max)

func _update_hud_guard():
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_guard"):
			hud.call_deferred("set_guard", guard_value, guard_max)

func _update_hud_target():
	var current = get_tree().get_current_scene()
	if current == null or not current.has_node("HUD"):
		return
	var hud = current.get_node("HUD")
	if hud == null or not hud.has_method("set_target_health"):
		return
	if combat_target and is_instance_valid(combat_target):
		var target_name = "Enemy Warrior"
		if combat_target.has_method("get_display_name"):
			target_name = combat_target.get_display_name()
		var target_health = int(combat_target.get("health"))
		var target_max = int(combat_target.get("max_health"))
		hud.call_deferred("set_target_health", target_name, target_health, target_max)
	else:
		hud.call_deferred("set_target_health", "", 0, 0)

func _pulse_combat_feedback():
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("pulse_crosshair"):
			hud.call_deferred("pulse_crosshair")

func _notify_combat(message, color):
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("show_combat_feedback"):
			hud.call_deferred("show_combat_feedback", message, color)

func _shake_camera(strength, duration, fov_amount = 0.0):
	if camera == null or not is_instance_valid(camera):
		return
	if camera.has_method("shake"):
		camera.shake(strength, duration)
	if fov_amount > 0.0 and camera.has_method("add_fov_kick"):
		camera.add_fov_kick(fov_amount)

func _spawn_slash_vfx(hit):
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var root = Spatial.new()
	root.name = "SlashVFX"
	root.translation = global_transform.origin + Vector3.UP * 1.15 + _get_forward_vector() * 1.10
	root.rotation.y = atan2(_get_forward_vector().x, -_get_forward_vector().z)
	current.add_child(root)

	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(1.0, 0.75, 0.30, 0.68) if hit else Color(0.65, 0.78, 1.0, 0.38)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.54, 0.18) if hit else Color(0.35, 0.62, 1.0)
	mat.emission_energy = 1.2 if hit else 0.55
	mat.flags_transparent = true

	var slash_count = 4 if low_spec_mode else 9
	for i in range(slash_count):
		var shard = MeshInstance.new()
		var mesh = CubeMesh.new()
		mesh.size = Vector3(0.10, 0.022, 0.46)
		shard.mesh = mesh
		var angle = deg2rad(-52.0 + float(i) * 13.0)
		shard.translation = Vector3(sin(angle) * 0.62, sin(float(i) * 0.7) * 0.12, -cos(angle) * 0.62)
		shard.rotation_degrees = Vector3(0, rad2deg(angle), 18.0 - i * 4.0)
		shard.scale = Vector3(1.0 + i * 0.04, 1.0, 1.0)
		shard.material_override = mat
		root.add_child(shard)
	yield(get_tree().create_timer(0.14 if hit else 0.08), "timeout")
	if is_instance_valid(root):
		root.queue_free()

func _spawn_dodge_dust():
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var dust = Particles.new()
	dust.name = "DodgeDust"
	dust.amount = 8 if low_spec_mode else 38
	dust.lifetime = 0.42
	dust.one_shot = true
	dust.explosiveness = 0.72
	dust.translation = global_transform.origin + Vector3.UP * 0.18
	var material = ParticlesMaterial.new()
	material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.36
	material.gravity = Vector3(0, -2.4, 0)
	material.initial_velocity = 2.0
	material.initial_velocity_random = 0.55
	material.scale = 0.14
	material.scale_random = 0.62
	material.color = Color(0.70, 0.60, 0.46, 0.44)
	dust.process_material = material
	var mesh = SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	dust.draw_pass_1 = mesh
	current.add_child(dust)
	dust.emitting = true
	yield(get_tree().create_timer(0.65), "timeout")
	if is_instance_valid(dust):
		dust.queue_free()

func _spawn_block_fx():
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var fx = Particles.new()
	fx.name = "BlockSparks"
	fx.amount = 10 if low_spec_mode else 48
	fx.lifetime = 0.34
	fx.one_shot = true
	fx.explosiveness = 0.88
	fx.translation = global_transform.origin + Vector3.UP * 1.20 + _get_forward_vector() * 0.72
	var material = ParticlesMaterial.new()
	material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.10
	material.gravity = Vector3(0, -1.0, 0)
	material.initial_velocity = 3.2
	material.initial_velocity_random = 0.65
	material.scale = 0.075
	material.scale_random = 0.45
	material.color = Color(0.62, 0.88, 1.0, 0.85)
	fx.process_material = material
	var mesh = SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	fx.draw_pass_1 = mesh
	current.add_child(fx)
	fx.emitting = true
	yield(get_tree().create_timer(0.50), "timeout")
	if is_instance_valid(fx):
		fx.queue_free()

func _spawn_damage_fx():
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var fx = Particles.new()
	fx.name = "PlayerHitSparks"
	fx.amount = 8 if low_spec_mode else 34
	fx.lifetime = 0.38
	fx.one_shot = true
	fx.explosiveness = 0.85
	fx.translation = global_transform.origin + Vector3.UP * 1.05
	var material = ParticlesMaterial.new()
	material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.22
	material.gravity = Vector3(0, -2.1, 0)
	material.initial_velocity = 2.2
	material.initial_velocity_random = 0.72
	material.scale = 0.08
	material.scale_random = 0.55
	material.color = Color(1.0, 0.24, 0.12, 0.70)
	fx.process_material = material
	var mesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	fx.draw_pass_1 = mesh
	current.add_child(fx)
	fx.emitting = true
	yield(get_tree().create_timer(0.52), "timeout")
	if is_instance_valid(fx):
		fx.queue_free()

func _spawn_evade_fx():
	_notify_combat("Evaded", Color(0.70, 0.88, 1.0))

func _play_fire_sound():
	var current = get_tree().get_current_scene()
	if current == null or not current.has_node("GameManager"):
		return
	var gm = current.get_node("GameManager")
	if gm and gm.has_method("play_fire_sound"):
		gm.play_fire_sound()

func _play_damage_sound():
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
