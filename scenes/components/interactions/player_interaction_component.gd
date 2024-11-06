class_name PlayerInteractionComponent
extends Node

@export var interaction_reach: float = 3.0
@export var interaction_raycast: InteractionRaycast
var interactable

func _ready() -> void:
    interaction_raycast.reach = interaction_reach
    interaction_raycast.on_interactable_seen.connect(_on_interactable_seen)
    interaction_raycast.on_interactable_unseen.connect(_on_interactable_unseen)

func _process(_delta: float) -> void:
    if Input.is_action_just_released("interact"):
        _handle_interaction()

func exclude_player(rid: RID) -> void:
    interaction_raycast.add_exception_rid(rid)

func _handle_interaction() -> void:
    pass

func _on_interactable_seen(p_interactable) -> void:
    interactable = p_interactable

func _on_interactable_unseen() -> void:
    interactable = null
