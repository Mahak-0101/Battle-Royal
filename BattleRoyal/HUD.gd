extends CanvasLayer

var ui_root = null
var start_root = null
var battle_root = null
var pause_root = null
var transition_overlay = null
var tween = null

var title_label = null
var subtitle_label = null
var selected_character_label = null
var character_info_label = null
var start_btn = null
var continue_btn = null
var character_cards = {}
var selected_character_key = ""

var mission_title_label = null
var mission_objective_label = null
var mission_progress_label = null
var objective_banner = null
var objective_timer = 0.0
var interaction_prompt = null
var dialogue_panel = null
var dialogue_speaker = null
var dialogue_line = null
var combat_log = null
var last_log_message = ""

var health_label = null
var health_bar = null
var guard_label = null
var guard_bar = null
var special_label = null
var special_bar = null
var xp_label = null
var weapon_label = null
var weapon_bar = null
var weapon_buttons = []
var target_panel = null
var target_label = null
var target_bar = null
var crosshair = null
var combat_feedback_label = null
var combat_feedback_timer = 0.0
var damage_flash = null
var pause_low_spec_label = null

var battle_mode = false
var health_value = 100
var health_max_value = 100
var guard_value = 100.0
var guard_max_value = 100.0
var special_value = 0.0
var special_max_value = 100.0
var ui_time = 0.0

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	_hide_legacy_ui()
	_build_ui()
	_refresh_continue_from_gm()
	_select_default_hero()
	_notify("A new journey waits at Kurukshetra.", Color(0.86, 0.72, 0.32))

func _process(delta):
	ui_time += delta
	if crosshair and crosshair.visible:
		var pulse = 1.0 + sin(ui_time * 5.2) * 0.025
		crosshair.rect_scale = Vector2(pulse, pulse)
	if combat_feedback_label and combat_feedback_timer > 0.0:
		combat_feedback_timer -= delta
		if combat_feedback_timer <= 0.0 and tween:
			tween.interpolate_property(combat_feedback_label, "modulate:a", combat_feedback_label.modulate.a, 0.0, 0.22, Tween.TRANS_SINE, Tween.EASE_IN)
			tween.start()
	if objective_banner and objective_timer > 0.0:
		objective_timer -= delta
		if objective_timer <= 0.0:
			tween.interpolate_property(objective_banner, "modulate:a", objective_banner.modulate.a, 0.0, 0.42, Tween.TRANS_SINE, Tween.EASE_IN)
			tween.start()

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_ESCAPE and battle_mode:
			_toggle_pause()

func _hide_legacy_ui():
	if has_node("Control"):
		get_node("Control").visible = false
	if has_node("Crosshair"):
		get_node("Crosshair").visible = false
	if has_node("WeaponBar"):
		get_node("WeaponBar").visible = false

func _build_ui():
	ui_root = Control.new()
	ui_root.name = "MahabharatHUD"
	ui_root.anchor_right = 1
	ui_root.anchor_bottom = 1
	ui_root.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(ui_root)

	var backdrop = ColorRect.new()
	backdrop.name = "GlobalTint"
	backdrop.anchor_right = 1
	backdrop.anchor_bottom = 1
	backdrop.color = Color(0.02, 0.025, 0.045, 0.16)
	ui_root.add_child(backdrop)

	damage_flash = ColorRect.new()
	damage_flash.name = "DamageFlash"
	damage_flash.anchor_right = 1
	damage_flash.anchor_bottom = 1
	damage_flash.color = Color(0.70, 0.08, 0.05, 0.0)
	ui_root.add_child(damage_flash)

	_build_start_menu()
	_build_battle_hud()
	_build_pause_menu()

	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.anchor_right = 1
	transition_overlay.anchor_bottom = 1
	transition_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(transition_overlay)

	tween = Tween.new()
	tween.pause_mode = Node.PAUSE_MODE_PROCESS
	ui_root.add_child(tween)

