extends Node

export (PackedScene) var EnemyScene = preload("res://Scenes/Enemy.tscn")
export (PackedScene) var StarterWeaponScene = preload("res://Scenes/WarriorMeleeWeapon.tscn")
export (bool) var low_spec_mode = true
export (int) var max_active_enemies = 5
export (float) var day_cycle_seconds = 420.0

var running = false
var story_started = false
var story_completed = false
var selected_character_key = "arjun"
var current_mission_index = 0
var mission_progress = 0
var mission_goal = 1
var battle_wave = 0
var defeated_total = 0
var checkpoint_position = Vector3(0, 3, 0)
var checkpoint_name = "Pandava Camp"
var save_path = "user://mahabharat_story.save"
var dialogue_playing = false
var loaded_player_state = {}
var day_time = 0.24
var day_update_timer = 0.0
var story_root = null
var story_points = {}
var story_point_roots = {}
var fire_player = null
var hit_player = null
var death_player = null
var ui_player = null
var music_player = null

var supply_ids = ["village_supplies", "forest_herbs", "river_water"]

var mission_defs = [
	{
		"id": "oath",
		"title": "The Oath at Dawn",
		"objective": "Speak with Krishna at the Pandava camp.",
		"goal": 1,
		"checkpoint": Vector3(0, 3, 0)
	},
	{
		"id": "supplies",
		"title": "For the Army of Dharma",
		"objective": "Gather supplies from the village, forest, and river.",
		"goal": 3,
		"checkpoint": Vector3(-14, 3, 12)
	},
	{
		"id": "raid",
		"title": "Raid at the Sacred Grove",
		"objective": "Defeat the Kaurava scouts threatening the camp.",
		"goal": 4,
		"checkpoint": Vector3(-8, 3, -12)
	},
	{
		"id": "temple",
		"title": "Blessing of the Stone Shrine",
		"objective": "Reach the temple and receive the sage's blessing.",
		"goal": 1,
		"checkpoint": Vector3(0, 3, -28)
	},
	{
		"id": "battlefield",
		"title": "The Field of Dharma",
		"objective": "Break through the battlefield ranks.",
		"goal": 6,
		"checkpoint": Vector3(0, 3, 18)
	},
	{
		"id": "duel",
		"title": "Rival's Challenge",
		"objective": "Defeat the rival commander and end the assault.",
		"goal": 1,
		"checkpoint": Vector3(0, 3, 30)
	}
]

var character_presets = {
	"arjun": {
		"display_name": "Arjun",
		"weapon_name": "Gandiva Bow",
		"max_health": 100,
		"walk_speed": 9,
		"run_speed": 16,
		"fire_rate": 0.18,
		"damage": 30,
		"melee_damage": 34,
		"description": "Master archer, precise and relentless.",
		"starter_weapon_scene": "res://Scenes/Bow.tscn",
		"visual_scene": "res://Assets/Characters/Idle.fbx",
		"animation_scenes": {
			"idle": "res://Assets/Characters/Idle.fbx",
			"walk": "res://Assets/Characters/Walk.fbx",
			"run": "res://Assets/Characters/Fast Run.fbx"
		}
	},
	"krishna": {
		"display_name": "Krishna",
		"weapon_name": "Sudarshan Chakra",
		"max_health": 120,
		"walk_speed": 10,
		"run_speed": 17,
		"fire_rate": 0.14,
		"damage": 26,
		"melee_damage": 31,
		"description": "Divine guide with balanced offense and resilience.",
		"starter_weapon_scene": "res://Scenes/WarriorMeleeWeapon.tscn"
	},
	"bhima": {
		"display_name": "Bhima",
		"weapon_name": "Vajra Gada",
		"max_health": 150,
		"walk_speed": 8,
		"run_speed": 13,
		"fire_rate": 0.26,
		"damage": 40,
		"melee_damage": 44,
		"description": "Powerhouse warrior with devastating strikes.",
		"starter_weapon_scene": "res://Scenes/WarriorMeleeWeapon.tscn"
	},
	"karna": {
		"display_name": "Karna",
		"weapon_name": "Vijaya Bow",
		"max_health": 110,
		"walk_speed": 9,
		"run_speed": 15,
		"fire_rate": 0.16,
		"damage": 34,
		"melee_damage": 38,
		"description": "Elite warrior with fierce precision.",
		"starter_weapon_scene": "res://Scenes/Bow.tscn"
	}
}

