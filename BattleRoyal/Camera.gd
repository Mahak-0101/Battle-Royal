extends Camera

export (NodePath) var player_path
export (float) var follow_distance = 7.8
export (float) var min_distance = 3.2
export (float) var max_distance = 10.8
export (float) var shoulder_offset = 0.82
export (float) var pivot_height = 1.65
export (float) var smooth_speed = 11.0
export (float) var rotation_smooth_speed = 12.0
export (float) var mouse_sensitivity = 0.0045
export (float) var pitch_min = -0.72
export (float) var pitch_max = 0.42
export (float) var lock_on_blend = 0.36
export (bool) var enable_soft_lock = false

var player = null
var yaw = 0.0
var pitch = -0.22
var battle_mode = false
var shake_strength = 0.0
var shake_time = 0.0
var shake_duration = 0.0
var fov_base = 64.0
var fov_kick = 0.0
var current_velocity = Vector3()

func _ready():
	if player_path != null and str(player_path) != "" and has_node(player_path):
		player = get_node(player_path)
	elif get_parent() and get_parent().has_node("Player"):
		player = get_parent().get_node("Player")
	fov_base = fov
	yaw = rotation.y
	set_process_input(true)

func _input(event):
	if not battle_mode:
		return
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP and event.pressed:
			follow_distance = clamp(follow_distance - 0.55, min_distance, max_distance)
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			follow_distance = clamp(follow_distance + 0.55, min_distance, max_distance)
		elif event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, pitch_min, pitch_max)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta):
	if not player:
		return

	var target_origin = player.global_transform.origin
	var focus = target_origin + Vector3.UP * pivot_height
	var lock_target = _get_soft_lock_target()
	if lock_target:
		var lock_dir = lock_target.global_transform.origin - target_origin
		lock_dir.y = 0
		if lock_dir.length() > 0.1:
			var lock_yaw = atan2(lock_dir.x, lock_dir.z) + PI
			yaw = lerp_angle(yaw, lock_yaw, clamp(lock_on_blend * delta * 3.2, 0.0, 1.0))
			focus = focus.linear_interpolate(lock_target.global_transform.origin + Vector3.UP * 1.15, 0.22)

	var desired_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var shoulder = desired_basis.x * shoulder_offset
	var desired_position = focus + shoulder + desired_basis.z * follow_distance
	desired_position = _resolve_camera_collision(focus + shoulder * 0.25, desired_position)

	var t = clamp(smooth_speed * delta, 0.0, 1.0)
	global_transform.origin = global_transform.origin.linear_interpolate(desired_position, t)

	var look_target = focus
	if lock_target:
		look_target = look_target.linear_interpolate(lock_target.global_transform.origin + Vector3.UP * 1.2, 0.44)
	look_at(look_target, Vector3.UP)

	if shake_time > 0.0:
		shake_time -= delta
		var intensity = shake_strength * (shake_time / max(shake_duration, 0.001))
		global_translate(Vector3(rand_range(-intensity, intensity), rand_range(-intensity, intensity), rand_range(-intensity, intensity)))
	elif shake_strength > 0.0:
		shake_strength = 0.0

	fov_kick = lerp(fov_kick, 0.0, clamp(delta * 5.5, 0.0, 1.0))
	fov = lerp(fov, fov_base + fov_kick, clamp(delta * 8.0, 0.0, 1.0))

func set_battle_mode(enabled):
	battle_mode = enabled
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func add_fov_kick(amount = 3.0):
	fov_kick = max(fov_kick, amount)

func shake(strength = 0.18, duration = 0.09):
	shake_strength = max(shake_strength, strength)
	shake_duration = max(duration, 0.01)
	shake_time = max(shake_time, duration)

func _get_soft_lock_target():
	if not enable_soft_lock or lock_on_blend <= 0.0:
		return null
	if player and player.has_method("get_combat_target"):
		var target = player.get_combat_target()
		if target and is_instance_valid(target):
			return target
	return null

func _resolve_camera_collision(from, desired_position):
	var current = get_tree().get_current_scene()
	if current == null:
		return desired_position
	var world = current.get_world()
	if world == null:
		return desired_position
	var exclude = []
	if player:
		exclude.append(player)
	var hit = world.direct_space_state.intersect_ray(from, desired_position, exclude, 1, true, false)
	if hit and hit.has("position"):
		var normal = Vector3.ZERO
		if hit.has("normal"):
			normal = hit.normal
		return hit.position + normal * 0.26 + (from - desired_position).normalized() * 0.18
	return desired_position
