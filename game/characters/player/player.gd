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

# ── Block juice ──
@export_group("Block Juice")
@export var block_aura_color: Color = Color(0.4, 0.7, 1.0, 1.0)
@export var block_burst_color: Color = Color(0.75, 0.92, 1.0, 1.0)
@export var block_hit_flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 1.0) var block_aura_steady_alpha: float = 0.45
@export var block_aura_fade_in_time: float = 0.14
@export var block_aura_fade_out_time: float = 0.15
@export var block_aura_scale: float = 1.14
@export var block_aura_scale_pulse: float = 1.24
@export var block_aura_pulse_time: float = 0.65
@export var block_aura_rot_pulse: float = 0.05
@export var block_enter_pop_scale: float = 1.10
@export var block_enter_pop_time: float = 0.13
@export var block_enter_burst_alpha: float = 0.8
@export var block_enter_burst_scale: float = 1.6
@export var block_enter_burst_time: float = 0.35
@export var block_hit_squash: Vector2 = Vector2(0.88, 1.14)
@export var block_hit_recover_time: float = 0.16
@export var block_hit_burst_alpha: float = 0.9
@export var block_hit_burst_scale: float = 1.8
@export var block_hit_burst_time: float = 0.25
@export var block_hit_screen_shake: float = 4.0
@export var block_hit_screen_time: float = 0.22

@export_subgroup("Block Hit Tilt")
## Максимальный угол наклона спрайта в сторону удара (радианы). 0 — отключено.
@export_range(0.0, 0.5) var block_hit_tilt: float = 0.12
## Длительность «щёлчка» в наклон.
@export var block_hit_tilt_out_time: float = 0.04
## Длительность возврата в исходное положение.
@export var block_hit_tilt_back_time: float = 0.14

# ── Attack pacing ──
## Микро-пауза после завершения атаки, прежде чем можно начать следующую (сек).
@export var attack_recovery: float = 0.12

var enemies: Array[CharacterBase] = []

var _attack_locked: bool = false
var _attack_turn_active: bool = false
var _block_held: bool = false
var _dodge_active: bool = false
var _queued_attack: bool = false
var _queued_dodge: bool = false

var _block_aura: AnimatedSprite2D
var _block_aura_tween: Tween
var _block_pulse_tween: Tween
var _block_scale_tween: Tween
var _sprite_base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	super()
	add_to_group(PLAYER_GROUP)
	if _attack_frames.is_empty():
		_attack_frames = { &"attack_1": 0, &"attack_2": 0 }
	if _attack_weights.is_empty():
		_attack_weights = { &"attack_1": 2.0, &"attack_2": 1.0 }
	if animated_sprite:
		_sprite_base_scale = animated_sprite.scale

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"attack"):
		_try_attack()
	elif Input.is_action_just_pressed(&"dodge"):
		_try_dodge()

	if Input.is_action_pressed(&"block"):
		_block_held = true
		_try_block()
	elif Input.is_action_just_released(&"block"):
		_block_held = false
		if _state == State.BLOCKING:
			unblock()

	_sync_block_aura()
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
	if _state == State.DEAD:
		return
	_queued_attack = false
	if _attack_locked or _attack_turn_active or _dodge_active:
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

	_spawn_dash_ghosts(id)

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

func _spawn_dash_ghosts(id: int) -> void:
	var elapsed := 0.0
	while id == _action_id and elapsed < dodge_duration:
		_spawn_dash_ghost(clampf(elapsed / dodge_duration, 0.0, 1.0))
		await get_tree().create_timer(GHOST_SPAWN_INTERVAL).timeout
		elapsed += GHOST_SPAWN_INTERVAL

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
	if _state == State.DEAD:
		return
	_queued_dodge = false
	if _attack_locked or _attack_turn_active:
		_queued_attack = true
		return
	if _state != State.IDLE and _state != State.BLOCKING:
		_queued_attack = true
		return
	if _any_enemy_attacking() or _any_enemy_about_to_attack():
		_queued_attack = true
		return
	if _state == State.BLOCKING:
		unblock()
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
	if _state == State.DEAD:
		_queued_attack = false
		return
	if _attack_locked or _attack_turn_active:
		return
	if _state != State.IDLE and _state != State.BLOCKING:
		return
	if _any_enemy_attacking() or _any_enemy_about_to_attack():
		return
	if _nearest_enemy() == null:
		_queued_attack = false
		return
	if _state == State.BLOCKING:
		unblock()
	_start_attack_now()

