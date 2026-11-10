extends CharacterBase
class_name Player

signal screen_shake_requested(intensity: float, duration: float)

const PLAYER_GROUP := &"player"
const DODGE_ANIM := &"dodge"

# ── Dash afterimage (ghost trail) ──
const GHOST_SPAWN_INTERVAL := 0.02
const GHOST_FADE_TIME      := 0.25
const GHOST_START_ALPHA    := 0.7
const GHOST_END_ALPHA      := 0.25
const GHOST_SCALE_START    := 1.05
const GHOST_SCALE_END      := 0.9
const GHOST_SCALE_FADE     := 0.85
const GHOST_COLOR_START    := Color(0.0, 0.4, 1.0, 1.0)
const GHOST_COLOR_END      := Color(1.0, 1.0, 1.0)

@export var dodge_distance: float = 110.0
@export var dodge_duration: float = 0.22
@export_range(0.0, 1.0) var dodge_iframe_ratio: float = 0.8
@export var dodge_return_to_idle: bool = true
@export var dodge_return_duration: float = 0.25
@export var dodge_screen_shake_intensity: float = 3.0

var enemies: Array[CharacterBase] = []

var _attack_locked: bool = false
var _attack_turn_active: bool = false
var _block_held: bool = false
var _dodge_active: bool = false
var _queued_attack: bool = false
var _queued_dodge: bool = false

func _ready() -> void:
	super()
	add_to_group(PLAYER_GROUP)
	if _attack_frames.is_empty():
		_attack_frames = { &"attack_1": 0, &"attack_2": 0 }
	if _attack_weights.is_empty():
		_attack_weights = { &"attack_1": 2.0, &"attack_2": 1.0 }

func _process(delta: float) -> void:
	if Input.is_action_pressed(&"block"):
		_block_held = true
		_try_block()
	elif Input.is_action_just_released(&"block"):
		_block_held = false
		if _state == State.BLOCKING:
			unblock()
	elif Input.is_action_just_pressed(&"attack"):
		_try_attack()
	elif Input.is_action_just_pressed(&"dodge"):
		_try_dodge()

	_maybe_execute_queued_dodge()
	_maybe_execute_queued_attack()
	_maybe_enter_queued_block()

func _apply_damage(amount: float, flash: bool = true) -> void:
	_emit_screen_shake(amount)
	super(amount, flash)

func _emit_screen_shake(amount: float) -> void:
	var p := _resolve_hit_shake()
	var max_hp := maxf(get_max_health(), 1.0)
	var scale := clampf(0.5 + (amount / max_hp) * 1.5, 0.5, 2.0)
	screen_shake_requested.emit(float(p[0]) * scale, float(p[1]))

func set_attack_locked(value: bool) -> void:
	var was_locked := _attack_locked
	_attack_locked = value
	if was_locked and not value:
		_maybe_enter_queued_block()

# ── shared helpers ──

func _can_start_action() -> bool:
	return not (_attack_locked or _attack_turn_active or _state == State.DEAD)

func _find_attacking_enemy() -> CharacterBase:
	for e in enemies:
		if is_instance_valid(e) and e.is_attacking():
			return e
	return null

func _any_enemy_attacking() -> bool:
	return _find_attacking_enemy() != null

func _any_enemy_about_to_attack() -> bool:
	for e in enemies:
		if is_instance_valid(e) and e.is_about_to_attack():
			return true
	return false

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

# ── dodge ──

func _try_dodge() -> void:
	if _state == State.DEAD or _attack_locked:
		return
	_queued_attack = false
	if _attack_turn_active or _dodge_active:
		_queued_dodge = true
		return
	if _state == State.BLOCKING:
		unblock()
	elif _state != State.IDLE:
		_queued_dodge = true
		return
	_start_dodge()

func _start_dodge() -> void:
	_dodge_active = true
	var id := _begin_action()
	_state = State.DODGING
	_invulnerable = true
	_play_anim(DODGE_ANIM)
	dodge_started.emit()

	var target := global_position + _resolve_dodge_direction() * dodge_distance
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "global_position", target, dodge_duration)

	# Послеобраз идёт параллельно движению и iframe-циклу
	_spawn_dash_ghosts(id)

	# i-frames занимают часть рывка
	var iframe_time := dodge_duration * dodge_iframe_ratio
	var elapsed := 0.0
	while id == _action_id and elapsed < iframe_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not _dodge_continue(id):
		return
	_invulnerable = false

	await _wait_tween(_active_tween, id)
	if not _dodge_continue(id):
		return

	if dodge_return_to_idle and global_position.distance_to(idle_point) > 1.0:
		if not (await _tween_self_to(idle_point, dodge_return_duration, id, Tween.EASE_IN_OUT)):
			_dodge_active = false
			return

	_state = State.IDLE
	_dodge_active = false
	_play_anim(ANIM_IDLE)
	turn_finished.emit()

