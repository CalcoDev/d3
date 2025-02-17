class_name PlayerController
extends RigidBody3D

@export_group("Look Around")
@export var look_sensitivity := 0.6
const SENS_MULT := 0.006

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
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var accel: float = 30.0
@export var accel_factor_from_dot: Curve
@export var max_accel_force: float = 50.0
@export var max_accel_factor_from_dot: Curve
@export var max_fall: float = 200.0

var _max_fall: float = max_fall

@export var air_accel: float = 17.0
@export var air_max_accel: float = 30.0

var _target_speed: float = 0.0

@export_group("Crouching")
@export var crouch_speed: float = 3

# stair handling
@export_group("Stairs")
@export var wall_angle_tolerance: float = 10.0
@export var max_step_height: float = 0.35

@export var max_ceiling_angle: float = 10.0

var _is_touching_wall: bool = false
var _wall_normal: Vector3 = Vector3.ZERO

var _wall_touch_relative_pos: Vector3 = Vector3.ZERO

var _touched_wall_with_velocity: Vector3 = Vector3.ZERO

var _is_touching_ceiling: bool = false
var _ceiling_normal: Vector3 = Vector3.ZERO

# Bobbing
const BOB_AMOUNT: Vector2 = Vector2(0.06, 0.15) 
const BOB_FREQ: float = 2.7
const BOB_RESET_SPEED: float = 2.5
const BOB_MOVE_SPEED: float = 10.0
const BOB_SHIFT: float = PI / 4.0
var bob_time: float = 0.0

@export_group("Jump")
@export var jump_height_approx: float = 1.5
@export var jump_cancel_rate: float = 5.0

@export var _wall_jump_force: float = 2.0

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
@onready var _camera_mount: Node3D = %CameraMount
@onready var _head: Node3D = %Head
@onready var _world_model: Node3D = %WorldModel
@onready var _camera_offsetter: Node3D = %CameraOffsetter
@onready var _collision_shape: CollisionShape3D = %CollisionShape3D

var _input_dir := Vector3.ZERO
var _wish_dir := Vector3.ZERO
var _wish_vel := Vector3.ZERO

var _prev_velocity: Vector3 = Vector3.ZERO

# stairs
var _snapped_down_last_frame: bool = false
var _snapped_up_last_frame: bool = false
var _stair_snap_camera_offset: Vector3 = Vector3.ZERO

# Interaction stuff
@export_group("Interactions")
@export var interaction_reach: float = 3.0
@onready var _player_interaction_component: PlayerInteractionComponent = %PlayerInteractionComponent

# Crouching
@export_group("Crouching")
@export var crouch_height_offset: float = 0.3
var _is_crouching: bool = false

# Wall Jumping / Sliding
@export_group("Wall Jump")
@export var wall_slide_max_fall: float = 100.0
@export var wall_jump_horiz_force: Curve
var _was_wall_sliding: bool = false
var _is_wall_sliding: bool = false
var _wall_slide_stop_y_vel: bool = false

var _is_wall_jumping: bool = false

@export_group("Held Items")

# @onready var faction: FactionComponent = %FactionComponent

@onready var _held_item_mount: Node3D = %HeldItemPosition
var _equipped_item: Node3D = null

func equip_item(obj: Node3D) -> void:
	_equipped_item = obj
	_equipped_item.reparent(_held_item_mount)
	_equipped_item.position = Vector3.ZERO
	_equipped_item.look_at(_held_item_mount.global_position + _held_item_mount.basis.z)

func unequip_item() -> void:
	_equipped_item.queue_free()
	_equipped_item = null

@export_group("Weapon Stuff")
@export var weapon: DualWeapon = null

func _ready() -> void:
	# TODO(calco): Remove in prod
# 	_camera.current = false
	for child: VisualInstance3D in _world_model.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)
	
	_player_interaction_component.exclude_player(get_rid())
	_player_interaction_component.interaction_reach = interaction_reach

	weapon.setup_owner(self)
	weapon.setup_faction(get_child(1) as FactionComponent)
	equip_item(weapon)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			_orientation.rotate_y(-event.screen_relative.x * look_sensitivity * SENS_MULT)
			_camera.rotate_x(-event.screen_relative.y * look_sensitivity * SENS_MULT)
			_camera.rotation.x = clampf(_camera.rotation.x, -PI*0.5, PI*0.5)

