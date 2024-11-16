class_name ProjectileWeapon
extends Weapon

class BulletParams:
	var transform: Transform3D
	var direction: Vector3
	var faction: FactionComponent
	var speed: float
	
	func _init(t: Transform3D, d: Vector3, f: FactionComponent, s: float) -> void:
		self.transform = t
		self.direction = d
		self.faction = f
		self.speed = s

@export_group("References")
@export var fire_point_path: NodePath
var _fire_point: Node3D = null

@export var bullet_prefab: PackedScene

@export_group("Projectile Weapon Settings")
@export var bullet_count: int = 1
@export var bullet_spread: Vector2 = Vector2.ZERO
@export var bullet_speed: float = 10.0

# Lifecycle
func _ready() -> void:
	var fire_node = get_node(fire_point_path)
	assert(fire_node is Node3D)
	_fire_point = fire_node
	on_fired.connect(_handle_on_fired)

# Event Handlers
func _handle_on_fired(fire_params: Weapon.FireParams) -> void:
	var container: Node = get_tree().get_first_node_in_group("bullet_container")
	assert(container != null)
	for i in bullet_count:
		var bullet = bullet_prefab.instantiate()
		assert("init_bullet" in bullet)
		var t = _fire_point.global_transform
		var d = _apply_spread(fire_params.direction, bullet_spread)
		var bullet_params := BulletParams.new(t, d, faction, fire_params.speed)
		bullet.init_bullet(bullet_params)
		container.add_child(bullet)

func _apply_spread(dir: Vector3, spread_angles: Vector2) -> Vector3:
		var spread_x := deg_to_rad(spread_angles.x)
		var spread_y := deg_to_rad(spread_angles.y)

		var offset_x := randf_range(-spread_x / 2, spread_x / 2)
		var offset_y := randf_range(-spread_y / 2, spread_y / 2)

		var rotation_basis := Basis()
		rotation_basis = rotation_basis.rotated(Vector3.UP, offset_y)
		rotation_basis = rotation_basis.rotated(Vector3.RIGHT, offset_x)

		return rotation_basis * dir.normalized()