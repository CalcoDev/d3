# Generic class used to simply get access to these methods basically.
class_name Weapon
extends Node

class FireParams:
	var position: Vector3 = Vector3.INF
	var direction: Vector3 = Vector3.ZERO
	var charge_percentage: float = 0.0
	var charge: float = 0.0
	var up_dir: Vector3 = Vector3.ZERO
	
	@warning_ignore("shadowed_variable")
	func _init(pos: Vector3, d: Vector3, cp: float, c: float, up_dir: Vector3) -> void:
		self.position = pos
		self.direction = d
		self.charge_percentage = cp
		self.charge = c
		self.up_dir = up_dir

signal on_fired(fire_params: FireParams)
signal on_charge(charge: float)

signal on_begin_charge()
signal on_end_charge()

@export_group("References")
@export var faction: FactionComponent
@export_flags_3d_physics var collision_layers: int = 0

@export_group("Weapon Settings")
@export var hold_down: bool = true
@export var instant: bool = true

@export var charge_time: float = 0.0
var is_charging: bool = false
var _charge_timer: float = 0.0

@export var fire_rate: float = 0.0
var _fire_rate_timer: float = 0.0

var weapon_owner: Node3D = null

# Lifecycle
func _ready() -> void:
	pass

func _process(delta: float) -> void:
	_update_charge(delta)
	_update_fire_timer(delta)

# Charging
func start_charge() -> bool:
	if _fire_rate_timer > 0.0 or instant or is_charging:
		return false
	is_charging = true
	_charge_timer = 0.0
	on_begin_charge.emit()
	return true
	
func stop_charge() -> bool:
	if instant or not is_charging:
		return false
	is_charging = false
	on_end_charge.emit()
	return true

func finish_charge(position: Vector3, direction: Vector3, up_dir: Vector3) -> bool:
	stop_charge()
	return fire(position, direction, up_dir)

func get_charge_percentage() -> float:
	return minf(1.0, _charge_timer / charge_time)

func _update_charge(delta: float) -> void:
	if is_charging:
		_charge_timer = minf(_charge_timer + delta, charge_time)
		on_charge.emit(_charge_timer)

# Firing
func fire(position: Vector3, direction: Vector3, up_dir: Vector3) -> bool:
	if _fire_rate_timer > 0.0:
		return false
	var params := FireParams.new(position, direction, get_charge_percentage(), _charge_timer, up_dir)
	on_fired.emit(params)
	_fire_rate_timer = fire_rate
	return true

func _update_fire_timer(delta: float) -> void:
	_fire_rate_timer = max(_fire_rate_timer - delta, 0.0)