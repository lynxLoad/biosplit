extends CharacterBase
class_name Player

var enemies: Array[CharacterBase] = []

var _attack_locked: bool = false        # ставит BattleManager на время свапа
var _attack_turn_active: bool = false   # ставится в момент ввода атаки, снимается по turn_finished
var _block_held: bool = false           # «кнопка блока физически зажата» — не зависит от busy/lock


func set_attack_locked(value: bool) -> void:
	var was_locked := _attack_locked
	_attack_locked = value
	# Свап завершился — если игрок всё это время держал блок, встаём в стойку.
	if was_locked and not value:
		_maybe_enter_queued_block()


func _play_anim(anim: StringName) -> void:
	if String(anim).begins_with("attack"):
		anim = "attack_" + str(randi_range(1, 2))
		super._play_anim(anim)
		return
	super._play_anim(anim)


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
	if _attack_locked or _attack_turn_active or is_dead():
		return

	# Атака снимает активный блок (бить из стойки нельзя).
	# _block_held при этом НЕ трогаем — если кнопку ещё держат,
	# после отхода автоматически вернёмся в стойку.
	if is_blocking():
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
	if _attack_locked or _attack_turn_active or is_dead():
		return
	if is_blocking():
		return
	if is_busy():
		# Занят атакой/отходом — сейчас нельзя, но _block_held уже true,
		# _maybe_enter_queued_block() встанет в стойку по завершении хода.
		return
	block()


func _on_block_release() -> void:
	# Отпускание кнопки снимает блок безусловно — стойка не должна залипать.
	if is_blocking():
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
	# После отхода в idle_point — если кнопка блока всё ещё зажата,
	# встаём в стойку автоматически.
	_maybe_enter_queued_block()


## Пытается войти в блок, если кнопка была зажата во время занятости.
## Вызывается из _wait_turn_end() (после атаки) и из set_attack_locked()
## (после свапа). Мягкая проверка — все гейты соблюдаются.
func _maybe_enter_queued_block() -> void:
	if not _block_held:
		return
	if _attack_locked or is_dead() or _attack_turn_active:
		return
	if is_blocking() or is_busy():
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
