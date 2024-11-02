class_name PlayerController
extends RigidBody3D

@export_group("Look Around")
@export var look_sensitivity := 1.0
const SENS_MULT := 0.006

@export_group("Hover")
@export var hover_ground: bool = false
@export var ground_hover_dist: float = 0.5
@export var ride_spring_strength: float = 1.0
@export var ride_spring_damper: float = 1.0

@export_group("Groundedness")
@export_flags_3d_physics var ground_layers: int = 1
@export_range(0.0, 90.0) var max_slope_angle: float = 45.0
var _was_grounded: bool = false
var _is_grounded: bool = false
var _is_on_slope: bool = false
var _floor_normal := Vector3.UP
var _floor_angle: float = 0.0

var _is_touching_ground_but_maybe_not_floor: bool = false

@export_group("Movement")
@export var walk_speed: float = 8.0
@export var sprint_speed: float = 6.0
@export var accel: float = 200.0
@export var accel_factor_from_dot: Curve
@export var max_accel_force: float = 150.0
@export var max_accel_factor_from_dot: Curve
@export var max_fall: float = 200.0

@export var air_accel: float = 20.0
@export var air_max_accel: float = 20.0

var _target_speed: float = 0.0

# stair handling
@export_group("Stairs")
@export var wall_angle_tolerance: float = 10.0
@export var max_step_height: float = 0.35

@export var max_ceiling_angle: float = 10.0

var _is_touching_wall: bool = false
var _wall_normal: Vector3 = Vector3.ZERO

var _is_touching_ceiling: bool = false
var _ceiling_normal: Vector3 = Vector3.ZERO


# Bobbing
const BOB_AMOUNT: Vector2 = Vector2(0.1, 0.2) 
const BOB_FREQ: float = 2.7
const BOB_RESET_SPEED: float = 2.5
const BOB_MOVE_SPEED: float = 10.0
const BOB_SHIFT: float = PI / 2.0
var bob_time: float = 0.0

@export_group("Jump")
@export var jump_height_approx: float = 2.0
@export var jump_cancel_rate: float = 5.0

var _is_jumping: bool = false

const JUMP_BUFFER_TIME: float = 0.15
const COYOTE_BUFFER_TIME: float = 0.15
var _jump_buffer_timer: float = 0.0
var _coyote_buffer_timer: float = 0.0

var _jump_inp_released: bool = false
var _jump_descent: bool = false

# who knows lol
@onready var _orientation: Node3D = %Orientation
@onready var _camera: Camera3D = %Camera3D
@onready var _head: Node3D = %Head
@onready var _world_model: Node3D = %WorldModel

var _wish_dir := Vector3.ZERO
var _wish_vel := Vector3.ZERO

@export_group("wtf man")
@export var _ground_raycasts: Array[RayCast3D] = []

# @onready var _ground_cast: ShapeCast3D = $"Orientation/Raycasts/Ground"
# @onready var _ceiling_cast: ShapeCast3D = $"Orientation/Raycasts/Ceiling"
# @onready var _wall_front_cast: ShapeCast3D = $"Orientation/Raycasts/Wall_Front"
# @onready var _wall_back_cast: ShapeCast3D = $"Orientation/Raycasts/Wall_Back"
# @onready var _wall_left_cast: ShapeCast3D = $"Orientation/Raycasts/Wall_Left"
# @onready var _wall_right_cast: ShapeCast3D = $"Orientation/Raycasts/Wall_Right"

func _ready() -> void:
	# TODO(calco): Remove in prod
	_camera.current = false
	for child: VisualInstance3D in _world_model.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			_orientation.rotate_y(-event.relative.x * look_sensitivity * SENS_MULT)
			_camera.rotate_x(-event.relative.y * look_sensitivity * SENS_MULT)
			_camera.rotation.x = clampf(_camera.rotation.x, -PI*0.5, PI*0.5)