func _process(delta: float) -> void:
	var input = Input.get_vector("left", "right", "up", "down").normalized()
	var abs_dir = Vector3(input.x, 0.0, input.y)
	_input_dir = abs_dir
	_wish_dir = _orientation.global_transform.basis * abs_dir
	
	if Input.is_action_pressed("sprint"):
		_target_speed = sprint_speed
	else:
		_target_speed = walk_speed
		
	if Input.is_action_just_pressed("_dbg_explode"):
		var r := random_on_unit_sphere()
		apply_impulse(r * 50)
	
	_coyote_buffer_timer -= delta
	_jump_buffer_timer -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME
		
	if _is_jumping and Input.is_action_just_released("jump"):
		_jump_inp_released = true
	
	# Gun stuff
	weapon.check_fire(_camera.global_position, -_camera.global_basis.z, _camera.global_basis.y, "use_primary", "use_secondary")
	
	# Crouching
	if _is_grounded and Input.is_action_pressed("crouch") and not _is_crouching:
		_is_crouching = true
		_head.position = Vector3.DOWN * crouch_height_offset
		if _collision_shape.shape is BoxShape3D:
			_collision_shape.shape.size.y -= crouch_height_offset
			_collision_shape.position.y -= crouch_height_offset * 0.5
		elif _collision_shape.shape is CylinderShape3D or _collision_shape.shape is CapsuleShape3D:
			_collision_shape.shape.height -= crouch_height_offset
			_collision_shape.position.y -= crouch_height_offset * 0.5
	elif not Input.is_action_pressed("crouch") and _is_crouching and _can_uncrouch():
		_is_crouching = false
		_head.position = Vector3.ZERO
		# TODO(calco): Maybe just set to 0?
		if _collision_shape.shape is BoxShape3D:
			_collision_shape.shape.size.y += crouch_height_offset
			_collision_shape.position.y += crouch_height_offset * 0.5
		elif _collision_shape.shape is CylinderShape3D or _collision_shape.shape is CapsuleShape3D:
			_collision_shape.shape.height += crouch_height_offset
			_collision_shape.position.y += crouch_height_offset * 0.5
	
	# View bobbing effect:
	var target_pos := _camera_mount.position
	if _is_grounded:
		var forward = abs(abs_dir.z) > 0.0
		var right = abs(abs_dir.x) > 0.0
		if forward or right:
			target_pos.y = sin(bob_time * BOB_FREQ) * BOB_AMOUNT.y
		if right:
			target_pos.x = sin(bob_time * BOB_FREQ + BOB_SHIFT) * BOB_AMOUNT.x
		else:
			target_pos.x = move_toward(target_pos.x, 0.0, delta * BOB_RESET_SPEED)
		if not forward and not right:
			target_pos.y = move_toward(target_pos.y, 0.0, delta * BOB_RESET_SPEED)
			bob_time = asin(target_pos.y / BOB_AMOUNT.y)
		if forward or right:
			bob_time += delta * BOB_FREQ
		_camera_mount.position = _camera_mount.position.lerp(target_pos, delta * BOB_MOVE_SPEED)
		
	# Handle stair snap smoothing
	if _stair_snap_camera_offset.length_squared() > 0.001:
		_camera_offsetter.position = _stair_snap_camera_offset
		_stair_snap_camera_offset = _stair_snap_camera_offset.lerp(Vector3.ZERO, delta * 15.0)

var _rb: PhysicsDirectBodyState3D
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_rb = state
	var delta := get_physics_process_delta_time()
	
	_handle_raycasts()
	
	if not _was_grounded and _is_grounded:
		_wall_slide_stop_y_vel = true
		_wish_vel = _wish_vel.slide(_floor_normal)
		_is_jumping = false
		_is_wall_jumping = false
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
	
	# Wall Jumps
# 	print(linear_velocity)
	if _can_wall_slide() and not _is_grounded and _jump_buffer_timer > 0.0:
# 		print("--> jupmp trigger")
		gravity_scale = 1.0
		linear_velocity = Vector3.ZERO
		
		_jump_buffer_timer = 0.0
		_is_jumping = true
		_is_wall_jumping = true
		_jump_inp_released = false
		_jump_descent = false
		
		var gravity_str: float = ProjectSettings.get_setting("physics/3d/default_gravity")
		var force := sqrt(jump_height_approx * 0.75 * gravity_str * 2.5) * mass
		apply_impulse(Vector3.UP * force)
		
		# apply sideways impulse based on a scaled dot?
		var d := _wish_dir.dot(_wall_normal)
		var zx_impulse := (_wall_normal * _wall_jump_force) * wall_jump_horiz_force.sample((-d + 1.0) / 2.0)
		_wish_vel += zx_impulse
		apply_impulse(zx_impulse)
	
	# Stair snapping
	if not _is_grounded and linear_velocity.y < 0.0 and (_was_grounded or _snapped_down_last_frame):
		var test := PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(global_transform, Vector3.DOWN * max_step_height, test):
			global_position.y += test.get_travel().y
			_stair_snap_camera_offset.y += -test.get_travel().y
			_snapped_down_last_frame = true
	else:
		_snapped_down_last_frame = false
	
	# Movement
	if _is_grounded:
