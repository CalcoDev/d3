class_name HealthComponent
extends Node

signal on_health_changed(previous: float, current: float, maximum: float)
signal on_died()

@export var health: float = 100.0
@export var max_health: float = 100.0

func is_dead() -> bool:
    return health <= 0

func _ready() -> void:
    health = max_health

func get_health_percentage() -> float:
    if max_health <= 0:
        return 0.0
    return min(health / max_health, 1.0)

func take_damage(damage: float) -> void:
    var old_health = health
    health -= damage
    if health <= 0:
        health = 0
        emit_signal("on_died")
	on_health_changed.emit(old_health, health, max_health)

func heal(amount: float) -> void:
    var old_health = health
    health += amount
    if health > max_health:
        health = max_health
	on_health_changed.emit(old_health, health, max_health)

func reset_health() -> void:
    var old_health = health
    health = max_health
	on_health_changed.emit(old_health, health, max_health)