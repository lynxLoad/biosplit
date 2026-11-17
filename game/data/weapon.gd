@tool
class_name Weapon
extends Resource
## Оружие, владеющее набором способностей.

#region Exports
@export_group("Identity")
@export var name: StringName = &""

@export_group("Attack")
@export_range(0, 64, 1, "or_greater") var animation_frame_attack: int = 0

@export_group("Abilities")
@export var abilities: Array[Ability] = []
#endregion

#region Helpers
func has_ability(ability_name: StringName) -> bool:
	return find_ability_index(ability_name) != -1

func find_ability_index(ability_name: StringName) -> int:
	for i in abilities.size():
		if abilities[i] and abilities[i].name == ability_name:
			return i
	return -1

func get_ability(ability_name: StringName) -> Ability:
	var idx := find_ability_index(ability_name)
	return abilities[idx] if idx != -1 else null

func add_ability(ability: Ability) -> bool:
	if ability == null or has_ability(ability.name):
		return false
	abilities.append(ability)
	return true

func remove_ability(ability_name: StringName) -> bool:
	var idx := find_ability_index(ability_name)
	if idx == -1:
		return false
	abilities.remove_at(idx)
	return true

func _to_string() -> String:
	return "Weapon(%s, %d abilities)" % [name, abilities.size()]
#endregion
