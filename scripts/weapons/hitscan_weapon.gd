class_name HitscanWeapon
extends Weapon

@export_group("References")
@export var fire_point_path: NodePath
var _fire_point: Node3D = null

@export_group("Hitscan Weapon Settings")
@export var fire_range: float = 100.0
@export var accuracy: float = 100.0

# Lifecycle
func _ready() -> void:
	var fire_node = get_node(fire_point_path)
	assert(fire_node is Node3D)
	_fire_point = fire_node
	on_fired.connect(_handle_on_fired)

# Event Handlers
func _handle_on_fired(fire_params: Weapon.FireParams) -> void:
	var from = _fire_point.global_position
	var to = from + fire_params.direction * fire_range
	var ray := raycast(from, to, collision_layers, [])
	if ray:
		print("hitscan ray hit: ", ray)

func raycast(from: Vector3, to: Vector3, mask: int = 4294967295, exclude: Array[RID] = []) -> Dictionary:
	assert("get_world_3d" in self)
	var state: PhysicsDirectSpaceState3D = self.get("get_world_3d").invoke().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	ray.hit_from_inside = true
	return state.intersect_ray(ray)
