extends Resource
class_name CharacterStats

@export var name: StringName = &"CharName"
@export var level: int = 1
@export var max_health: float = 30.0
@export var speed: float = 16.0
@export var block_damage_reduction: float = 0.5
@export_range(0.0, 1.0) var block_chance: float = 0.5
