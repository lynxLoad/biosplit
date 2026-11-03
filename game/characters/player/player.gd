extends CharacterBase
class_name Player

signal screen_shake_requested(intensity: float, duration: float)

const PLAYER_GROUP := &"player"

var enemies: Array[CharacterBase] = []

var _attack_locked: bool = false        # ставит BattleManager на время свапа
var _attack_turn_active: bool = false   # ставится на ввод атаки, снимается по turn_finished
var _block_held: bool = false           # «кнопка блока физически зажата»

func _ready() -> void:
	super()
	add_to_group(PLAYER_GROUP)
	if _attack_frames.is_empty():
		_attack_frames = { &"attack_1": 0, &"attack_2": 1 }
	if _attack_weights.is_empty():
		_attack_weights = { &"attack_1": 1.75, &"attack_2": 1.0 }

# Постоянный polling: как только персонаж реально освободился (state == IDLE,
# нет лока, нет активного хода атаки) — сразу же применяем зажатый блок.
# Это гарантирует, что блок включится в тот же физ-кадр, когда закончилась
# анимация удара / hurt / свапа, а не когда-нибудь «позже по событию».
func _physics_process(delta: float) -> void:
	_maybe_enter_queued_block()

func _apply_damage(amount: float, flash: bool = true) -> void:
	_emit_screen_shake(amount)
	super(amount, flash)

func _emit_screen_shake(amount: float) -> void:
	var p := _resolve_hit_shake()
	var dist := float(p["distance"])
	var max_hp := maxf(get_max_health(), 1.0)
	# 0.5× на «чирик», до 2× на тяжёлый удар по отношению к max HP.
	var scale := clampf(0.5 + (amount / max_hp) * 1.5, 0.5, 2.0)
	screen_shake_requested.emit(dist * scale, float(p["duration"]))

func set_attack_locked(value: bool) -> void:
	var was_locked := _attack_locked
	_attack_locked = value
	if was_locked and not value:
		_maybe_enter_queued_block()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		_try_attack()
	elif event.is_action_pressed(&"block"):
		_block_held = true
		_try_block()
	elif event.is_action_released(&"block"):
		_block_held = false
		if _state == State.BLOCKING:
			unblock()


func _try_attack() -> void:
	if _attack_locked or _attack_turn_active or _state == State.DEAD:
		return

	if _state == State.BLOCKING:
		unblock()
	if is_busy():
		return

	# Пока враги атакуют — атаковать нельзя.
	if _any_enemy_attacking():
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
	if _state == State.BLOCKING or is_busy():
		return
	block()


func _wait_turn_end() -> void:
	if is_busy():
		await turn_finished
	# без лишнего process_frame: следующий физ-кадр всё равно вызовет _maybe_enter_queued_block()
	_attack_turn_active = false
	_maybe_enter_queued_block()


func _maybe_enter_queued_block() -> void:
	if not _block_held or _attack_locked or _attack_turn_active:
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


func _any_enemy_attacking() -> bool:
	for e in enemies:
		if is_instance_valid(e) and e.is_attacking():
			return true
	return false
