extends Resource
class_name CharacterStats

@export var name: StringName = &"chara_name"
@export_range(1, 999) var level: int = 1
@export_range(1.0, 9999.0) var max_health: float = 30.0
@export_range(0.01, 999.0) var speed: float = 16.0
@export_range(0.0, 999.0) var block_damage_reduction: float = 5.0
@export_range(0.0, 1.0) var block_chance: float = 0.5