# 		print("ground")
		_handle_ground_movement(delta)
	else:
		# TODO(calco): Should still allow movement, just not in that direction lmao.
		if _is_touching_ground_but_maybe_not_floor:
# 			print("notfloor")
			return
# 		print("air")
		_handle_air_movement(delta)
	   
	_prev_velocity = linear_velocity
	
func _physics_process(_delta: float) -> void:
	pass

func _handle_raycasts() -> void:
	_was_grounded = _is_grounded
	_is_grounded = false
	_is_on_slope = false
	_is_touching_ground_but_maybe_not_floor = false
	_is_touching_wall = false
	_is_touching_ceiling = false
	
	var col_cnt = _rb.get_contact_count()
	for cidx in col_cnt:
		var obj := _rb.get_contact_collider_object(cidx)
		var local_pos := to_local(_rb.get_contact_local_position(cidx))
		var normal := _rb.get_contact_local_normal(cidx)
		
		if not is_instance_valid(obj):
			continue
		
		var layer = obj.get("collision_layer")
		if layer == null or layer & ground_layers == 0:
			continue
	
		var is_not_floor_ramp := false
		var is_floor := false
		var is_wall := false
		var is_ceiling := false
		var pos: Vector3 = local_pos
		if pos.y < 0.1:
			if _is_floor(normal):
				is_floor = true
			else:
				is_not_floor_ramp = true
		if pos.y > 0.95 and _is_ceiling(normal):
			is_ceiling = true
		if _is_wall(normal):
			is_wall = true
		if is_ceiling:
			is_wall = false
			is_floor = false
		
		if is_floor:
			_floor_normal = normal
			_floor_angle = Vector3.UP.angle_to(_floor_normal)
			_is_grounded = true
			if _floor_angle > deg_to_rad(0.01):
				_is_on_slope = true
		if is_not_floor_ramp:
			_is_touching_ground_but_maybe_not_floor = true
		if is_wall:
			_is_touching_wall = true
			_touched_wall_with_velocity = _prev_velocity
			_wall_touch_relative_pos = local_pos
			_wall_normal = normal
		if is_ceiling:
			_is_touching_ceiling = true
			_ceiling_normal = normal
	if _is_touching_wall:
		_is_touching_ground_but_maybe_not_floor = false

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
	var wish_vel := slope_dir * _get_target_speed()
	_wish_vel = _wish_vel.move_toward(wish_vel, curr_accel * delta)
	
	# stair stuff
	if _is_touching_wall:
		const BOTTOM_RAYCAST_LEN: float = 0.4 + 0.3
		const TOP_RAYCAST_LEN: float = 0.4 + 0.3
		var from := global_position + Vector3.UP * 0.025
		var to := from + slope_dir * BOTTOM_RAYCAST_LEN
		var res := raycast(from, to, 1)
		if res:
			from += Vector3.UP * (max_step_height - 0.0125)
			to = from + slope_dir * TOP_RAYCAST_LEN
			var bottom_p := res["position"] as Vector3
			res = raycast(from, to, 1)
			if not res:
				var init_pos = global_position
				global_position.y += max_step_height + 0.1
				var ll := (bottom_p - global_position).length()
				var l := slope_dir * (ll / 6.5)
				global_position += l
				var motion_res := PhysicsTestMotionResult3D.new()
				var fr = global_transform
				if _run_body_test_motion(fr, Vector3.DOWN * (max_step_height + 0.25), motion_res):
					global_position += motion_res.get_travel()
					linear_velocity = _touched_wall_with_velocity
					var diff = init_pos - global_position
					_stair_snap_camera_offset += Vector3.UP * diff
					_snapped_up_last_frame = true
	else:
		_snapped_up_last_frame = false
	
	var required_force := (_wish_vel - linear_velocity) / delta
	var max_accel := max_accel_force * max_accel_factor_from_dot.sample((vel_dot + 1.0) / 2.0)
	required_force = required_force.limit_length(max_accel)
	apply_force(required_force)

