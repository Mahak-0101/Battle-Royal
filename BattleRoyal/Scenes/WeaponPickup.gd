extends Area

export (PackedScene) var weapon_scene
export (String) var weapon_name = "Weapon"

func _ready():
    set_deferred("monitoring", true)
    connect("body_entered", self, "_on_body_entered")

func _on_body_entered(body):
    if body == null:
        return
    if body.has_method("pickup_weapon"):
        body.pickup_weapon(weapon_scene, weapon_name)
        queue_free()
