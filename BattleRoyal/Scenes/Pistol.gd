extends "res://Scenes/Weapon.gd"

func _ready():
    # pistol defaults
    if fire_rate == 0:
        fire_rate = 0.28
    if damage == 0:
        damage = 20
    if not bullet_scene:
        bullet_scene = preload("res://Scenes/Bullet.tscn")