func _build_start_menu():
	start_root = Control.new()
	start_root.name = "StartMenu"
	start_root.anchor_right = 1
	start_root.anchor_bottom = 1
	ui_root.add_child(start_root)

	var wash = ColorRect.new()
	wash.anchor_right = 1
	wash.anchor_bottom = 1
	wash.color = Color(0.025, 0.035, 0.070, 0.82)
	start_root.add_child(wash)

	var panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.margin_left = -410
	panel.margin_right = 410
	panel.margin_top = -235
	panel.margin_bottom = 235
	panel.add_stylebox_override("panel", _make_panel_style(Color(0.035, 0.045, 0.075, 0.94), Color(0.86, 0.66, 0.24, 0.88), 2))
	start_root.add_child(panel)

	var box = VBoxContainer.new()
	box.margin_left = 18
	box.margin_top = 16
	box.margin_right = -18
	box.margin_bottom = -16
	box.add_constant_override("separation", 10)
	panel.add_child(box)

	title_label = Label.new()
	title_label.text = "DHARMA YODDHA"
	title_label.align = Label.ALIGN_CENTER
	title_label.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "A Mahabharat-inspired warrior journey"
	subtitle_label.align = Label.ALIGN_CENTER
	subtitle_label.add_color_override("font_color", Color(0.78, 0.90, 0.92))
	box.add_child(subtitle_label)

	selected_character_label = Label.new()
	selected_character_label.text = "Choose a hero"
	selected_character_label.align = Label.ALIGN_CENTER
	selected_character_label.add_color_override("font_color", Color(1.0, 0.95, 0.84))
	box.add_child(selected_character_label)

	character_info_label = Label.new()
	character_info_label.text = ""
	character_info_label.autowrap = true
	character_info_label.rect_min_size = Vector2(720, 54)
	character_info_label.align = Label.ALIGN_CENTER
	character_info_label.add_color_override("font_color", Color(0.78, 0.90, 0.92))
	box.add_child(character_info_label)

	var hero_row = HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGN_CENTER
	hero_row.add_constant_override("separation", 10)
	box.add_child(hero_row)
	_create_hero_card(hero_row, "Arjun", "arjun", "Gandiva Bow", "Precise archer with fast ranged pressure.")
	_create_hero_card(hero_row, "Krishna", "krishna", "Sudarshan Chakra", "Balanced divine guide with high resilience.")
	_create_hero_card(hero_row, "Bhima", "bhima", "Vajra Gada", "Heavy melee power and high health.")
	_create_hero_card(hero_row, "Karna", "karna", "Vijaya Bow", "Fierce marksman with strong damage.")

	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGN_CENTER
	button_row.add_constant_override("separation", 12)
	box.add_child(button_row)

	start_btn = Button.new()
	start_btn.text = "Begin Story"
	start_btn.rect_min_size = Vector2(170, 38)
	_style_button(start_btn)
	start_btn.connect("pressed", self, "_on_start_pressed")
	button_row.add_child(start_btn)

	continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.rect_min_size = Vector2(150, 38)
	_style_button(continue_btn)
	continue_btn.connect("pressed", self, "_on_continue_pressed")
	button_row.add_child(continue_btn)

