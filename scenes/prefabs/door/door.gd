class_name Door
extends Node3D

var interaction_nodes: Array[InteractionComponent] = []

func _ready() -> void:
	if not is_in_group("interactable"):
		add_to_group("interactable")

func interact() -> void:
	print("door interacted with this")