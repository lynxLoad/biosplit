extends CharacterBase
class_name Player

## Кадр применения урона для каждой анимации атаки.
## Ключ — имя анимации, значение — кадр, на котором наносится урон.
## ⚠ Значения — заглушки, подгони под реальные спрайты.
const _ATTACK_FRAMES := {
	&"attack_1": 0,
	&"attack_2": 1,
	#&"attack_3": 0,
}

var enemies: Array[CharacterBase] = []

var _attack_locked: bool = false        # ставит BattleManager на время свапа
var _attack_turn_active: bool = false   # ставится на ввод атаки, снимается по turn_finished
var _block_held: bool = false           # «кнопка блока физически зажата»


func set_attack_locked(value: bool) -> void:
	var was_locked := _attack_locked
	_attack_locked = value
	if was_locked and not value:
		_maybe_enter_queued_block()


## Выбирает случайный вариант атаки из доступных в спрайте и возвращает
## пару «анимация + кадр» для нанесения урона.
func _pick_attack() -> Dictionary:
	var available: Array[StringName] = []
	for anim in _ATTACK_FRAMES:
		if _has_anim(anim):
			available.append(anim)
	if available.is_empty():
		return  super()
	var anim: StringName = available[randi() % available.size()]
	return {"anim": anim, "frame": _ATTACK_FRAMES[anim]}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		_try_attack()
		return
	if event.is_action_pressed(&"block"):
		_block_held = true
		_try_block()
		return
	if event.is_action_released(&"block"):
		_block_held = false
		_on_block_release()


func _try_attack() -> void:
	if _attack_locked or _attack_turn_active or _state == State.DEAD:
		return

	# Атака снимает активный блок. _block_held не трогаем — если кнопка
	# ещё зажата, после отхода автоматически вернёмся в стойку.
	if _state == State.BLOCKING:
		unblock()

	if is_busy():
		return

	var enemy := _nearest_enemy()
	if enemy == null:
		return

	_attack_turn_active = true
	attack(enemy)
	_wait_turn_end()


func _try_block() -> void:
	if _attack_locked or _attack_turn_active or _state == State.DEAD:
		return
	if _state == State.BLOCKING:
		return
	if is_busy():
		return
	block()


func _on_block_release() -> void:
	if _state == State.BLOCKING:
		unblock()


func _wait_turn_end() -> void:
	if not is_busy():
		await get_tree().process_frame
		_attack_turn_active = false
		_maybe_enter_queued_block()
		return
	await turn_finished
	await get_tree().process_frame
	_attack_turn_active = false
	_maybe_enter_queued_block()


func _maybe_enter_queued_block() -> void:
	if not _block_held:
		return
	if _attack_locked or _state == State.DEAD or _attack_turn_active:
		return
	if _state != State.IDLE:
		return
	block()


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
