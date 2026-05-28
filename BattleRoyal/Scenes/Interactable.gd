extends Area

export (String) var interact_id = ""
export (String) var display_name = "Story Point"
export (String) var prompt_text = "Press E to interact"
export (bool) var auto_trigger = false
export (bool) var active = true
export (float) var activation_cooldown = 0.45

var player_near = false
var cooldown = 0.0

func _ready():
	monitoring = active
	monitorable = active
	connect("body_entered", self, "_on_body_entered")
	connect("body_exited", self, "_on_body_exited")
	set_process(true)

func _process(delta):
	if cooldown > 0.0:
		cooldown = max(0.0, cooldown - delta)
	if not active or not player_near:
		return
	if Input.is_key_pressed(KEY_E) and cooldown <= 0.0:
		activate()

func set_active(value):
	active = value
	monitoring = value
	monitorable = value
	visible = value
	if not active:
		_set_prompt(false)

func activate():
	if not active:
		return
	cooldown = activation_cooldown
	_set_prompt(false)
	var current = get_tree().get_current_scene()
	if current and current.has_node("GameManager"):
		var gm = current.get_node("GameManager")
		if gm and gm.has_method("handle_interaction"):
			gm.handle_interaction(interact_id, self)

func _on_body_entered(body):
	if body == null or not body.is_in_group("player"):
		return
	player_near = true
	if not active:
		return
	if auto_trigger:
		activate()
	else:
		_set_prompt(true)

func _on_body_exited(body):
	if body == null or not body.is_in_group("player"):
		return
	player_near = false
	_set_prompt(false)

func _set_prompt(show):
	if not is_inside_tree():
		return
	var current = get_tree().get_current_scene()
	if current == null or not current.has_node("HUD"):
		return
	var hud = current.get_node("HUD")
	if hud and hud.has_method("set_interaction_prompt"):
		hud.set_interaction_prompt(prompt_text if show else "", show)
