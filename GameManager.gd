extends Node

export (PackedScene) var EnemyScene = preload("res://Scenes/Enemy.tscn")

var spawn_interval = 3.0
var spawn_timer = 0.0
var running = false

func _process(delta):
    if not running:
        return
    spawn_timer += delta
    if spawn_timer >= spawn_interval:
        spawn_timer = 0
        spawn_enemy()

func spawn_enemy():
    var e = EnemyScene.instance()
    var x = rand_range(-20,20)
    var z = rand_range(-20,20)
    e.translation = Vector3(x,1,z)
    get_parent().add_child(e)

func start_single_player():
    running = true

func start_multiplayer():
    # Basic stub for LAN multiplayer: the full networking implementation
    # requires additional setup. For now this toggles a placeholder.
    print("Multiplayer mode selected — networking not implemented yet.")
