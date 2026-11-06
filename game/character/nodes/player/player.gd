extends Character
class_name Player

signal screen_shake_requested(intensity: float, duration: float)

const PLAYER_GROUP := &"player"

@export_group("Block Feedback")
## Глобальный freeze-frame при успешном блоке. 0 = выключен.
@export var block_hitstop_duration: float = 0.06

var enemies: Array[Character] = []

var _attack_locked: bool = false
var _attack_turn_active: bool = false
var _block_held: bool = false


func _ready() -> void:
	super()
	add_to_group(PLAYER_GROUP)
	if _attack_frames.is_empty():
		_attack_frames = { &"attack_1": 0, &"attack_2": 1 }
	if _attack_weights.is_empty():
		_attack_weights = { &"attack_1": 1.75, &"attack_2": 1.0 }


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"attack"):
		_try_attack()
	if Input.is_action_just_pressed(&"block"):
		_block_held = true
		_try_block()
	elif Input.is_action_just_released(&"block"):
		_block_held = false
		if _state == State.BLOCKING:
			unblock()
	
	_maybe_enter_queued_block()


func _apply_damage(amount: float, flash: bool = true) -> void:
	_emit_screen_shake(amount)
	super(amount, flash)


func _emit_screen_shake(amount: float) -> void:
	var p := HitShakePresets.resolve(hit_shake_preset, _hit_shake.custom)
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


func _try_attack() -> void:
	if _attack_locked or _attack_turn_active or _state == State.DEAD:
		return
	if _state == State.BLOCKING:
		unblock()
	if is_busy():
		return
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
	_attack_turn_active = false
	_maybe_enter_queued_block()


func _maybe_enter_queued_block() -> void:
	if not _block_held or _attack_locked or _attack_turn_active:
		return
	if _state != State.IDLE:
		return
	block()


func _nearest_enemy() -> Character:
	var best: Character = null
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
