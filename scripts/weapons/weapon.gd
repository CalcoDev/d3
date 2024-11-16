# Generic class used to simply get access to these methods basically.
class_name Weapon
extends Node

class FireParams:
	var direction: Vector3 = Vector3.ZERO

signal on_fired(fire_params: FireParams)
signal on_charge(charge: float, max_charge: float)

@export_group("References")
@export var faction: FactionComponent
@export_flags_3d_physics var collision_layers: int = 0

@export_group("Weapon Settings")
@export var instant: bool = true

@export var charge_time: float = 0.0
var is_charging: bool = false
var _charge_timer: float = 0.0

@export var fire_rate: float = 0.0
var _fire_rate_timer: float = 0.0

# Lifecycle
func _process(delta: float) -> void:
	_update_charge(delta)
	_update_fire_timer(delta)

# Charging
func start_charge() -> void:
	if instant or is_charging:
		return
	is_charging = true
	_charge_timer = 0.0
	
func stop_charge() -> void:
	if instant or not is_charging:
		return
	is_charging = false

func get_charge_percentage() -> float:
	return _charge_timer / charge_time

func _update_charge(delta: float) -> void:
	if is_charging:
		_charge_timer = min(_charge_timer + delta, charge_time)
		on_charge.emit(_charge_timer, charge_time)

# Firing
func fire() -> void:
	if _fire_rate_timer > 0.0:
		return
	on_fired.emit()
	_fire_rate_timer = fire_rate

func _update_fire_timer(delta: float) -> void:
	_fire_rate_timer = max(_fire_rate_timer - delta, 0.0)