func _ready():
	randomize()
	_cache_audio_players()
	_apply_performance_profile()
	call_deferred("_finish_ready_setup")

func _finish_ready_setup():
	_build_story_world()
	_hide_all_story_points()
	_notify_hud_continue_state()
	_update_day_night(0.0)

func _process(delta):
	day_update_timer -= delta
	if day_update_timer <= 0.0:
		day_update_timer = 0.35
		_update_day_night(delta)

func _cache_audio_players():
	var parent = get_parent()
	if parent == null:
		return
	fire_player = _ensure_audio_player(parent, "FireSound")
	hit_player = _ensure_audio_player(parent, "HitSound")
	death_player = _ensure_audio_player(parent, "DeathSound")
	ui_player = _ensure_audio_player(parent, "UISound")
	music_player = _ensure_audio_player(parent, "MusicSound")
	if music_player:
		music_player.volume_db = -24.0

func _ensure_audio_player(parent, node_name):
	if parent.has_node(node_name):
		return parent.get_node(node_name)
	var player = AudioStreamPlayer.new()
	player.name = node_name
	parent.call_deferred("add_child", player)
	return player

func _apply_performance_profile():
	Engine.target_fps = 60
	var parent = get_parent()
	if parent == null:
		return
	if parent.has_node("ArenaBuilder"):
		var arena = parent.get_node("ArenaBuilder")
		arena.low_spec_mode = low_spec_mode
		arena.enable_particles = false
		arena.enable_dynamic_lights = false
		arena.enable_grass = false
		arena.tree_count = min(int(arena.tree_count), 8)
		arena.rock_count = min(int(arena.rock_count), 22)
		arena.terrain_resolution = clamp(int(arena.terrain_resolution), 12, 22)
	if parent.has_node("DirectionalLight"):
		var sun = parent.get_node("DirectionalLight")
		sun.shadow_enabled = false
		sun.light_energy = 0.95
	if parent.has_node("Camera"):
		var cam = parent.get_node("Camera")
		cam.far = 82.0
		cam.enable_soft_lock = true
	if parent.has_node("CloudLayerFar"):
		parent.get_node("CloudLayerFar").visible = false
	if parent.has_node("WorldEnvironment"):
		var world_env = parent.get_node("WorldEnvironment")
		if world_env.environment:
			world_env.environment.glow_enabled = false
			world_env.environment.fog_enabled = true
			world_env.environment.fog_depth_begin = 18.0
			world_env.environment.fog_depth_end = 92.0

func _build_story_world():
	var parent = get_parent()
	if parent == null:
		return
	if story_root and is_instance_valid(story_root):
		story_root.queue_free()
	story_root = Spatial.new()
	story_root.name = "StoryWorld"
	parent.add_child(story_root)
	_build_river()
	_build_camp(Vector3(-4, 0.03, 6))
	_build_village(Vector3(-27, 0.03, 12))
	_build_battlefield(Vector3(0, 0.04, 31))
	_build_story_points()

func _build_river():
	var water_mat = _make_spatial_material(Color(0.10, 0.32, 0.40, 0.58), 0.0, 0.72, true)
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.02, 0.11, 0.14)
	var river = MeshInstance.new()
	river.name = "SaraswatiRiver"
	var mesh = CubeMesh.new()
	mesh.size = Vector3(10.0, 0.05, 72.0)
	river.mesh = mesh
	river.translation = Vector3(22, 0.04, 0)
	river.rotation_degrees.y = -9.0
	river.material_override = water_mat
	story_root.add_child(river)
	for i in range(5):
		_add_block(story_root, Vector3(18 + i * 1.7, 0.16, -18 + i * 8), Vector3(1.2, 0.20, 0.8), _stone_mat(), "RiverStone")

func _build_camp(origin):
	var cloth_red = _make_spatial_material(Color(0.45, 0.05, 0.08), 0.0, 0.86)
	var cloth_blue = _make_spatial_material(Color(0.08, 0.16, 0.34), 0.0, 0.82)
	var wood = _make_spatial_material(Color(0.30, 0.16, 0.07), 0.0, 0.88)
	for i in range(3):
		var tent = Spatial.new()
		tent.name = "PandavaTent"
		tent.translation = origin + Vector3(-5 + i * 4.6, 0.0, 1.5 + (i % 2) * 2.1)
		story_root.add_child(tent)
		var body = MeshInstance.new()
		var body_mesh = PrismMesh.new()
		body_mesh.size = Vector3(2.6, 1.6, 2.0)
		body.mesh = body_mesh
		body.translation.y = 0.82
		body.rotation_degrees.y = 90
		body.material_override = cloth_red if i != 1 else cloth_blue
		tent.add_child(body)
		_add_cylinder(tent, Vector3(-1.45, 0.75, 0), Vector3(0, 0, 0), 0.04, 1.5, wood, "TentPole")
		_add_cylinder(tent, Vector3(1.45, 0.75, 0), Vector3(0, 0, 0), 0.04, 1.5, wood, "TentPole")
	for i in range(4):
		_add_banner(origin + Vector3(-8 + i * 4.2, 0, -2.5), Color(0.88, 0.65, 0.20), "CampBanner")

