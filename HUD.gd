
extends CanvasLayer

var health_label = null
var single_btn = null
var multi_btn = null
var weapon_label = null
var crosshair = null
var weapon_bar = null
var weapon_buttons = []

func _ready():
	if has_node("Control/VBoxContainer/HealthLabel"):
		health_label = get_node("Control/VBoxContainer/HealthLabel")
	if has_node("Control/VBoxContainer/ModeContainer/SingleButton"):
		single_btn = get_node("Control/VBoxContainer/ModeContainer/SingleButton")
	if has_node("Control/VBoxContainer/ModeContainer/MultiButton"):
		multi_btn = get_node("Control/VBoxContainer/ModeContainer/MultiButton")
	if single_btn:
		single_btn.connect("pressed", self, "_on_single_pressed")
	if multi_btn:
		multi_btn.connect("pressed", self, "_on_multi_pressed")
	if has_node("Control/VBoxContainer/WeaponLabel"):
		weapon_label = get_node("Control/VBoxContainer/WeaponLabel")

	if has_node("Crosshair"):
		crosshair = get_node("Crosshair")
	if has_node("WeaponBar"):
		weapon_bar = get_node("WeaponBar")

func add_weapon_slot(name, index):
	if not weapon_bar:
		return
	var btn = Button.new()
	btn.text = name
	btn.rect_min_size = Vector2(100, 36)
	btn.connect("pressed", self, "_on_weapon_button_pressed", [index])
	weapon_bar.add_child(btn)
	weapon_buttons.append(btn)

func set_selected_weapon(index):
	for i in range(weapon_buttons.size()):
		var b = weapon_buttons[i]
		if i == index:
			b.add_color_override("font_color", Color(1,0.8,0))
		else:
			b.add_color_override("font_color", Color(1,1,1))

func _on_weapon_button_pressed(index):
	var current = get_tree().get_current_scene()
	if current and current.has_node("Player"):
		var player = current.get_node("Player")
		if player and player.has_method("equip_weapon"):
			player.equip_weapon(index)

func set_health(h):
	if health_label:
		health_label.text = "Health: %d" % h
	else:
		# HUD not ready yet, defer the update
		call_deferred("set_health", h)

func set_weapon(name):
	if weapon_label:
		weapon_label.text = "Weapon: %s" % name
	else:
		call_deferred("set_weapon", name)

func _on_single_pressed():
	var current = get_tree().get_current_scene()
	if current and current.has_node("GameManager"):
		var gm = current.get_node("GameManager")
		if gm and gm.has_method("start_single_player"):
			gm.start_single_player()

func _on_multi_pressed():
	var current = get_tree().get_current_scene()
	if current and current.has_node("GameManager"):
		var gm = current.get_node("GameManager")
		if gm and gm.has_method("start_multiplayer"):
			gm.start_multiplayer()
