class_name HurtboxComponent
extends Area3D

signal on_hit(damage: float, by: Node3D)

@onready var _shape: CollisionShape3D = find_children("*", "CollisionShape3D")[0]
@export var enabled: bool = true:
	get():
		return not _shape.disabled
	set(value):
		monitoring = value
		monitorable = value
		_shape.disabled = not value

@export_group("References")
@export var health: HealthComponent
@export var faction: FactionComponent

@export_group("Hurtbox Settings")
@export var damage_delay: float = 0.05
var _damage_timer: float = 0.0

func _ready() -> void:
	enabled = enabled

func _process(delta: float) -> void:
	_damage_timer = maxf(_damage_timer - delta, 0.0)

func get_hit(damage: float, by: Node3D) -> bool:
	if _damage_timer > 0.0:
		return false
	health.take_damage(damage)
	on_hit.emit(damage, by)
	_damage_timer = damage_delay
	return true