func _build_village(origin):
	var mud = _make_spatial_material(Color(0.42, 0.30, 0.20), 0.0, 0.94)
	var thatch = _make_spatial_material(Color(0.62, 0.50, 0.28), 0.0, 0.96)
	for i in range(4):
		var hut = Spatial.new()
		hut.name = "VillageHut"
		hut.translation = origin + Vector3((i % 2) * 5.2, 0.0, int(floor(float(i) / 2.0)) * 4.4)
		hut.rotation_degrees.y = rand_range(-18, 18)
		story_root.add_child(hut)
		_add_block(hut, Vector3(0, 0.68, 0), Vector3(2.7, 1.35, 2.2), mud, "HutWall")
		var roof = MeshInstance.new()
		var roof_mesh = PrismMesh.new()
		roof_mesh.size = Vector3(3.4, 1.2, 2.8)
		roof.mesh = roof_mesh
		roof.translation.y = 1.72
		roof.rotation_degrees.y = 90
		roof.material_override = thatch
		hut.add_child(roof)
	_add_banner(origin + Vector3(2.3, 0, -2.8), Color(0.12, 0.48, 0.42), "VillageBanner")

func _build_battlefield(origin):
	var wood = _make_spatial_material(Color(0.25, 0.12, 0.05), 0.0, 0.88)
	var metal = _make_spatial_material(Color(0.48, 0.47, 0.42), 0.35, 0.35)
	for i in range(9):
		var x = -16 + i * 4
		_add_cylinder(story_root, origin + Vector3(x, 0.75, -5 + sin(i) * 2.4), Vector3(12, 0, 25), 0.045, 1.7, wood, "BrokenSpear")
		_add_block(story_root, origin + Vector3(x + 0.35, 0.35, -4.3 + cos(i) * 2.1), Vector3(0.42, 0.70, 0.05), metal, "FallenShield")
	for i in range(5):
		_add_banner(origin + Vector3(-11 + i * 5.5, 0, 3.4), Color(0.55, 0.04, 0.06), "WarBanner")

func _build_story_points():
	_create_story_point("krishna_intro", "npc", "Krishna", "Press E to speak with Krishna", Vector3(-1.5, 0.05, 3.5), Color(0.12, 0.25, 0.68))
	_create_story_point("village_supplies", "supply", "Village Granary", "Press E to collect grain for the army", Vector3(-24, 0.1, 13), Color(0.72, 0.52, 0.22))
	_create_story_point("forest_herbs", "supply", "Forest Herbs", "Press E to gather healing herbs", Vector3(-18, 0.1, -21), Color(0.12, 0.42, 0.18))
	_create_story_point("river_water", "supply", "River Offering", "Press E to fill the water vessels", Vector3(20, 0.1, 7), Color(0.10, 0.42, 0.52))
	_create_story_point("temple_sage", "npc", "Temple Sage", "Press E to receive the blessing", Vector3(0, 0.1, -27.5), Color(0.58, 0.47, 0.82))
	_create_story_point("camp_checkpoint", "checkpoint", "Camp Checkpoint", "Press E to save at the camp flame", Vector3(3.2, 0.1, 7.8), Color(1.0, 0.42, 0.12))
	_create_story_point("temple_checkpoint", "checkpoint", "Temple Checkpoint", "Press E to save at the shrine flame", Vector3(3.0, 0.1, -25.0), Color(1.0, 0.58, 0.16))

func _create_story_point(point_id, point_type, display_name, prompt, pos, accent):
	var root = Spatial.new()
	root.name = "StoryPoint_%s" % point_id
	root.translation = pos
	story_root.add_child(root)
	story_point_roots[point_id] = root
	_build_story_point_visual(root, point_type, accent)

	var area = Area.new()
	area.name = "InteractArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.set_script(load("res://Scenes/Interactable.gd"))
	area.interact_id = point_id
	area.display_name = display_name
	area.prompt_text = prompt
	root.add_child(area)

	var shape = CollisionShape.new()
	var sphere = SphereShape.new()
	sphere.radius = 2.25
	shape.shape = sphere
	area.add_child(shape)
	story_points[point_id] = area

