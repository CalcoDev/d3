extends Node3D

# Exported variables
@export var target_node: NodePath  # Reference to the target node
@export var movement_speed: float = 5.0  # Movement speed
@export var rotation_speed: float = 2.0  # Rotation speed in radians per second

# Variable to store the actual target node
var target: Node3D

func _ready():
	# Resolve the target node from the exported NodePath
	if target_node:
		target = get_node(target_node)
	else:
		target = null
		print("Target node is not set!")

func _process(delta: float):
	if target and target != self:
		# Calculate direction towards the target in the ZX plane
		var direction = Vector3(
			target.global_transform.origin.x - global_transform.origin.x,
			0,  # Ignore the Y-axis
			target.global_transform.origin.z - global_transform.origin.z
		).normalized()
		
		# Calculate the target rotation

		# Interpolate towards the target rotation
		var distance = target.global_position.distance_to(global_position)
		var target_rotation
		if distance < 7.0:
			target_rotation = atan2(direction.x, direction.z) - PI
		else:
			target_rotation = atan2(direction.x, direction.z)
		
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

		# Move towards the target
		global_transform.origin += direction * movement_speed * delta