func _process(delta: float) -> void:
	var input = Input.get_vector("left", "right", "up", "down").normalized()
	var abs_dir = Vector3(input.x, 0.0, input.y)
	_wish_dir = _orientation.global_transform.basis * abs_dir
	
	if Input.is_action_pressed("sprint"):
		_target_speed = sprint_speed
	else:
		_target_speed = walk_speed
	
	_coyote_buffer_timer -= delta
	_jump_buffer_timer -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME
		
	if _is_jumping and Input.is_action_just_released("jump"):
		_jump_inp_released = true
	
	# View bobbing effect:
	var target_pos := _camera.position
	if _is_grounded:
		var forward = abs(abs_dir.z) > 0.0
		var right = abs(abs_dir.x) > 0.0
		# Y Axis bob
		if forward or right:
			target_pos.y = sin(bob_time * BOB_FREQ) * BOB_AMOUNT.y
		# X Axis bob
		if right:
			target_pos.x = sin(bob_time * BOB_FREQ + BOB_SHIFT) * BOB_AMOUNT.x
		else:
# 			target_pos.x = lerpf(target_pos.x, 0.0, delta * BOB_RESET_SPEED)
			target_pos.x = move_toward(target_pos.x, 0.0, delta * BOB_RESET_SPEED)
		# Lerp back to 0 bob
		if not forward and not right:
# 			target_pos.y = lerpf(target_pos.y, 0.0, delta * BOB_RESET_SPEED)
			target_pos.y = move_toward(target_pos.y, 0.0, delta * BOB_RESET_SPEED)
			bob_time = asin(target_pos.y / BOB_AMOUNT.y)
		# Update bob
		if forward or right:
			bob_time += delta * BOB_FREQ
# 		print(target_pos)
		_camera.position = _camera.position.lerp(target_pos, delta * BOB_MOVE_SPEED)


var _rb: PhysicsDirectBodyState3D
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_rb = state
	var delta := get_physics_process_delta_time()
	
	# handle groundedness and checks
# 	var f := global_position

	_handle_raycasts()
	
	if not _was_grounded and _is_grounded:
		_wish_vel = _wish_vel.slide(_floor_normal)
		_is_jumping = false
	if _was_grounded and not _is_grounded:
		_wish_vel = _wish_vel.slide(Vector3.UP)

	# Jump
	if _is_grounded or _was_grounded:
		_coyote_buffer_timer = COYOTE_BUFFER_TIME
	if _is_jumping and _jump_inp_released:
		linear_velocity.y *= 0.75
		_jump_inp_released = false
		_jump_descent = true
	if _is_jumping and _jump_descent and linear_velocity.y > 0.0:
		apply_force(Vector3.DOWN * jump_cancel_rate)
	if _coyote_buffer_timer > 0.0 and _jump_buffer_timer > 0.0:
		_jump_buffer_timer = 0.0
		_coyote_buffer_timer = 0.0
		var gravity_str: float = ProjectSettings.get_setting("physics/3d/default_gravity")
		var force := sqrt(jump_height_approx * gravity_str * 2.5) * mass
		linear_velocity.y = 0.0
		apply_impulse(Vector3.UP * force)
		_is_jumping = true
		_jump_inp_released = false
		_jump_descent = false
	
	# Movement
	if _is_grounded:
		_handle_ground_movement(delta)
	else:
		if _is_touching_ground_but_maybe_not_floor:
			return
		_handle_air_movement(delta)
	
func _physics_process(_delta: float) -> void:
	pass

func _handle_raycasts() -> void:
	_was_grounded = _is_grounded
	_is_grounded = false
	_is_on_slope = false
	_is_touching_ground_but_maybe_not_floor = false
	_is_touching_wall = false
	_is_touching_ceiling = false
	
	var colls: Dictionary = {}
	
	var col_cnt = _rb.get_contact_count()
	for cidx in col_cnt:
		var obj := _rb.get_contact_collider_object(cidx)
		var local_pos := to_local(_rb.get_contact_local_position(cidx))
		var normal := _rb.get_contact_local_normal(cidx)
		if obj.get_instance_id() not in colls:
			colls[obj] = {
				"positions": [],
				"normals": [],
				"idx": cidx
			}
		colls[obj]["positions"].append(local_pos)
		colls[obj]["normals"].append(normal)
	
	print("")
	for obj_id in colls:
		var obj_dict: Dictionary = colls[obj_id]
		var obj := _rb.get_contact_collider_object(obj_dict["idx"])
		var layer = obj.get("collision_layer")
		if layer == null or layer & ground_layers == 0:
			continue
		print("Checking obj: ", obj)
		var positions = colls[obj]["positions"]
		var normals = colls[obj]["normals"]
		
		var average_normal := Vector3.ZERO
		
		var is_not_floor_ramp := false
		var is_floor := false
		var is_wall := false
		var is_ceiling := false
		for i in range(positions.size()):
			var pos: Vector3 = positions[i]
			var normal: Vector3 = normals[i]
			average_normal += normal
			if pos.y < 0.1:
				if _is_floor(normal):
					is_floor = true
				else:
					is_not_floor_ramp = true
			if pos.y > 0.95:
				is_ceiling = true
			if _is_wall(normal):
				is_wall = true
			if _is_ceiling(normal):
				is_ceiling = true
		if is_ceiling:
			is_wall = false
			is_floor = false
		
		average_normal = average_normal.normalized()
		if is_floor:
			print("Floor detected with object:", obj)
			_floor_normal = average_normal
			_floor_angle = Vector3.UP.angle_to(_floor_normal)
			_is_grounded = true
			if _floor_angle > deg_to_rad(0.01):
				_is_on_slope = true
		if is_not_floor_ramp:
