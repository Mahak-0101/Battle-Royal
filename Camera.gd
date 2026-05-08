extends Camera

onready var player = get_parent().get_node("Player")
var smooth_speed = 8.0
var offset = Vector3(0,8,12)

func _process(delta):
	if not player:
		return
	var target = player.translation + offset
	translation = translation.linear_interpolate(target, clamp(smooth_speed * delta, 0, 1))
