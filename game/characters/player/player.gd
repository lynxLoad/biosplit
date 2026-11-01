extends CharacterBase
class_name Player

var enemies: Array[CharacterBase] = []

var _attack_locked: bool = false        # ставит BattleManager на время свапа
var _attack_turn_active: bool = false   # ставится в момент ввода, снимается по turn_finished

func set_attack_locked(value: bool) -> void:
	_attack_locked = value

func _play_anim(anim: StringName) -> void:
	if String(anim).begins_with("attack"):
		anim = "attack_" + str(randi_range(1, 2))
		super._play_anim(anim)
		return
	super._play_anim(anim)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"attack"):
		return
	# Блокируем: свап, уже идущий ход, любая busy-анимация, смерть
	if _attack_locked or _attack_turn_active or is_busy() or is_dead():
		return
	var enemy := _nearest_enemy()
	if enemy == null:
		return

	_attack_turn_active = true
	attack(enemy)          # синхронно выставит _is_busy = true
	_wait_turn_end()

func _wait_turn_end() -> void:
	# Если attack() вернулся сразу (enemy стал невалиден и т.п.) — снимем флаг сразу.
	if not is_busy():
		await get_tree().process_frame
		_attack_turn_active = false
		return
	# Иначе ждём строго конца хода — сигнал летит последним в attack().
	await turn_finished
	# Дополнительный кадр, чтобы все твины/позиции гарантированно «устоялись»
	# до того, как разрешим следующий ввод.
	await get_tree().process_frame
	_attack_turn_active = false

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
