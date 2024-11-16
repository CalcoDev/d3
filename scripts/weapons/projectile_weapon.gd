class_name ProjectileWeapon
extends Weapon

class BulletParams:
	var position: Vector3
	var direction: Vector3
	var up_dir: Vector3
	var faction: FactionComponent
	var speed: float
	
	@warning_ignore("shadowed_variable")
	func _init(p: Vector3, d: Vector3, f: FactionComponent, s: float, up_dir: Vector3) -> void:
		self.position = p
		self.direction = d
		self.faction = f
		self.speed = s
		self.up_dir = up_dir

@export_group("References")
@export var use_fire_point: bool = false
@export var fire_point_path: NodePath
var _fire_point: Node3D = null

@export var bullet_prefab: PackedScene

@export_group("Projectile Weapon Settings")
@export var bullet_count: int = 1
@export var bullet_spread: Vector2 = Vector2.ZERO
@export var bullet_speed: float = 10.0

# Lifecycle
func _ready() -> void:
	super._ready()
	var fire_node = get_node(fire_point_path)
	assert(fire_node is Node3D)
	_fire_point = fire_node
	on_fired.connect(_handle_on_fired)

func _process(delta: float) -> void:
	super._process(delta)

# Event Handlers
func _handle_on_fired(fire_params: Weapon.FireParams) -> void:
	var container: Node = get_tree().get_first_node_in_group("bullet_container")
	assert(container != null)
	for i in bullet_count:
		var bullet = bullet_prefab.instantiate()
		assert("init_bullet" in bullet)
		var t = _fire_point.global_position if use_fire_point else fire_params.position
		var d = _apply_spread(fire_params.direction, bullet_spread)
		var bullet_params := BulletParams.new(t, d, faction, bullet_speed, fire_params.up_dir)
		container.add_child(bullet)
		bullet.init_bullet(bullet_params)

func _apply_spread(dir: Vector3, spread_angles: Vector2) -> Vector3:
		var spread_x := deg_to_rad(spread_angles.x)
		var spread_y := deg_to_rad(spread_angles.y)

		var offset_x := randf_range(-spread_x / 2, spread_x / 2)
		var offset_y := randf_range(-spread_y / 2, spread_y / 2)

		var rotation_basis := Basis()
		rotation_basis = rotation_basis.rotated(Vector3.UP, offset_y)
		rotation_basis = rotation_basis.rotated(Vector3.RIGHT, offset_x)

		return rotation_basis * dir.normalized()
