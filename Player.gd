extends KinematicBody

export (int) var walk_speed = 8
export (int) var run_speed = 14
var speed = walk_speed
export (int) var jump_speed = 7
var velocity = Vector3()
var gravity = 20

export (int) var max_health = 100
var health = max_health

onready var bullet_scene = preload("res://Scenes/Bullet.tscn")
var shoot_cooldown = 0.28
var shoot_timer = 0.0

var anim_player = null
var camera = null
var inventory = []
var equipped_index = -1
var equipped_weapon = null

func _ready():
	health = max_health
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_health"):
			hud.call_deferred("set_health", health)
	# find camera and animation player safely
	# camera: use current scene's Camera node
	if current and current.has_node("Camera"):
		camera = current.get_node("Camera")
	else:
		camera = null
	# animation player inside the imported model instance `Idle`
	if has_node("Idle"):
		var idle_node = get_node("Idle")
		anim_player = idle_node.find_node("AnimationPlayer", true, false)
		if not anim_player:
			anim_player = idle_node.find_node("AnimationTree", true, false)


func _physics_process(delta):
	if Input.is_key_pressed(KEY_SHIFT):
		speed = run_speed
	else:
		speed = walk_speed

	var direction = Vector3()

	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_up"):
		direction.z -= 1
	if Input.is_action_pressed("ui_down"):
		direction.z += 1

	direction = direction.normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if is_on_floor():
		if Input.is_action_just_pressed("ui_accept"):
			velocity.y = jump_speed
	else:
		velocity.y -= gravity * delta

	velocity = move_and_slide(velocity, Vector3.UP)

	# Shooting
	shoot_timer -= delta
	var is_shooting = false
	if Input.is_mouse_button_pressed(BUTTON_LEFT) and shoot_timer <= 0:
		shoot()
		shoot_timer = shoot_cooldown
		is_shooting = true

	# Animation handling (basic)
	_update_animation(direction, is_shooting)

func shoot():
	# use equipped weapon if available
	if equipped_weapon != null and equipped_weapon.has_method("fire"):
		var origin = Transform()
		var dir = -global_transform.basis.z
		# prefer camera direction if available
		var current = get_tree().get_current_scene()
		if current and current.has_node("Camera"):
			var cam = current.get_node("Camera")
			origin = cam.global_transform
			dir = (cam.global_transform.basis.z * -1).normalized()
		else:
			origin = global_transform
			dir = -global_transform.basis.z
		equipped_weapon.fire(origin, dir)
	else:
		# fallback: spawn simple bullet
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
		# hide model for now (weapon can be visualized later)
		instance.set_physics_process(true)
		inventory.append({"node": instance, "name": name})
		# auto-equip first weapon
		if equipped_index == -1:
			equip_weapon(0)
		# update HUD weapon bar
		var current = get_tree().get_current_scene()
		if current and current.has_node("HUD"):
			var hud = current.get_node("HUD")
			if hud and hud.has_method("add_weapon_slot"):
				hud.call_deferred("add_weapon_slot", name, inventory.size() - 1)

func equip_weapon(idx):
	if idx < 0 or idx >= inventory.size():
		return
	equipped_index = idx
	equipped_weapon = inventory[idx]["node"]
	# update HUD
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

func _update_animation(direction, shooting):
	if not anim_player:
		return
	var speed_val = direction.length()
	# prefer animations in this order
	var run_names = ["Fast Run", "Run", "RunCycle"]
	var walk_names = ["Walk", "walk"]
	var idle_names = ["Idle", "idle", "Idle_0"]
	var shoot_names = ["Shoot", "Fire", "shoot"]

	if shooting:
		for n in shoot_names:
			if anim_player.has_animation(n):
				anim_player.play(n)
				return
	if speed_val > 0.6:
		for n in run_names:
			if anim_player.has_animation(n):
				anim_player.play(n)
				return
	elif speed_val > 0.05:
		for n in walk_names:
			if anim_player.has_animation(n):
				anim_player.play(n)
				return
	# default to idle
	for n in idle_names:
		if anim_player.has_animation(n):
			anim_player.play(n)
			return

func apply_damage(dmg):
	health -= dmg
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_health"):
			hud.call_deferred("set_health", health)
	if health <= 0:
		die()

func die():
	# simple respawn; can be expanded later
	health = max_health
	translation = Vector3(0,3,0)
	var current = get_tree().get_current_scene()
	if current and current.has_node("HUD"):
		var hud = current.get_node("HUD")
		if hud and hud.has_method("set_health"):
			hud.call_deferred("set_health", health)
