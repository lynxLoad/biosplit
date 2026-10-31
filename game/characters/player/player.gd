extends CharacterBase
class_name Player

## Заполняется BattleManager'ом при спавне.
var enemies: Array[CharacterBase] = []

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack") and not is_busy():
		var enemy := _nearest_enemy()
		if enemy:
			attack(enemy)

func _nearest_enemy() -> CharacterBase:
	var best: CharacterBase = null
	var best_d2 := INF
	for e in enemies:
		if not is_instance_valid(e) or e.is_dead():
			continue
		var d2 := global_position.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best