# 			print("Is floor but cannot walk here:", obj)
			_is_touching_ground_but_maybe_not_floor = true
		if is_wall:
			print("Wall detected with object:", obj)
			_is_touching_wall = true
			_wall_normal = average_normal
			# floor ish
# 			print("wall: ", min_y, " ", max_y)
# 			if min_y < 0.05 and max_y < max_step_height:
# 				print("should be skippable!")
		if is_ceiling:
			print("Ceiling detected with object:", obj)
			_is_touching_ceiling = true
			_ceiling_normal = average_normal
	
	# stair handling stuff
	# rayacst to check if on stair
	
# 	var bottom_raycast := raycast(global_position, Vector3.DOWN * -(max_step_height + 0.15), 1)
# 	var forward_raycast := raycast(global_position + global_transform.basis.z * 0.5, Vector3.DOWN * -max_step_height, 1)
# 	
# 	if not _is_floor(_floor_normal) and bottom_raycast and forward_raycast:
# 		print("is on stairs I think")
	
# 	if _is_grounded:
# 		_last_frame_was_on_floor = Engine.get_process_frames()

# 	print(_is_touching_wall, " ", _wall_normal)
	
# 	_was_grounded = _is_grounded
# 	_is_grounded = false
# 	_is_on_slope = false
# 	_is_touching_ground_but_maybe_not_floor = false
# 	_is_touching_wall = false
# 	_is_touching_ceiling = false
# 	for r in _ground_raycasts:
# 		r.force_raycast_update()
# 		if r.is_colliding():
# 			var n := r.get_collision_normal()
# 			_is_touching_ground_but_maybe_not_floor = true
# 			if _is_floor(n):
# 				_is_grounded = true
# 				_floor_normal = n
# 				_floor_angle = Vector3.UP.angle_to(n)
# 				if _floor_angle > deg_to_rad(0.01):
# 					_is_on_slope = true
# 	print(_floor_normal)
			
# 	_was_grounded = _is_grounded
# 	_is_grounded = _ground_cast.is_colliding()
# 	
# 	print(_ground_cast.is_colliding())
# 	
# 	_is_on_slope = false
# 	
# 	# slopes
# 	var cnt = _ground_cast.get_collision_count()
# 	var avg_norm := Vector3.ZERO
# 	for idx in cnt:
# 		var n := _ground_cast.get_collision_normal(idx)
# 		avg_norm += n
# 	avg_norm = avg_norm.normalized()

func _handle_ground_movement(delta: float) -> void:
	var unit_vel := linear_velocity.normalized()
	var vel_dot := _wish_dir.dot(unit_vel)
	var curr_accel := accel * accel_factor_from_dot.sample((vel_dot + 1.0) / 2.0)
	
	if _is_on_slope:
		var gravity_str: float = ProjectSettings.get_setting("physics/3d/default_gravity")
		var gravity_vec: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
		var req_force := -gravity_vec * gravity_str
		apply_force(req_force)
	
	var slope_dir := _wish_dir.slide(_floor_normal).normalized()
	var wish_vel := slope_dir * _target_speed
	_wish_vel = _wish_vel.move_toward(wish_vel, curr_accel * delta)
	
	# stair stuff
