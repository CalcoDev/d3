class_name HitscanWeapon
extends Weapon

@export_group("References")
@export var use_fire_point: bool = false
@export var fire_point_path: NodePath
var _fire_point: Node3D = null

@export_group("Hitscan Weapon Settings")
@export var fire_range: float = 100.0
@export var bullet_spread: Vector2 = Vector2.ZERO

# Lifecycle
func _ready() -> void:
	var fire_node = get_node(fire_point_path)
	assert(fire_node is Node3D)
	_fire_point = fire_node
	on_fired.connect(_handle_on_fired)

# Event Handlers
func _handle_on_fired(fire_params: Weapon.FireParams) -> void:
	var from = _fire_point.global_position if use_fire_point else fire_params.position
	var to = from + (_apply_spread(fire_params.direction, bullet_spread) * fire_range)
	var exclude: Array[RID] = [_get_node_rid(self.weapon_owner)]
# 	var ray := repeat_raycast(from, to, _is_valid_hit, collision_layers)
	var ray := raycast(from, to, collision_layers, exclude)
	if ray:
		var obj = ray["collider"]
# 		if obj.find_children("*", )
		# TODO(calco): HURTBOX IMPLEMENTATION AND THEN DO THIS

# raycasts repetedly until doesn;t hit or hits adequate object
func repeat_raycast(from: Vector3, to: Vector3, check_callback: Callable, mask: int = 4294967295) -> Dictionary:
	var exclude: Array[RID] = [_get_node_rid(self.weapon_owner)]
	print("EXCLUDE: ", exclude[0])
	var depth := 0
	while true:
		if depth >= 10:
			break
		depth += 1
		var ray := raycast(from, to, mask, exclude)
		if not ray:
			return {}
		var obj = ray["collider"]
		if check_callback.call(obj):
			return ray
		exclude.append(obj)
	return {}

func _get_node_rid(node: Node3D) -> RID:
	if "get_rid" in node:
		return node.get_rid()
	for n: CollisionShape3D in node.find_children("*", "CollisionShape3D"):
		return n.shape.get_rid()
	assert(false, "ERROR: Could not get RID for given node.")
	return RID() # impossible to reach so it's fine

func raycast(from: Vector3, to: Vector3, mask: int = 4294967295, exclude: Array[RID] = []) -> Dictionary:
	assert("get_world_3d" in self)
	var state: PhysicsDirectSpaceState3D = self.get("get_world_3d").call().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	ray.hit_from_inside = true
	return state.intersect_ray(ray)

func _apply_spread(dir: Vector3, spread_angles: Vector2) -> Vector3:
		var spread_x := deg_to_rad(spread_angles.x)
		var spread_y := deg_to_rad(spread_angles.y)

		var offset_x := randf_range(-spread_x / 2.0, spread_x / 2.0)
		var offset_y := randf_range(-spread_y / 2.0, spread_y / 2.0)

		var rotation_basis := Basis()
		rotation_basis = rotation_basis.rotated(Vector3.UP, offset_y)
		rotation_basis = rotation_basis.rotated(Vector3.RIGHT, offset_x)

		return rotation_basis * dir.normalized()
