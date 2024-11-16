extends CharacterBody3D

var vel := Vector3.ZERO
func init_bullet(params: ProjectileWeapon.BulletParams) -> void:
	global_position = params.position
	vel = params.direction * params.speed
	look_at(global_position + params.direction, params.direction.cross(params.up_dir))

func destroy_bullet() -> void:
	queue_free()

func _physics_process(_delta: float) -> void:
	velocity = vel
	move_and_slide()
	if get_slide_collision_count() != 0:
		destroy_bullet()