func _build_battle_hud():
	battle_root = Control.new()
	battle_root.name = "BattleHUD"
	battle_root.anchor_right = 1
	battle_root.anchor_bottom = 1
	battle_root.visible = false
	ui_root.add_child(battle_root)

	var mission_panel = PanelContainer.new()
	mission_panel.anchor_left = 0.02
	mission_panel.anchor_right = 0.02
	mission_panel.anchor_top = 0.02
	mission_panel.anchor_bottom = 0.02
	mission_panel.margin_left = 0
	mission_panel.margin_right = 390
	mission_panel.margin_top = 0
	mission_panel.margin_bottom = 122
	mission_panel.add_stylebox_override("panel", _make_panel_style(Color(0.025, 0.035, 0.060, 0.78), Color(0.86, 0.66, 0.24, 0.78), 1))
	battle_root.add_child(mission_panel)

	var mission_box = VBoxContainer.new()
	mission_box.margin_left = 12
	mission_box.margin_top = 10
	mission_box.margin_right = -12
	mission_box.margin_bottom = -10
	mission_box.add_constant_override("separation", 4)
	mission_panel.add_child(mission_box)

	mission_title_label = Label.new()
	mission_title_label.text = "Mission"
	mission_title_label.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	mission_box.add_child(mission_title_label)

	mission_objective_label = Label.new()
	mission_objective_label.text = ""
	mission_objective_label.autowrap = true
	mission_objective_label.rect_min_size = Vector2(350, 38)
	mission_objective_label.add_color_override("font_color", Color(0.88, 0.96, 0.94))
	mission_box.add_child(mission_objective_label)

	mission_progress_label = Label.new()
	mission_progress_label.text = ""
	mission_progress_label.add_color_override("font_color", Color(0.72, 0.92, 0.92))
	mission_box.add_child(mission_progress_label)

	var status_panel = PanelContainer.new()
	status_panel.anchor_left = 0.02
	status_panel.anchor_right = 0.02
	status_panel.anchor_top = 1.0
	status_panel.anchor_bottom = 1.0
	status_panel.margin_left = 0
	status_panel.margin_right = 350
	status_panel.margin_top = -178
	status_panel.margin_bottom = -22
	status_panel.add_stylebox_override("panel", _make_panel_style(Color(0.025, 0.035, 0.055, 0.80), Color(0.18, 0.58, 0.58, 0.70), 1))
	battle_root.add_child(status_panel)

	var status_box = VBoxContainer.new()
	status_box.margin_left = 12
	status_box.margin_top = 10
	status_box.margin_right = -12
	status_box.margin_bottom = -10
	status_box.add_constant_override("separation", 5)
	status_panel.add_child(status_box)

	health_label = Label.new()
	health_label.text = "Health: 100"
	health_label.add_color_override("font_color", Color(1.0, 0.92, 0.86))
	status_box.add_child(health_label)
	health_bar = _make_progress_bar(Color(0.80, 0.08, 0.08, 0.96), 326, 18)
	status_box.add_child(health_bar)

	guard_label = Label.new()
	guard_label.text = "Guard: 100"
	guard_label.add_color_override("font_color", Color(0.80, 0.92, 1.0))
	status_box.add_child(guard_label)
	guard_bar = _make_progress_bar(Color(0.22, 0.54, 0.96, 0.94), 326, 16)
	status_box.add_child(guard_bar)

	special_label = Label.new()
	special_label.text = "Resolve: 0"
	special_label.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	status_box.add_child(special_label)
	special_bar = _make_progress_bar(Color(0.88, 0.62, 0.16, 0.94), 326, 16)
	status_box.add_child(special_bar)

	xp_label = Label.new()
	xp_label.text = "Level 1"
	xp_label.add_color_override("font_color", Color(0.78, 0.90, 0.92))
	status_box.add_child(xp_label)

	var weapon_panel = PanelContainer.new()
	weapon_panel.anchor_left = 0.5
	weapon_panel.anchor_right = 0.5
	weapon_panel.anchor_top = 1.0
	weapon_panel.anchor_bottom = 1.0
	weapon_panel.margin_left = -260
	weapon_panel.margin_right = 260
	weapon_panel.margin_top = -76
	weapon_panel.margin_bottom = -20
	weapon_panel.add_stylebox_override("panel", _make_panel_style(Color(0.025, 0.035, 0.055, 0.72), Color(0.86, 0.66, 0.24, 0.68), 1))
	battle_root.add_child(weapon_panel)

	var weapon_box = VBoxContainer.new()
	weapon_box.margin_left = 10
	weapon_box.margin_top = 6
	weapon_box.margin_right = -10
	weapon_box.margin_bottom = -6
	weapon_box.add_constant_override("separation", 4)
	weapon_panel.add_child(weapon_box)

	weapon_label = Label.new()
	weapon_label.text = "Weapon: None"
	weapon_label.align = Label.ALIGN_CENTER
	weapon_label.add_color_override("font_color", Color(1.0, 0.95, 0.84))
	weapon_box.add_child(weapon_label)

	weapon_bar = HBoxContainer.new()
	weapon_bar.alignment = BoxContainer.ALIGN_CENTER
	weapon_bar.add_constant_override("separation", 8)
	weapon_box.add_child(weapon_bar)

	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.margin_left = -18
	crosshair.margin_right = 18
	crosshair.margin_top = -22
	crosshair.margin_bottom = 22
	crosshair.align = Label.ALIGN_CENTER
	crosshair.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	battle_root.add_child(crosshair)

	interaction_prompt = Label.new()
	interaction_prompt.anchor_left = 0.5
	interaction_prompt.anchor_right = 0.5
	interaction_prompt.anchor_top = 1.0
	interaction_prompt.anchor_bottom = 1.0
	interaction_prompt.margin_left = -250
	interaction_prompt.margin_right = 250
	interaction_prompt.margin_top = -124
	interaction_prompt.margin_bottom = -92
	interaction_prompt.align = Label.ALIGN_CENTER
	interaction_prompt.visible = false
	interaction_prompt.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	battle_root.add_child(interaction_prompt)

	_build_target_panel()
	_build_dialogue_panel()
	_build_combat_log()
	_build_feedback_labels()

