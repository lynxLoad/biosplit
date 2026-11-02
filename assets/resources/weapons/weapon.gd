extends Resource
class_name Weapon

@export var name: StringName = &"WeaponName"
@export_range(0.0, 999.0) var damage: float = 10.0
@export_range(0, 60) var animation_frame_attack: int = 1