func _build_story_point_visual(root, point_type, accent):
	var gold = _make_spatial_material(Color(0.86, 0.63, 0.20), 0.20, 0.34)
	var cloth = _make_spatial_material(accent, 0.0, 0.78)
	var skin = _make_spatial_material(Color(0.82, 0.66, 0.50), 0.0, 0.78)
	if point_type == "npc":
		_add_cylinder(root, Vector3(0, 0.9, 0), Vector3(0, 0, 0), 0.24, 1.3, cloth, "NpcRobe")
		_add_sphere(root, Vector3(0, 1.72, 0), Vector3(0.25, 0.28, 0.25), skin, "NpcHead")
		_add_cylinder(root, Vector3(0, 1.25, -0.32), Vector3(90, 0, 0), 0.035, 0.8, gold, "NpcStaff")
	elif point_type == "checkpoint":
		_add_cylinder(root, Vector3(0, 0.58, 0), Vector3(0, 0, 0), 0.18, 1.12, _stone_mat(), "CheckpointBase")
		_add_sphere(root, Vector3(0, 1.28, 0), Vector3(0.18, 0.30, 0.18), cloth, "CheckpointFlame")
	else:
		_add_block(root, Vector3(0, 0.42, 0), Vector3(1.0, 0.8, 1.0), _make_spatial_material(Color(0.30, 0.18, 0.09), 0.0, 0.9), "SupplyCrate")
		_add_sphere(root, Vector3(0, 1.04, 0), Vector3(0.24, 0.16, 0.24), cloth, "SupplyGlow")

func _hide_all_story_points():
	for key in story_points.keys():
		_set_point_active(key, false)

func _set_point_active(point_id, active):
	if story_points.has(point_id):
		story_points[point_id].set_active(active)
	if story_point_roots.has(point_id):
		story_point_roots[point_id].visible = active

func _clear_enemies():
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()

func start_single_player():
	start_story_mode(false)

func start_multiplayer():
	start_story_mode(false)

func start_story_mode(load_existing = false):
	running = true
	story_started = true
	_clear_enemies()
	if load_existing:
		load_game()
	else:
		story_completed = false
		current_mission_index = 0
		mission_progress = 0
		checkpoint_position = Vector3(0, 3, 0)
		checkpoint_name = "Pandava Camp"
	_apply_character_to_player()
	var player = _get_player()
	if player:
		if load_existing and player.has_method("restore_progression_state"):
			player.restore_progression_state(loaded_player_state)
		elif not load_existing and player.has_method("reset_progression"):
			player.reset_progression()
	_place_player_at_checkpoint()
	_notify_hud_character()
	if load_existing and story_completed:
		_complete_story()
		return
	_start_mission(current_mission_index, load_existing)
	_play_story_stinger(196.0, 0.22)
	save_game()

func continue_story():
	if not has_save():
		start_story_mode(false)
		return
	start_story_mode(true)

func return_to_menu():
	save_game()
	running = false
	story_started = false
	dialogue_playing = false
	_hide_all_story_points()
	_clear_enemies()

func set_low_spec_mode(enabled):
	low_spec_mode = enabled
	_apply_performance_profile()

func _place_player_at_checkpoint():
	var parent = get_parent()
	if parent == null or not parent.has_node("Player"):
		return
	var player = parent.get_node("Player")
	player.translation = checkpoint_position
	if player.has_method("set_checkpoint_position"):
		player.set_checkpoint_position(checkpoint_position)

func _start_mission(index, keep_progress = false):
	current_mission_index = clamp(index, 0, mission_defs.size() - 1)
	var mission = mission_defs[current_mission_index]
	mission_goal = int(mission.get("goal", 1))
	if not keep_progress:
		mission_progress = 0
	battle_wave = 0
	var mission_id = str(mission.get("id", ""))
	if mission_id != "supplies":
		_clear_enemies()
	_hide_all_story_points()
	_activate_mission_points(mission_id)
	_setup_mission_encounters(mission_id)
	_update_mission_hud()
	_show_objective_banner(str(mission.get("title", "")))
	save_game()