func _build_target_panel():
	target_panel = PanelContainer.new()
	target_panel.anchor_left = 0.5
	target_panel.anchor_right = 0.5
	target_panel.anchor_top = 0.02
	target_panel.anchor_bottom = 0.02
	target_panel.margin_left = -190
	target_panel.margin_right = 190
	target_panel.margin_top = 0
	target_panel.margin_bottom = 62
	target_panel.visible = false
	target_panel.add_stylebox_override("panel", _make_panel_style(Color(0.035, 0.025, 0.040, 0.76), Color(0.72, 0.10, 0.12, 0.72), 1))
	battle_root.add_child(target_panel)

	var box = VBoxContainer.new()
	box.margin_left = 10
	box.margin_top = 7
	box.margin_right = -10
	box.margin_bottom = -7
	box.add_constant_override("separation", 4)
	target_panel.add_child(box)

	target_label = Label.new()
	target_label.text = "Enemy"
	target_label.align = Label.ALIGN_CENTER
	target_label.add_color_override("font_color", Color(1.0, 0.86, 0.78))
	box.add_child(target_label)
	target_bar = _make_progress_bar(Color(0.88, 0.08, 0.07, 0.95), 350, 16)
	box.add_child(target_bar)

func _build_dialogue_panel():
	dialogue_panel = PanelContainer.new()
	dialogue_panel.anchor_left = 0.5
	dialogue_panel.anchor_right = 0.5
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.margin_left = -330
	dialogue_panel.margin_right = 330
	dialogue_panel.margin_top = -170
	dialogue_panel.margin_bottom = -92
	dialogue_panel.visible = false
	dialogue_panel.add_stylebox_override("panel", _make_panel_style(Color(0.025, 0.030, 0.055, 0.88), Color(0.86, 0.66, 0.24, 0.84), 1))
	battle_root.add_child(dialogue_panel)

	var box = VBoxContainer.new()
	box.margin_left = 14
	box.margin_top = 10
	box.margin_right = -14
	box.margin_bottom = -10
	box.add_constant_override("separation", 4)
	dialogue_panel.add_child(box)

	dialogue_speaker = Label.new()
	dialogue_speaker.text = ""
	dialogue_speaker.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	box.add_child(dialogue_speaker)

	dialogue_line = Label.new()
	dialogue_line.text = ""
	dialogue_line.autowrap = true
	dialogue_line.rect_min_size = Vector2(610, 40)
	dialogue_line.add_color_override("font_color", Color(0.92, 0.98, 0.96))
	box.add_child(dialogue_line)

func _build_combat_log():
	combat_log = RichTextLabel.new()
	combat_log.anchor_left = 1.0
	combat_log.anchor_right = 1.0
	combat_log.anchor_top = 0.02
	combat_log.anchor_bottom = 0.02
	combat_log.margin_left = -330
	combat_log.margin_right = -18
	combat_log.margin_top = 0
	combat_log.margin_bottom = 138
	combat_log.bbcode_enabled = true
	combat_log.scroll_active = false
	combat_log.add_color_override("default_color", Color(0.90, 0.98, 0.96))
	combat_log.add_stylebox_override("panel", _make_panel_style(Color(0.025, 0.035, 0.055, 0.72), Color(0.18, 0.58, 0.58, 0.62), 1))
	battle_root.add_child(combat_log)

func _build_feedback_labels():
	objective_banner = Label.new()
	objective_banner.anchor_left = 0.5
	objective_banner.anchor_right = 0.5
	objective_banner.anchor_top = 0.5
	objective_banner.anchor_bottom = 0.5
	objective_banner.margin_left = -250
	objective_banner.margin_right = 250
	objective_banner.margin_top = -88
	objective_banner.margin_bottom = -44
	objective_banner.align = Label.ALIGN_CENTER
	objective_banner.modulate.a = 0.0
	objective_banner.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	battle_root.add_child(objective_banner)

	combat_feedback_label = Label.new()
	combat_feedback_label.anchor_left = 0.5
	combat_feedback_label.anchor_right = 0.5
	combat_feedback_label.anchor_top = 0.5
	combat_feedback_label.anchor_bottom = 0.5
	combat_feedback_label.margin_left = -220
	combat_feedback_label.margin_right = 220
	combat_feedback_label.margin_top = 42
	combat_feedback_label.margin_bottom = 82
	combat_feedback_label.align = Label.ALIGN_CENTER
	combat_feedback_label.modulate.a = 0.0
	combat_feedback_label.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	battle_root.add_child(combat_feedback_label)

