extends Node

@export var damage: float = 0.0

func on_hitbox_response(obj: Node3D) -> bool:
	for c in obj.get_children():
		if c is HealthComponent:
			c.take_damage(damage)
			return true
	return false