func _activate_mission_points(mission_id):
	_set_point_active("camp_checkpoint", true)
	if mission_id == "oath":
		_set_point_active("krishna_intro", true)
	elif mission_id == "supplies":
		for i in range(supply_ids.size()):
			_set_point_active(supply_ids[i], i >= mission_progress)
	elif mission_id == "temple":
		_set_point_active("temple_sage", true)
		_set_point_active("temple_checkpoint", true)
	elif mission_id == "battlefield" or mission_id == "duel":
		_set_point_active("temple_checkpoint", true)

func _setup_mission_encounters(mission_id):
	if mission_id == "raid":
		_spawn_mission_wave([
			Vector3(-14, 1.2, -15),
			Vector3(-8, 1.2, -20),
			Vector3(-4, 1.2, -13),
			Vector3(-18, 1.2, -9)
		], "Kaurava Scout", 105, 17, 5)
	elif mission_id == "battlefield":
		_spawn_battlefield_wave()
	elif mission_id == "duel":
		_spawn_story_enemy(Vector3(0, 1.2, 34), {
			"name": "Rival Commander",
			"health": 260,
			"damage": 24,
			"speed": 4,
			"scale": 1.18,
			"xp": 120,
			"special": 70
		})

func _spawn_battlefield_wave():
	var remaining = mission_goal - mission_progress
	if remaining <= 0:
		return
	battle_wave += 1
	var count = min(3, remaining)
	var positions = []
	for i in range(count):
		positions.append(Vector3(-8 + i * 8, 1.2, 27 + battle_wave * 3))
	_spawn_mission_wave(positions, "Battlefield Guard", 125 + battle_wave * 18, 18 + battle_wave * 2, 4)
	_show_combat_note("Wave %d enters the field" % battle_wave, Color(0.90, 0.64, 0.24))

func _spawn_mission_wave(positions, enemy_name, health, damage, speed):
	for pos in positions:
		if _get_active_enemy_count() < max_active_enemies:
			_spawn_story_enemy(pos, {
				"name": enemy_name,
				"health": health,
				"damage": damage,
				"speed": speed,
				"xp": 35,
				"special": 24
			})

func _spawn_story_enemy(pos, profile):
	var parent = get_parent()
	if parent == null or EnemyScene == null:
		return null
	var enemy = EnemyScene.instance()
	enemy.translation = pos
	parent.add_child(enemy)
	if enemy.has_method("configure"):
		enemy.configure(profile)
	else:
		enemy.display_name = str(profile.get("name", "Enemy Warrior"))
		enemy.max_health = int(profile.get("health", enemy.max_health))
		enemy.health = enemy.max_health
		enemy.attack_damage = int(profile.get("damage", enemy.attack_damage))
		enemy.speed = int(profile.get("speed", enemy.speed))
	if profile.has("scale"):
		enemy.scale = Vector3.ONE * float(profile.get("scale", 1.0))
	return enemy

func spawn_enemy():
	var spawn_center = Vector3.ZERO
	if get_parent() and get_parent().has_node("Player"):
		spawn_center = get_parent().get_node("Player").translation
	var angle = rand_range(0.0, TAU)
	var distance = rand_range(12.0, 22.0)
	var x = spawn_center.x + cos(angle) * distance
	var z = spawn_center.z + sin(angle) * distance
	return _spawn_story_enemy(Vector3(clamp(x, -44.0, 44.0), 1.2, clamp(z, -44.0, 44.0)), {
		"name": "Kaurava Soldier",
		"health": 110,
		"damage": 17,
		"speed": 5,
		"xp": 30,
		"special": 20
	})

func handle_interaction(interact_id, interactable):
	if not running:
		return
	if dialogue_playing:
		return
	if interact_id == "camp_checkpoint":
		_set_checkpoint(Vector3(0, 3, 0), "Pandava Camp")
		_show_combat_note("Camp checkpoint saved", Color(0.58, 0.86, 1.0))
		return
	if interact_id == "temple_checkpoint":
		_set_checkpoint(Vector3(0, 3, -28), "Stone Shrine")
		_show_combat_note("Temple checkpoint saved", Color(0.58, 0.86, 1.0))
		return

	if interact_id == "krishna_intro":
		_set_point_active(interact_id, false)
		yield(_play_dialogue([
			["Krishna", "The field ahead is not only war, Partha. It is a test of clarity."],
			["Krishna", "Protect the people, honor your oath, and let skill serve dharma."],
			["Arjun", "Then I will walk the path with a steady bow and an open heart."]
		]), "completed")
		_advance_mission_progress(1)
	elif supply_ids.has(interact_id):
		_set_point_active(interact_id, false)
		if interact_id == "forest_herbs":
			_spawn_mission_wave([Vector3(-20, 1.2, -18), Vector3(-15, 1.2, -24)], "Forest Raider", 90, 15, 5)
		yield(_play_dialogue([["Scout", _supply_dialogue(interact_id)]]), "completed")
		_advance_mission_progress(1)
	elif interact_id == "temple_sage":
		_set_point_active(interact_id, false)
		yield(_play_dialogue([
			["Temple Sage", "A warrior who remembers compassion is never alone in battle."],
			["Temple Sage", "Take this blessing. Let your resolve burn brighter than fear."]
		]), "completed")
		_grant_blessing()
		_advance_mission_progress(1)
	if interactable and is_instance_valid(interactable):
		interactable.set_active(false)

