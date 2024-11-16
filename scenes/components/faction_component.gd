class_name FactionComponent
extends Node

enum Faction {
	Player,
	Enemy
}

@export var faction: Faction = Faction.Enemy