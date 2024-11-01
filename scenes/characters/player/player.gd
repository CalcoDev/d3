class_name PlayerController
extends CharacterBody3D

const SENS_MULT := 0.006
@export var look_sensitivity := 1.0

@export var jump_force := 6.0
@export var auto_bhop := true
@export var walk_speed := 7.0
@export var sprint_speed := 8.5

# @export var headbob_move_amount :=

var _wish_dir := Vector3.ZERO

func _ready() -> void:
	for child: VisualInstance3D in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity * SENS_MULT)
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity * SENS_MULT)
			%Camera3D.rotation.x = clampf(%Camera3D.rotation.x, -PI*0.5, PI*0.5)

func _process(delta: float) -> void:
	_handle_movement(delta)
	pass

# func _physics_process(delta: float) -> void:
# 	pass

func _handle_movement(delta: float) -> void:
	var input = Input.get_vector("left", "right", "up", "down").normalized()
	_wish_dir = self.global_transform.basis * Vector3(input.x, 0.0, input.y)
	
	if is_on_floor():
		if Input.is_action_pressed("jump"):
			self.velocity.y = jump_force
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)

func _handle_air_physics(delta: float) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	move_and_slide()

func _handle_ground_physics(delta: float) -> void:
	self.velocity.x = _wish_dir.x * walk_speed
	self.velocity.z = _wish_dir.z * walk_speed
	move_and_slide()