func _maybe_enter_queued_block() -> void:
	if not _block_held or _attack_locked or _attack_turn_active:
		return
	if _state == State.IDLE:
		block()

func _maybe_execute_queued_dodge() -> void:
	if not _queued_dodge:
		return
	if _state == State.DEAD:
		_queued_dodge = false
		return
	if _attack_locked or _attack_turn_active:
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

func block() -> void:
	if _state not in [State.IDLE, State.MOVING_TO_IDLE]:
		return
	super()
	if _state == State.BLOCKING:
		_begin_block_visuals()

func unblock() -> void:
	if _state != State.BLOCKING:
		return
	_end_block_visuals()
	super()

func play_block_reaction(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	super(amount, from_position)
	if _state == State.BLOCKING:
		_block_hit_visuals(from_position)

func _die() -> void:
	if _state == State.BLOCKING or (_block_aura and is_instance_valid(_block_aura)):
		_end_block_visuals()
	super()

func _get_post_hit_return_point() -> Vector2:
	return idle_point

# ── block juice ──

func _begin_block_visuals() -> void:
	if not animated_sprite:
		return
	_sprite_pop(block_enter_pop_scale, block_enter_pop_time)
	_spawn_block_aura()
	_spawn_block_burst(block_burst_color, block_enter_burst_alpha, block_enter_burst_scale, block_enter_burst_time)

func _end_block_visuals() -> void:
	_kill_tween(_block_aura_tween)
	_kill_tween(_block_pulse_tween)
	_kill_tween(_block_scale_tween)
	_sprite_scale_reset()
	if _block_aura and is_instance_valid(_block_aura):
		var old := _block_aura
		_block_aura = null
		var tw := create_tween()
		tw.tween_property(old, "modulate:a", 0.0, block_aura_fade_out_time)
		tw.tween_callback(old.queue_free)

## Визуальная (rest) позиция спрайта в локальных координатах Player.
## = позиция спрайта + его offset * его базовый масштаб.
func _get_sprite_visual_local_base() -> Vector2:
	if not animated_sprite:
		return Vector2.ZERO
	return _sprite_base_position + animated_sprite.offset * _sprite_base_scale

func _spawn_block_aura() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if _block_aura and is_instance_valid(_block_aura):
		_block_aura.queue_free()

	var aura_scale := maxf(block_aura_scale, 0.001)

	_block_aura = AnimatedSprite2D.new()
	_block_aura.sprite_frames = animated_sprite.sprite_frames
	# Копируем offset (с компенсацией масштаба ауры) — так её визуальный
	# центр совпадает с визуальным центром спрайта, даже если у спрайта
	# задан offset (например (0, -69) для «поднятия» картинки).
	_block_aura.offset = animated_sprite.offset / aura_scale
	# Ставим в rest-позицию спрайта: не дёргается от hit-shake.
	_block_aura.position = _sprite_base_position
	_block_aura.z_index = animated_sprite.z_index - 1
	_block_aura.scale = _sprite_base_scale * aura_scale
	_block_aura.speed_scale = animated_sprite.speed_scale
	_block_aura.modulate = Color(block_aura_color.r, block_aura_color.g, block_aura_color.b, 0.0)
	add_child(_block_aura)
	_block_aura.play(animated_sprite.animation)
	_block_aura.frame = animated_sprite.frame

	_block_aura_tween = create_tween()
	_block_aura_tween.tween_property(_block_aura, "modulate:a", block_aura_steady_alpha, block_aura_fade_in_time)

	_block_pulse_tween = create_tween().set_loops()
	_block_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_block_pulse_tween.tween_property(_block_aura, "scale", _sprite_base_scale * block_aura_scale_pulse, block_aura_pulse_time)
	_block_pulse_tween.parallel().tween_property(_block_aura, "rotation", block_aura_rot_pulse, block_aura_pulse_time)
	_block_pulse_tween.tween_property(_block_aura, "scale", _sprite_base_scale * aura_scale, block_aura_pulse_time)
	_block_pulse_tween.parallel().tween_property(_block_aura, "rotation", -block_aura_rot_pulse, block_aura_pulse_time)

func _spawn_block_burst(color: Color, alpha: float, scale_end: float, duration: float) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var burst := AnimatedSprite2D.new()
	burst.sprite_frames = animated_sprite.sprite_frames
	# Тот же offset и rest-позиция — burst рождается ровно на визуальном
	# центре спрайта.
	burst.offset = animated_sprite.offset
	burst.position = _sprite_base_position
	burst.z_index = animated_sprite.z_index - 1
	burst.scale = _sprite_base_scale
	burst.speed_scale = animated_sprite.speed_scale
	burst.modulate = Color(color.r, color.g, color.b, alpha)
	add_child(burst)
	burst.play(animated_sprite.animation)
	burst.frame = animated_sprite.frame

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(burst, "scale", _sprite_base_scale * scale_end, duration)
	tw.parallel().tween_property(burst, "modulate:a", 0.0, duration)
	tw.tween_callback(burst.queue_free)

func _block_hit_visuals(from_position: Vector2) -> void:
	# squash&stretch
	if animated_sprite:
		_kill_tween(_block_scale_tween)
		animated_sprite.scale = _sprite_base_scale * block_hit_squash
		_block_scale_tween = create_tween()
		_block_scale_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_block_scale_tween.tween_property(animated_sprite, "scale", _sprite_base_scale, block_hit_recover_time)

	# вспышка ауры
	if _block_aura and is_instance_valid(_block_aura):
		_block_aura.modulate = Color(block_hit_flash_color.r, block_hit_flash_color.g, block_hit_flash_color.b, block_aura_steady_alpha)
		var tw := create_tween()
		tw.tween_property(_block_aura, "modulate",
			Color(block_aura_color.r, block_aura_color.g, block_aura_color.b, block_aura_steady_alpha), 0.18)

	# расходящееся кольцо
	_spawn_block_burst(block_hit_flash_color, block_hit_burst_alpha, block_hit_burst_scale, block_hit_burst_time)

	# усиленный screen shake
	screen_shake_requested.emit(block_hit_screen_shake, block_hit_screen_time)

	# наклон спрайта в сторону удара
	if animated_sprite and block_hit_tilt > 0.0:
		var dir := _dir_from(from_position, Vector2.UP)
		var tilt := dir.x * block_hit_tilt
		var tw2 := create_tween()
		tw2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw2.tween_property(animated_sprite, "rotation", tilt, block_hit_tilt_out_time)
		tw2.tween_property(animated_sprite, "rotation", 0.0, block_hit_tilt_back_time)

func _sprite_pop(scale_mult: float, duration: float) -> void:
	if not animated_sprite:
		return
	_kill_tween(_block_scale_tween)
	animated_sprite.scale = _sprite_base_scale * scale_mult
	_block_scale_tween = create_tween()
	_block_scale_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_block_scale_tween.tween_property(animated_sprite, "scale", _sprite_base_scale, duration)

func _sprite_scale_reset() -> void:
	if animated_sprite:
		animated_sprite.scale = _sprite_base_scale
		animated_sprite.rotation = 0.0

func _sync_block_aura() -> void:
	if not _block_aura or not is_instance_valid(_block_aura) or not animated_sprite:
		return
	_block_aura.speed_scale = animated_sprite.speed_scale
	if _block_aura.animation != animated_sprite.animation:
		_block_aura.play(animated_sprite.animation)
	_block_aura.frame = animated_sprite.frame