func _dodge_continue(id: int) -> bool:
	if id == _action_id:
		return true
	_dodge_active = false
	return false

func _resolve_dodge_direction() -> Vector2:
	var e := _find_attacking_enemy()
	if e == null:
		e = _nearest_enemy()
	if e:
		var d := global_position - e.global_position
		if d.length_squared() > 0.0001:
			return d.normalized()
	return Vector2.UP

# ── dash afterimage ──

## Фоновый спавнер: тикает раз в GHOST_SPAWN_INTERVAL в течение dodge_duration.
## Автоматически останавливается при смене _action_id (отмена/смерть/новый экшен).
func _spawn_dash_ghosts(id: int) -> void:
	var elapsed := 0.0
	while id == _action_id and elapsed < dodge_duration:
		_spawn_dash_ghost(clampf(elapsed / dodge_duration, 0.0, 1.0))
		await get_tree().create_timer(GHOST_SPAWN_INTERVAL).timeout
		elapsed += GHOST_SPAWN_INTERVAL

## t ∈ [0, 1] — прогресс дэша: 0 = старт (яркий синий), 1 = конец (бледный белый).
func _spawn_dash_ghost(t: float) -> void:
	if not animated_sprite:
		return
	var parent := get_parent()
	if parent == null:
		return

	var ghost := animated_sprite.duplicate() as AnimatedSprite2D
	if ghost == null:
		return
	parent.add_child(ghost)

	ghost.global_position = animated_sprite.global_position
	ghost.z_index = z_index - 1
	ghost.scale = animated_sprite.scale * lerpf(GHOST_SCALE_START, GHOST_SCALE_END, t)

	var alpha := lerpf(GHOST_START_ALPHA, GHOST_END_ALPHA, t)
	var col := GHOST_COLOR_START.lerp(GHOST_COLOR_END, t)
	ghost.modulate = Color(col.r, col.g, col.b, alpha)

	var tween := ghost.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_TIME)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * GHOST_SCALE_FADE, GHOST_FADE_TIME)
	tween.tween_callback(ghost.queue_free)

func _on_dodged_hit(amount: float, from_position: Vector2) -> void:
	super(amount, from_position)
	_flash(Color(0.7, 0.85, 1.0, 1.0), 0.02, 0.08)

# ── attack ──

func _try_attack() -> void:
	if _state == State.DEAD or _attack_locked:
		return
	_queued_dodge = false
	if _attack_turn_active:
		_queued_attack = true
		return
	if _state == State.BLOCKING:
		unblock()
	if is_busy() or _any_enemy_attacking() or _any_enemy_about_to_attack():
		_queued_attack = true
		return
	_start_attack_now()

func _start_attack_now() -> void:
	var enemy := _nearest_enemy()
	if enemy == null:
		return
	_queued_attack = false
	_attack_turn_active = true
	attack(enemy)
	_wait_turn_end()

func _maybe_execute_queued_attack() -> void:
	if not _queued_attack:
		return
	if _state == State.DEAD or _attack_locked:
		_queued_attack = false
		return
	if _attack_turn_active or is_busy():
		return
	if _state != State.IDLE:
		return
	if _any_enemy_attacking() or _any_enemy_about_to_attack():
		return
	if _nearest_enemy() == null:
		_queued_attack = false
		return
	_start_attack_now()

func _maybe_enter_queued_block() -> void:
	if not _block_held or _attack_locked or _attack_turn_active:
		return
	if _queued_dodge or _queued_attack:
		return
	if _state == State.IDLE:
		block()

func _maybe_execute_queued_dodge() -> void:
	if not _queued_dodge:
		return
	if _state == State.DEAD or _attack_locked:
		_queued_dodge = false
		return
	if _attack_turn_active:
		return
	if _state == State.BLOCKING:
		unblock()
	if is_busy():
		return
	_queued_dodge = false
	_start_dodge()

func _wait_turn_end() -> void:
	if is_busy():
		await turn_finished
	_attack_turn_active = false
	_maybe_enter_queued_block()

# ── block ──

func _try_block() -> void:
	if not _can_start_action():
		return
	if _state == State.BLOCKING or is_busy():
		return
	block()

func _get_post_hit_return_point() -> Vector2:
	return idle_point
