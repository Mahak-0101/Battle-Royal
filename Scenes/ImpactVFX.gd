extends Node

export(float) var lifetime = 0.6

func _ready():
    yield(get_tree().create_timer(lifetime), "timeout")
    queue_free()