func _handle_air_movement(delta: float) -> void:
	# Wall Jumping and Fall Limiting
	_was_wall_sliding = _is_wall_sliding
	if _can_wall_slide():
		var dot = _wall_normal.dot(_wish_dir)
		if _wall_normal.length_squared() > 0.01 and _wish_dir.length_squared() > 0.01 and dot < 0.85:
			_is_wall_sliding = true
		else:
			_is_wall_sliding = false
	else:
		_is_wall_sliding = false
	
	gravity_scale = 1.0
	_max_fall = max_fall
	if _is_wall_sliding and linear_velocity.y < 0.0:
		gravity_scale = 0.2
		_max_fall = wall_slide_max_fall
	if linear_velocity.y < -_max_fall:
		linear_velocity.y = -max_fall
	
	if not _was_wall_sliding and _is_wall_sliding and _wall_slide_stop_y_vel and linear_velocity.y < 0.0:
		linear_velocity.y = min(linear_velocity.y * 0.2, 0.5)
		# TODO(calco): Determine what Ultrakill and Karlson do here lmao
# 		_wall_slide_stop_y_vel = false

	# Actual movement
	var unit_vel := Vector3.ZERO
	if abs(linear_velocity.x) + abs(linear_velocity.z) > 0.0:
		unit_vel = (linear_velocity * Vector3(1,0,1)).normalized()
	var vel_dot := _wish_dir.dot(unit_vel)
	var curr_accel := air_accel * accel_factor_from_dot.sample((vel_dot + 1.0) / 2.0)

	var wish_vel := _wish_dir * _get_target_speed()

	var wvel := wish_vel.length_squared()
	if wvel > 0.01 and _wish_vel.length_squared() > wvel:
		_wish_vel = _wish_vel.move_toward(wish_vel, curr_accel * delta).normalized() * _wish_vel.length()
	else:
		_wish_vel = _wish_vel.move_toward(wish_vel, curr_accel * delta)

	var mult := 0.1
	if _is_wall_sliding or _wish_dir.length_squared() > 0.01:
		mult = 0.6
	
	# if on wall and trying to move away from it
	if _is_wall_sliding or _can_wall_slide():
		var d = _wish_dir.dot(_wall_normal)
		if d > 0.0:
			if d < 0.95:
				_wish_vel = _wish_vel - _wish_vel.project(_wall_normal)
# 				_wish_vel = _wish_vel - _wish_vel.slide(_wall_normal)
			else:
				_wish_vel = _wish_vel - _wish_vel.project(_wall_normal) * 0.005
# 				_wish_vel = _wish_vel - _wish_vel.slide(_wall_normal) * 0.05

	# TODO(calco): I kinda hate this because it makes it similar to using velocity = ...
	var required_force := (_wish_vel - linear_velocity*Vector3(1,0,1)) / delta
	var max_accel := air_max_accel * max_accel_factor_from_dot.sample((vel_dot + 1.0) / 2.0)
	required_force = (required_force * mult).limit_length(max_accel)
	apply_force(required_force)
	
func _can_wall_slide() -> bool:
	return _is_touching_wall
	
func _get_target_speed() -> float:
	if _is_crouching:
		return crouch_speed
	else:
		return _target_speed

func raycast(from: Vector3, to: Vector3, mask: int = 4294967295, exclude: Array[RID] = []) -> Dictionary:
	var state := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	ray.hit_from_inside = true
	return state.intersect_ray(ray)

func _can_uncrouch() -> bool:
	# NOTE(calco): For some reason this does not work. 0 idea why lmfao
# 	var res = PhysicsTestMotionResult3D.new() 
# 	var i = _run_body_test_motion(global_transform.translated(Vector3.UP * 1.01), Vector3.UP, res)
	var from := global_position + Vector3.UP * (2.0 - crouch_height_offset)
	var to := global_position + Vector3.UP * 2.0
	var res := raycast(from, to, 1 | 4, [])
	return res == {}

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

func random_on_unit_sphere() -> Vector3:
	var x1 = randf_range (-1, 1)
	var x2 = randf_range (-1, 1)
	while x1*x1 + x2*x2 >= 1:
		x1 = randf_range(-1, 1)
		x2 = randf_range(-1, 1)
	var random_pos_on_unit_sphere = Vector3 (
	2 * x1 * sqrt(1 - x1*x1 - x2*x2),
	2 * x2 * sqrt(1 - x1*x1 - x2*x2),
	1 - 2 * (x1*x1 + x2*x2))
	return random_pos_on_unit_sphere