func _supply_dialogue(interact_id):
	if interact_id == "village_supplies":
		return "The village offers grain and cloth. Their hope travels with you."
	if interact_id == "forest_herbs":
		return "Healing herbs secured. The forest has answered the army's need."
	return "The river vessels are filled. The camp will endure another night."

func _grant_blessing():
	var player = _get_player()
	if player and player.has_method("add_progression_reward"):
		player.add_progression_reward(60, 100)

func notify_enemy_defeated(_enemy, source = null, xp_reward = 35, special_reward = 24):
	defeated_total += 1
	var reward_target = source
	if reward_target == null or not is_instance_valid(reward_target) or not reward_target.has_method("add_progression_reward"):
		reward_target = _get_player()
	if reward_target and reward_target.has_method("add_progression_reward"):
		reward_target.add_progression_reward(xp_reward, special_reward)

	if not running:
		return
	var mission_id = _current_mission_id()
	if mission_id == "raid" or mission_id == "battlefield" or mission_id == "duel":
		_advance_mission_progress(1)
		if mission_id == "battlefield" and mission_progress < mission_goal and _get_active_enemy_count() <= 1:
			_spawn_battlefield_wave()

func _advance_mission_progress(amount):
	mission_progress = clamp(mission_progress + amount, 0, mission_goal)
	_update_mission_hud()
	save_game()
	if mission_progress >= mission_goal:
		_complete_current_mission()

func _complete_current_mission():
	var mission = mission_defs[current_mission_index]
	var mission_title = str(mission.get("title", "Mission"))
	var cp = mission.get("checkpoint", checkpoint_position)
	_set_checkpoint(cp, mission_title)
	_show_combat_note("%s complete" % mission_title, Color(0.97, 0.84, 0.38))
	_play_story_stinger(260.0, 0.25)
	current_mission_index += 1
	mission_progress = 0
	save_game()
	if current_mission_index >= mission_defs.size():
		yield(get_tree().create_timer(1.0), "timeout")
		_complete_story()
	else:
		yield(get_tree().create_timer(1.2), "timeout")
		_start_mission(current_mission_index)

func _complete_story():
	running = false
	story_completed = true
	_hide_all_story_points()
	_clear_enemies()
	var hud = _get_hud()
	if hud and hud.has_method("show_story_complete"):
		hud.show_story_complete()
	var player = _get_player()
	if player and player.has_method("play_victory_pose"):
		player.play_victory_pose()
	_show_combat_note("The assault is broken. Dharma holds the field.", Color(0.97, 0.84, 0.38))
	save_game()

func _set_checkpoint(pos, name):
	checkpoint_position = pos
	checkpoint_name = name
	var player = _get_player()
	if player and player.has_method("set_checkpoint_position"):
		player.set_checkpoint_position(pos)
	var hud = _get_hud()
	if hud and hud.has_method("show_checkpoint"):
		hud.show_checkpoint(name)
	save_game()

func on_player_defeated():
	_show_combat_note("You return to %s." % checkpoint_name, Color(1.0, 0.45, 0.28))
	save_game()

func _play_dialogue(lines):
	dialogue_playing = true
	var hud = _get_hud()
	for entry in lines:
		if hud and hud.has_method("show_dialogue"):
			hud.show_dialogue(str(entry[0]), str(entry[1]))
		_play_story_stinger(164.0 + rand_range(-16.0, 20.0), 0.08)
		yield(get_tree().create_timer(2.35), "timeout")
	if hud and hud.has_method("hide_dialogue"):
		hud.hide_dialogue()
	dialogue_playing = false

