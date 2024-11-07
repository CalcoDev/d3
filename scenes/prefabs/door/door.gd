class_name Door
extends Node3D

var interaction_nodes: Array[InteractionComponent] = []

func _ready() -> void:
	if not is_in_group("interactable"):
		add_to_group("interactable")
	interaction_nodes.assign(find_children("*", "InteractionComponent", true))

func interact() -> void:
	print("door was interacted with this")