func _build_pause_menu():
	pause_root = Control.new()
	pause_root.name = "PauseMenu"
	pause_root.anchor_right = 1
	pause_root.anchor_bottom = 1
	pause_root.visible = false
	pause_root.pause_mode = Node.PAUSE_MODE_PROCESS
	ui_root.add_child(pause_root)

	var shade = ColorRect.new()
	shade.anchor_right = 1
	shade.anchor_bottom = 1
	shade.color = Color(0, 0, 0, 0.58)
	pause_root.add_child(shade)

	var panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.margin_left = -170
	panel.margin_right = 170
	panel.margin_top = -150
	panel.margin_bottom = 150
	panel.add_stylebox_override("panel", _make_panel_style(Color(0.030, 0.040, 0.070, 0.96), Color(0.86, 0.66, 0.24, 0.90), 2))
	pause_root.add_child(panel)

	var box = VBoxContainer.new()
	box.margin_left = 16
	box.margin_top = 14
	box.margin_right = -16
	box.margin_bottom = -14
	box.add_constant_override("separation", 10)
	panel.add_child(box)

	var title = Label.new()
	title.text = "Paused"
	title.align = Label.ALIGN_CENTER
	title.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	box.add_child(title)

	var resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.rect_min_size = Vector2(260, 36)
	_style_button(resume_btn)
	resume_btn.connect("pressed", self, "_toggle_pause")
	box.add_child(resume_btn)

	var save_btn = Button.new()
	save_btn.text = "Save Checkpoint"
	save_btn.rect_min_size = Vector2(260, 36)
	_style_button(save_btn)
	save_btn.connect("pressed", self, "_on_save_pressed")
	box.add_child(save_btn)

	var low_btn = Button.new()
	low_btn.text = "Visual Profile"
	low_btn.rect_min_size = Vector2(260, 36)
	_style_button(low_btn)
	low_btn.connect("pressed", self, "_on_low_spec_pressed")
	box.add_child(low_btn)

	pause_low_spec_label = Label.new()
	pause_low_spec_label.text = "Low Spec: On"
	pause_low_spec_label.align = Label.ALIGN_CENTER
	pause_low_spec_label.add_color_override("font_color", Color(0.78, 0.90, 0.92))
	box.add_child(pause_low_spec_label)

	var menu_btn = Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.rect_min_size = Vector2(260, 36)
	_style_button(menu_btn)
	menu_btn.connect("pressed", self, "_on_return_to_menu_pressed")
	box.add_child(menu_btn)

func _create_hero_card(parent, title_text, hero_key, weapon_text, description_text):
	var card = PanelContainer.new()
	card.rect_min_size = Vector2(176, 154)
	card.add_stylebox_override("panel", _make_panel_style(Color(0.045, 0.060, 0.090, 0.94), Color(0.18, 0.58, 0.58, 0.70), 1))
	parent.add_child(card)
	character_cards[hero_key] = card

	var box = VBoxContainer.new()
	box.margin_left = 10
	box.margin_top = 10
	box.margin_right = -10
	box.margin_bottom = -10
	box.add_constant_override("separation", 5)
	card.add_child(box)

	var hero_name = Label.new()
	hero_name.text = title_text
	hero_name.align = Label.ALIGN_CENTER
	hero_name.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	box.add_child(hero_name)

	var weapon = Label.new()
	weapon.text = weapon_text
	weapon.align = Label.ALIGN_CENTER
	weapon.autowrap = true
	weapon.add_color_override("font_color", Color(0.92, 0.98, 0.96))
	box.add_child(weapon)

	var desc = Label.new()
	desc.text = description_text
	desc.autowrap = true
	desc.rect_min_size = Vector2(150, 42)
	desc.add_color_override("font_color", Color(0.78, 0.90, 0.92))
	box.add_child(desc)

	var btn = Button.new()
	btn.text = "Select"
	btn.rect_min_size = Vector2(144, 30)
	_style_button(btn)
	btn.connect("pressed", self, "_on_hero_selected", [hero_key])
	box.add_child(btn)

