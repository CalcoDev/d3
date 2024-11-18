class_name PlayerHeldItem
extends Node3D

@export_group("References")
@export var player: PlayerController
@export var swayer: Node3D

@export_group("Sway & Lag Settings")
@export var sway_amount: float = 0.05
@export var sway_speed: float = 10.0

@export var max_lag_amount: float = 0.05
@export var lag_amount: float = 0.02
@export var lag_speed: float = 5.0

var target_offset: Vector3 = Vector3.ZERO
var current_offset: Vector3 = Vector3.ZERO
func _process(delta: float) -> void:
	var vel := player.linear_velocity
# 	print(_vec_rel_to_look(vel))
	target_offset = -_vec_rel_to_look(vel) * lag_amount
	if target_offset.length_squared() > max_lag_amount * max_lag_amount:
		target_offset = target_offset.normalized() * max_lag_amount
	current_offset = current_offset.lerp(target_offset, lag_speed * delta)
	swayer.position = current_offset

func _vec_rel_to_look(vec: Vector3) -> Vector3:
	var look_angle := player._orientation.rotation.y
	var move_angle := atan2(vec.z, vec.x)
	var u := angle_difference(look_angle, move_angle)
	var v := PI * 0.5 - u
	var mag := vec.length()
	var x := mag * cos(u)
	var y := mag * cos(v)
	return Vector3(x, vec.y, y)

func angle_difference(angle1, angle2):
	var diff = angle2 - angle1
	return diff if abs(diff) < 180 else diff + (360 * -sign(diff))