func _show_objective_banner(text):
	var hud = _get_hud()
	if hud and hud.has_method("show_objective_banner"):
		hud.show_objective_banner(text)

func _show_combat_note(message, color):
	var hud = _get_hud()
	if hud and hud.has_method("show_combat_feedback"):
		hud.show_combat_feedback(message, color)

func _update_mission_hud():
	var hud = _get_hud()
	if hud == null or not hud.has_method("set_mission"):
		return
	var mission = mission_defs[current_mission_index]
	hud.set_mission(str(mission.get("title", "")), str(mission.get("objective", "")), mission_progress, mission_goal)

func _current_mission_id():
	if current_mission_index < 0 or current_mission_index >= mission_defs.size():
		return ""
	return str(mission_defs[current_mission_index].get("id", ""))

func save_game():
	if not story_started:
		_notify_hud_continue_state()
		return
	var player_state = {}
	var player = _get_player()
	if player and player.has_method("get_progression_state"):
		player_state = player.get_progression_state()
	var file = File.new()
	if file.open(save_path, File.WRITE) != OK:
		return
	file.store_var({
		"selected_character_key": selected_character_key,
		"current_mission_index": current_mission_index,
		"mission_progress": mission_progress,
		"checkpoint_position": checkpoint_position,
		"checkpoint_name": checkpoint_name,
		"defeated_total": defeated_total,
		"story_completed": story_completed,
		"player_state": player_state
	})
	file.close()
	_notify_hud_continue_state()

func load_game():
	var file = File.new()
	if not file.file_exists(save_path):
		return false
	if file.open(save_path, File.READ) != OK:
		return false
	var data = file.get_var()
	file.close()
	selected_character_key = str(data.get("selected_character_key", "arjun"))
	var raw_mission_index = int(data.get("current_mission_index", 0))
	story_completed = bool(data.get("story_completed", false)) or raw_mission_index >= mission_defs.size()
	current_mission_index = clamp(raw_mission_index, 0, mission_defs.size() - 1)
	mission_progress = int(data.get("mission_progress", 0))
	checkpoint_position = data.get("checkpoint_position", Vector3(0, 3, 0))
	checkpoint_name = str(data.get("checkpoint_name", "Pandava Camp"))
	defeated_total = int(data.get("defeated_total", 0))
	loaded_player_state = data.get("player_state", {})
	return true

func has_save():
	var file = File.new()
	return file.file_exists(save_path)

func _notify_hud_continue_state():
	var hud = _get_hud()
	if hud and hud.has_method("set_continue_available"):
		hud.set_continue_available(has_save())

func select_character(character_key):
	if character_presets.has(character_key):
		selected_character_key = character_key
		play_ui_sound()

func get_selected_character_data():
	if character_presets.has(selected_character_key):
		var data = character_presets[selected_character_key].duplicate(true)
		data["character_key"] = selected_character_key
		return data
	return character_presets["arjun"]

func apply_selected_character_to_player(player):
	if player == null:
		return
	var data = get_selected_character_data()
	var starter_scene = StarterWeaponScene
	if data.has("starter_weapon_scene"):
		var starter_path = str(data.get("starter_weapon_scene", ""))
		if starter_path != "":
			var loaded_scene = load(starter_path)
			if loaded_scene and loaded_scene is PackedScene:
				starter_scene = loaded_scene
	if player.has_method("apply_character_preset"):
		player.call("apply_character_preset", data, starter_scene)

func _apply_character_to_player():
	var player = _get_player()
	if player:
		apply_selected_character_to_player(player)

func _notify_hud_character():
	var hud = _get_hud()
	if hud and hud.has_method("show_selected_character"):
		hud.call_deferred("show_selected_character", get_selected_character_data())

func _get_player():
	var parent = get_parent()
	if parent and parent.has_node("Player"):
		return parent.get_node("Player")
	return null

func _get_hud():
	var parent = get_parent()
	if parent and parent.has_node("HUD"):
		return parent.get_node("HUD")
	return null

func _get_active_enemy_count():
	return get_tree().get_nodes_in_group("enemies").size()

