extends Node3D

@export var primary: Weapon
@export var secondary: Weapon

func _ready() -> void:
	# Set up interacations between the 2 (don't allow use at the same time)
	# Set up secondary to like spin gun or whatever
	pass