func _select_default_hero():
	_on_hero_selected("arjun")

func _on_hero_selected(hero_key):
	selected_character_key = hero_key
	var current = get_tree().get_current_scene()
	if current and current.has_node("GameManager"):
		var gm = current.get_node("GameManager")
		if gm and gm.has_method("select_character"):
			gm.select_character(hero_key)
		if gm and gm.has_method("get_selected_character_data"):
			show_selected_character(gm.get_selected_character_data())

func _on_start_pressed():
	if selected_character_key == "":
		_notify("Choose a hero first.", Color(1.0, 0.45, 0.28))
		return
	_play_battle_transition(false)

func _on_continue_pressed():
	_play_battle_transition(true)

func _play_battle_transition(continue_game):
	if start_btn:
		start_btn.disabled = true
	if continue_btn:
		continue_btn.disabled = true
	if tween:
		tween.interpolate_property(transition_overlay, "color:a", transition_overlay.color.a, 0.90, 0.24, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.start()
	yield(get_tree().create_timer(0.28), "timeout")
	_enter_battle_mode()
	var gm = _get_game_manager()
	if gm:
		if continue_game and gm.has_method("continue_story"):
			gm.continue_story()
		elif gm.has_method("start_story_mode"):
			gm.start_story_mode(false)
	if tween:
		tween.interpolate_property(transition_overlay, "color:a", 0.90, 0.0, 0.42, Tween.TRANS_SINE, Tween.EASE_IN)
		tween.start()
	yield(get_tree().create_timer(0.50), "timeout")
	if start_btn:
		start_btn.disabled = false
	_refresh_continue_from_gm()

func _enter_battle_mode():
	battle_mode = true
	start_root.visible = false
	battle_root.visible = true
	pause_root.visible = false
	get_tree().paused = false
	var current = get_tree().get_current_scene()
	if current and current.has_node("Camera"):
		var cam = current.get_node("Camera")
		if cam and cam.has_method("set_battle_mode"):
			cam.set_battle_mode(true)

func _toggle_pause():
	if not battle_mode:
		return
	var paused = not get_tree().paused
	get_tree().paused = paused
	pause_root.visible = paused
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_save_pressed():
	var gm = _get_game_manager()
	if gm and gm.has_method("save_game"):
		gm.save_game()
		show_checkpoint("Manual Save")

func _on_low_spec_pressed():
	var gm = _get_game_manager()
	if gm and gm.has_method("set_low_spec_mode"):
		gm.set_low_spec_mode(not bool(gm.low_spec_mode))
		_update_low_spec_label()

func _on_return_to_menu_pressed():
	get_tree().paused = false
	battle_mode = false
	pause_root.visible = false
	battle_root.visible = false
	start_root.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var gm = _get_game_manager()
	if gm and gm.has_method("return_to_menu"):
		gm.return_to_menu()
	_refresh_continue_from_gm()

func _update_low_spec_label():
	var gm = _get_game_manager()
	if pause_low_spec_label and gm:
		pause_low_spec_label.text = "Low Spec: %s" % ("On" if bool(gm.low_spec_mode) else "Balanced")

func _refresh_continue_from_gm():
	var gm = _get_game_manager()
	if gm and gm.has_method("has_save"):
		set_continue_available(gm.has_save())
	_update_low_spec_label()

func set_continue_available(available):
	if continue_btn:
		continue_btn.disabled = not available
		continue_btn.modulate.a = 1.0 if available else 0.45

func show_selected_character(data):
	if data == null:
		return
	var display_name = str(data.get("display_name", "Hero"))
	var character_key = str(data.get("character_key", display_name.to_lower()))
	var weapon_name = str(data.get("weapon_name", "Weapon"))
	var max_health = int(data.get("max_health", 100))
	selected_character_key = character_key
	health_max_value = max_health
	health_value = max_health
	if selected_character_label:
		selected_character_label.text = "%s chosen" % display_name
	if character_info_label:
		character_info_label.text = "%s  |  %s  |  Health %d" % [str(data.get("description", "")), weapon_name, max_health]
	if weapon_label:
		weapon_label.text = "Weapon: %s" % weapon_name
	set_health(max_health)
	for key in character_cards.keys():
		var card = character_cards[key]
		if key == character_key:
			card.add_stylebox_override("panel", _make_panel_style(Color(0.065, 0.075, 0.110, 0.98), Color(0.96, 0.78, 0.30, 1.0), 2))
			card.rect_scale = Vector2(1.025, 1.025)
		else:
			card.add_stylebox_override("panel", _make_panel_style(Color(0.045, 0.060, 0.090, 0.94), Color(0.18, 0.58, 0.58, 0.70), 1))
			card.rect_scale = Vector2(1, 1)
	_notify("%s is ready." % display_name, Color(0.96, 0.78, 0.30))

func set_mission(title, objective, progress, goal):
	if mission_title_label:
		mission_title_label.text = title
	if mission_objective_label:
		mission_objective_label.text = objective
	if mission_progress_label:
		mission_progress_label.text = "%d / %d" % [progress, max(goal, 1)]
	_notify("%s: %s" % [title, objective], Color(0.78, 0.90, 0.92))

func show_objective_banner(text):
	if objective_banner == null:
		return
	objective_banner.text = text
	objective_banner.modulate.a = 0.0
	objective_banner.rect_scale = Vector2(0.96, 0.96)
	objective_timer = 2.1
	if tween:
		tween.interpolate_property(objective_banner, "modulate:a", 0.0, 1.0, 0.22, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.interpolate_property(objective_banner, "rect_scale", Vector2(0.96, 0.96), Vector2(1, 1), 0.22, Tween.TRANS_BACK, Tween.EASE_OUT)
		tween.start()

func set_interaction_prompt(text, show):
	if interaction_prompt == null:
		return
	interaction_prompt.text = text
	interaction_prompt.visible = show and text != ""

func show_dialogue(speaker, line):
	if dialogue_panel == null:
		return
	dialogue_panel.visible = true
	dialogue_speaker.text = speaker
	dialogue_line.text = line

func hide_dialogue():
	if dialogue_panel:
		dialogue_panel.visible = false

func show_checkpoint(name):
	show_combat_feedback("Saved: %s" % name, Color(0.58, 0.86, 1.0))

func show_story_complete():
	set_mission("Journey Complete", "The field is safe. The warrior's oath is fulfilled.", 1, 1)
	show_objective_banner("DHARMA HOLDS")
	show_combat_feedback("Story complete", Color(0.96, 0.78, 0.30))

func add_weapon_slot(name, index):
	if weapon_bar == null:
		return
	for button in weapon_buttons:
		if button.text == name:
			return
	var btn = Button.new()
	btn.text = name
	btn.rect_min_size = Vector2(112, 28)
	_style_button(btn)
	btn.connect("pressed", self, "_on_weapon_button_pressed", [index])
	weapon_bar.add_child(btn)
	weapon_buttons.append(btn)
	set_selected_weapon(index)
	_notify("Equipped: %s" % name, Color(0.96, 0.78, 0.30))

func _on_weapon_button_pressed(index):
	var current = get_tree().get_current_scene()
	if current and current.has_node("Player"):
		var player = current.get_node("Player")
		if player and player.has_method("equip_weapon"):
			player.equip_weapon(index)

func set_selected_weapon(index):
	for i in range(weapon_buttons.size()):
		var button = weapon_buttons[i]
		if i == index:
			button.rect_scale = Vector2(1.04, 1.04)
			button.add_color_override("font_color", Color(1.0, 0.96, 0.86))
		else:
			button.rect_scale = Vector2(1, 1)
			button.add_color_override("font_color", Color(0.96, 0.78, 0.30))

func set_weapon(name):
	if weapon_label:
		weapon_label.text = "Weapon: %s" % name
	_notify("Ready: %s" % name, Color(0.92, 0.98, 0.96))

func set_health(h):
	health_value = clamp(int(h), 0, health_max_value)
	if health_label:
		health_label.text = "Health: %d" % health_value
	if health_bar:
		health_bar.max_value = health_max_value
		health_bar.value = health_value
	if health_value < health_max_value:
		_flash_damage()

func set_guard(value, max_value):
	guard_value = clamp(float(value), 0.0, float(max_value))
	guard_max_value = max(float(max_value), 1.0)
	if guard_label:
		guard_label.text = "Guard: %d" % int(guard_value)
	if guard_bar:
		guard_bar.max_value = guard_max_value
		guard_bar.value = guard_value

func set_progression(level, xp, xp_next, special, special_max):
	special_value = clamp(float(special), 0.0, float(special_max))
	special_max_value = max(float(special_max), 1.0)
	if special_label:
		special_label.text = "Resolve: %d" % int(special_value)
	if special_bar:
		special_bar.max_value = special_max_value
		special_bar.value = special_value
	if xp_label:
		xp_label.text = "Level %d  XP %d/%d" % [int(level), int(xp), int(xp_next)]

func set_target_health(name, value, max_value):
	if target_panel == null:
		return
	if name == "" or max_value <= 0:
		target_panel.visible = false
		return
	target_panel.visible = battle_mode
	target_label.text = name
	target_bar.max_value = max_value
	target_bar.value = clamp(value, 0, max_value)

func show_combat_feedback(message, color = Color(1, 1, 1)):
	if combat_feedback_label == null:
		return
	combat_feedback_label.text = message
	combat_feedback_label.add_color_override("font_color", color)
	combat_feedback_label.modulate.a = 1.0
	combat_feedback_label.rect_scale = Vector2(1.08, 1.08)
	combat_feedback_timer = 0.72
	if tween:
		tween.interpolate_property(combat_feedback_label, "rect_scale", combat_feedback_label.rect_scale, Vector2(1, 1), 0.16, Tween.TRANS_BACK, Tween.EASE_OUT)
		tween.start()
	_notify(message, color)

func pulse_crosshair():
	if crosshair == null:
		return
	crosshair.rect_scale = Vector2(1.18, 1.18)
	if tween:
		tween.interpolate_property(crosshair, "rect_scale", crosshair.rect_scale, Vector2(1, 1), 0.12, Tween.TRANS_BACK, Tween.EASE_OUT)
		tween.start()

func _flash_damage():
	if damage_flash == null or tween == null:
		return
	damage_flash.color.a = 0.0
	tween.interpolate_property(damage_flash, "color:a", 0.0, 0.18, 0.06, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(damage_flash, "color:a", 0.18, 0.0, 0.22, Tween.TRANS_SINE, Tween.EASE_IN, 0.08)
	tween.start()

func _notify(message, color = Color(1, 1, 1)):
	if combat_log == null:
		return
	if message == last_log_message:
		return
	last_log_message = message
	combat_log.bbcode_text = "[color=#%s]%s[/color]\n%s" % [_hex_color(color), message, combat_log.bbcode_text]
	combat_log.bbcode_text = combat_log.bbcode_text.substr(0, 1200)

func _hex_color(color):
	return "%02x%02x%02x" % [int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0)]

func _get_game_manager():
	var current = get_tree().get_current_scene()
	if current and current.has_node("GameManager"):
		return current.get_node("GameManager")
	return null

func _make_progress_bar(fill_color, width, height):
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.percent_visible = false
	bar.rect_min_size = Vector2(width, height)
	bar.add_stylebox_override("bg", _make_bar_bg_style())
	bar.add_stylebox_override("fg", _make_bar_fg_style(fill_color))
	return bar

func _make_panel_style(bg_color, border_color, border_width = 1):
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_bar_bg_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.014, 0.025, 0.88)
	style.border_color = Color(0.18, 0.58, 0.58, 0.56)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	return style

func _make_bar_fg_style(fill_color):
	var style = StyleBoxFlat.new()
	style.bg_color = fill_color
	return style

func _style_button(btn):
	btn.add_stylebox_override("normal", _make_panel_style(Color(0.045, 0.060, 0.090, 0.94), Color(0.18, 0.58, 0.58, 0.70), 1))
	btn.add_stylebox_override("hover", _make_panel_style(Color(0.060, 0.080, 0.120, 0.96), Color(0.96, 0.78, 0.30, 0.92), 1))
	btn.add_stylebox_override("pressed", _make_panel_style(Color(0.030, 0.040, 0.065, 0.98), Color(0.96, 0.78, 0.30, 1.0), 1))
	btn.add_color_override("font_color", Color(0.96, 0.78, 0.30))
	btn.add_color_override("font_color_hover", Color(0.92, 0.98, 0.96))
	btn.add_color_override("font_color_pressed", Color(1.0, 0.95, 0.84))