func _update_day_night(delta):
	if running:
		day_time = fposmod(day_time + delta / max(day_cycle_seconds, 1.0), 1.0)
	var parent = get_parent()
	if parent == null:
		return
	var light_amount = clamp(sin(day_time * TAU - PI * 0.35) * 0.5 + 0.55, 0.18, 1.0)
	if parent.has_node("DirectionalLight"):
		var sun = parent.get_node("DirectionalLight")
		sun.rotation_degrees.x = -25.0 - light_amount * 46.0
		sun.light_energy = 0.30 + light_amount * 0.75
		sun.light_color = Color(1.0, 0.78 + light_amount * 0.18, 0.58 + light_amount * 0.28)
	if parent.has_node("WorldEnvironment"):
		var world_env = parent.get_node("WorldEnvironment")
		if world_env.environment:
			world_env.environment.ambient_light_energy = 0.42 + light_amount * 0.58
			world_env.environment.ambient_light_color = Color(0.30 + light_amount * 0.38, 0.36 + light_amount * 0.34, 0.46 + light_amount * 0.28)
			world_env.environment.fog_color = Color(0.28 + light_amount * 0.35, 0.33 + light_amount * 0.34, 0.42 + light_amount * 0.28)

func play_fire_sound():
	_play_synth_tone(fire_player, 196.0, 0.10, 0.22, "fire")

func play_hit_sound():
	_play_synth_tone(hit_player, 260.0, 0.07, 0.18, "hit")

func play_death_sound():
	_play_synth_tone(death_player, 92.0, 0.24, 0.22, "death")

func play_ui_sound():
	_play_synth_tone(ui_player, 520.0, 0.05, 0.10, "ui")

func _play_story_stinger(frequency, duration):
	_play_synth_tone(music_player, frequency, duration, duration + 0.08, "music")

func _play_synth_tone(player, frequency, duration, buffer_length, tone_type):
	if player == null:
		return
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = buffer_length
	player.stream = generator
	player.play()
	var playback = player.get_stream_playback()
	if playback == null:
		return
	var sample_rate = 22050.0
	var sample_count = int(duration * sample_rate)
	var phase = 0.0
	var low_phase = 0.0
	var phase_step = TAU * frequency / sample_rate
	var low_step = TAU * (frequency * 0.5) / sample_rate
	for i in range(sample_count):
		var progress = float(i) / float(max(sample_count, 1))
		var envelope = 1.0 - progress
		envelope = envelope * envelope
		var sample = sin(phase) * envelope * 0.50
		if tone_type == "hit":
			sample += sin(phase * 2.1) * envelope * 0.14
		elif tone_type == "death":
			sample += sin(low_phase) * envelope * 0.18
		elif tone_type == "ui":
			sample *= 0.52
		elif tone_type == "music":
			sample = (sin(phase) * 0.18 + sin(low_phase) * 0.34) * envelope
		playback.push_frame(Vector2(sample, sample))
		phase += phase_step
		low_phase += low_step

func _add_banner(pos, color, node_name):
	var root = Spatial.new()
	root.name = node_name
	root.translation = pos
	story_root.add_child(root)
	var pole_mat = _make_spatial_material(Color(0.25, 0.13, 0.06), 0.0, 0.88)
	var cloth_mat = _make_spatial_material(color, 0.0, 0.82)
	_add_cylinder(root, Vector3(0, 1.1, 0), Vector3(0, 0, 0), 0.04, 2.2, pole_mat, "BannerPole")
	_add_block(root, Vector3(0.36, 1.65, 0), Vector3(0.68, 0.52, 0.04), cloth_mat, "BannerCloth")

func _add_block(parent, pos, scale_amount, material, node_name):
	var block = MeshInstance.new()
	block.name = node_name
	var mesh = CubeMesh.new()
	mesh.size = Vector3(1, 1, 1)
	block.mesh = mesh
	block.translation = pos
	block.scale = scale_amount
	block.material_override = material
	parent.add_child(block)
	return block

func _add_cylinder(parent, pos, rot, radius, height, material, node_name):
	var item = MeshInstance.new()
	item.name = node_name
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	item.mesh = mesh
	item.translation = pos
	item.rotation_degrees = rot
	item.material_override = material
	parent.add_child(item)
	return item

func _add_sphere(parent, pos, scale_amount, material, node_name):
	var item = MeshInstance.new()
	item.name = node_name
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	item.mesh = mesh
	item.translation = pos
	item.scale = scale_amount
	item.material_override = material
	parent.add_child(item)
	return item

func _stone_mat():
	return _make_spatial_material(Color(0.34, 0.32, 0.28), 0.0, 0.92)

func _make_spatial_material(albedo, metallic = 0.0, roughness = 0.8, transparent = false):
	var mat = SpatialMaterial.new()
	mat.albedo_color = albedo
	mat.metallic = metallic
	mat.roughness = roughness
	if transparent:
		mat.flags_transparent = true
	return mat