# 	print("groinud momemem")
	if _is_touching_wall and false:
		const BOTTOM_RAYCAST_LEN: float = 0.5 + 0.2
		const TOP_RAYCAST_LEN: float = 0.5 + 0.25
		var from := global_position + Vector3.UP * 0.025
		var to := from + slope_dir * BOTTOM_RAYCAST_LEN
		var res := raycast(from, to, 1)
		if res:
			from += Vector3.UP * (max_step_height - 0.0125)
			to = from + slope_dir * TOP_RAYCAST_LEN
			res = raycast(from, to, 1)
			if not res:
# 				global_position.y += max_step_height + 0.1
				var motion_res := PhysicsTestMotionResult3D.new()
# 				
				var from_transf = global_transform.translated(Vector3.UP * (max_step_height + 0.1))
				if _run_body_test_motion(from_transf, Vector3.DOWN * (max_step_height + 0.2), motion_res):
# 					_rb.transform = from_transf.translated(motion_res.get_travel())
					_rb.transform = _rb.transform.translated(Vector3.UP * max_step_height * 1.25)
# 					var l = (linear_velocity*Vector3(1,0,1)).normalized() * 0.2
# 					_rb.transform = _rb.transform.translated(l)
# 					global_position += motion_res.get_travel()
# 					global_position += (linear_velocity*Vector3(1,0,1)).normalized() * 0.2
	
	var required_force := (_wish_vel - linear_velocity) / delta
	var max_accel := max_accel_force * max_accel_factor_from_dot.sample((vel_dot + 1.0) / 2.0)
	required_force = required_force.limit_length(max_accel)
	
	apply_force(required_force)

func _handle_air_movement(delta: float) -> void:
	var unit_vel := Vector3.ZERO
	if abs(linear_velocity.x) + abs(linear_velocity.z) > 0.0:
		unit_vel = (linear_velocity * Vector3(1,0,1)).normalized()
	var vel_dot := _wish_dir.dot(unit_vel)
	var curr_accel := air_accel * accel_factor_from_dot.sample((vel_dot + 1.0) / 2.0)

	var wish_vel := _wish_dir * _target_speed
	_wish_vel = _wish_vel.move_toward(wish_vel, curr_accel * delta)

	if _wish_dir.length_squared() > 0.01:
		var required_force := (_wish_vel - linear_velocity*Vector3(1,0,1)) / delta
		var max_accel := air_max_accel * max_accel_factor_from_dot.sample((vel_dot + 1.0) / 2.0)
		required_force = required_force.limit_length(max_accel)
		apply_force(required_force)

func _handle_hover(_delta: float) -> void:
	var vel := linear_velocity
	var other_vel := Vector3.ZERO
	var ray_result := raycast(transform.origin, transform.origin + Vector3.DOWN * 2.0, 1)
	if ray_result:
		var other = ray_result["collider"]
		if other is RigidBody3D:
			other_vel = other.linear_velocity
		elif other is CharacterBody3D:
			other_vel = other.velocity

		var ray_dir_vel := Vector3.DOWN.dot(vel)
		var other_ray_dir_vel := Vector3.DOWN.dot(other_vel)
		var rel_vel := ray_dir_vel - other_ray_dir_vel

		var ray_dist := (ray_result["position"] as Vector3 - transform.origin).length()

# 		TODO(calco): Might cmoe in handy
		var x := ray_dist - ground_hover_dist
		var spring_force := (x * ride_spring_strength) - (rel_vel * ride_spring_damper)

		apply_force(Vector3.DOWN * spring_force)
		if other is RigidBody3D:
			other.apply_force(Vector3.DOWN * -spring_force, ray_result["position"])

func raycast(from: Vector3, to: Vector3, mask: int = 4294967295, exclude: Array[RID] = []) -> Dictionary:
	var state = get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	ray.hit_from_inside = true
	return state.intersect_ray(ray)

func _run_body_test_motion(from: Transform3D, motion: Vector3, result: PhysicsTestMotionResult3D = null) -> bool:
	if not result:
		result = PhysicsTestMotionResult3D.new()
	var params := PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)

func _is_floor(vec: Vector3) -> bool:
	var angle = Vector3.UP.angle_to(vec)
	return angle < deg_to_rad(max_slope_angle)

func _is_wall(vec: Vector3) -> bool:
	var angle = Vector3.UP.angle_to(vec)
	return angle > deg_to_rad(90.0 - wall_angle_tolerance)

func _is_ceiling(normal: Vector3) -> bool:
	var angle = Vector3.DOWN.angle_to(normal)
	return angle < deg_to_rad(max_ceiling_angle)