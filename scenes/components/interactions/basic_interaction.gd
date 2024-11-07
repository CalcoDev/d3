extends InteractionComponent

@onready var parent_node: Node = get_parent()

func interact() -> void:
	if parent_node.has_method("interact"):
		parent_node.interact()
	on_interacted_with.emit()