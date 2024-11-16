class_name HitboxComponent
extends Area3D

signal on_hit(hurtbox: HurtboxComponent)

## Sets the initial value of responder. Separate so we can export a nodepath.
@export var hitbox_owner: Node
@export var faction: FactionComponent

@export var friendly_fire: bool = false

@export_node_path var default_responder: NodePath = ""
@export var damage: float = 0.0
var _responder = null # any object with a func on_hitbox_response(obj: Node3D) -> bool

@onready var _shape: CollisionShape3D = find_children("*", "CollisionShape3D")[0]
@export var enabled: bool = true:
	get():
		return not _shape.disabled
	set(value):
		monitoring = value
		monitorable = value
		_shape.disabled = not value
@export var update_self: bool = true

@export var collide_areas: bool = true:
	set(value):
		if value:
			area_entered.connect(_handle_on_area_entered)
			area_exited.connect(_handle_on_area_exited)
		else:
			area_entered.disconnect(_handle_on_area_entered)
			area_exited.disconnect(_handle_on_area_exited)
@export var area_count: int = 4

# @export var collide_bodies: bool = false:
# 	set(value):
# 		if value:
# 			body_entered.connect(_handle_on_body_entered)
# 			body_exited.connect(_handle_on_body_exited)
# 		else:
# 			body_entered.disconnect(_handle_on_body_entered)
# 			body_exited.disconnect(_handle_on_body_exited)
# @export var body_count: int = 4

## Delay between dealing damage if a hurtbox stays inside of it.
## < 0 => not continuous
## == 0 => every frame
@export var continuous_delay: float = -1.0

func _ready() -> void:
	_responder = get_node(default_responder)
	collide_areas = collide_areas
	enabled = enabled

func _process(delta: float) -> void:
	if update_self:
		update(delta)

func update(delta: float) -> void:
	for c in _collidables:
		var time: float = _collidables[c]
		if continuous_delay < 0.0:
			if time <= 0.0 and _respond(c):
				_collidables[c] = 1.0
		elif time > continuous_delay:
			if _respond(c):
				_collidables[c] = 0.0
		else:
			_collidables[c] += delta

func _respond(c: Node3D) -> bool:
	if _responder.on_hitbox_response(c):
		on_hit.emit(c)
		return true
	return false

# Hitbox Responder ahhhh
func on_hitbox_response(hurtbox: HurtboxComponent) -> bool:
	return hurtbox.get_hit(damage, hitbox_owner)

# Callbacks
var _collidables: Dictionary = {}
var _area_cnt: int = 0
var _body_cnt: int = 0
func _handle_on_area_entered(area: Area3D):
	if _area_cnt >= area_count:
		return
	if area is not HurtboxComponent:
		return
	if not friendly_fire and area.faction.faction == faction.faction:
		return
	_collidables[area] = 0.0
	_area_cnt += 1

func _handle_on_area_exited(area: Area3D):
	if _collidables.erase(area):
		_area_cnt -= 1

func _handle_on_body_entered(body: Node3D):
	if _body_cnt >= area_count:
		return
	_collidables[body] = 0.0
	_body_cnt += 1

func _handle_on_body_exited(body: Node3D):
	if _collidables.erase(body):
		_body_cnt -= 1
