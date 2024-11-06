class_name InteractionRaycast
extends RayCast3D

signal on_interactable_seen(interactable)
signal on_interactable_unseen()

var reach: float:
	set(value):
		reach = value
		target_position = Vector3.FORWARD * reach

var _interactable:
	set(value):
		if _interactable == value:
			return
		_interactable = value
		if _interactable == null:
			on_interactable_unseen.emit()
		else:
			on_interactable_seen.emit(_interactable)

func _process(_delta: float) -> void:
	if not is_instance_valid(_interactable):
		if typeof(_interactable) != 0:
			_interactable = null
			return
	
	var obj = get_collider()
	if obj != null and not obj.is_in_group("interactable"):
		obj = null
	if obj == null and typeof(obj) != 0:
		obj = null
	_interactable = obj