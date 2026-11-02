extends Node2D
class_name CharacterBase

signal turn_finished
signal damaged(amount: float)
signal died
signal retreat_started

## ── блокирование ──
signal block_started
signal block_ended
signal hit_blocked(amount: float)

@export_range(0.0, 1.0) var block_anim_lead_ratio: float = 1

@export var character_stats: CharacterStats
@export var weapon: Weapon

@export var strike_distance: float = 80.0
@export var pixels_per_unit: float = 100.0
@export var min_phase_duration: float = 0.08
@export var max_phase_duration: float = 1.5

@export var animation_frame_damage: int = 1

## ── hit shake: пресеты ──
enum HitShakePreset { LIGHT, MEDIUM, HEAVY, CRITICAL, JAB, MAGIC, BLOCK_HIT, CUSTOM }

const HIT_SHAKE_PRESETS := {
	HitShakePreset.LIGHT:     {"distance": 6.0,  "duration": 0.18, "oscillations": 4, "decay": 0.55, "return_mult": 1.2},
	HitShakePreset.MEDIUM:    {"distance": 14.0, "duration": 0.30, "oscillations": 7, "decay": 0.65, "return_mult": 1.5},
	HitShakePreset.HEAVY:     {"distance": 24.0, "duration": 0.45, "oscillations": 6, "decay": 0.78, "return_mult": 1.6},
	HitShakePreset.CRITICAL:  {"distance": 32.0, "duration": 0.55, "oscillations": 9, "decay": 0.80, "return_mult": 2.0},
	HitShakePreset.JAB:       {"distance": 8.0,  "duration": 0.12, "oscillations": 3, "decay": 0.45, "return_mult": 1.0},
	HitShakePreset.MAGIC:     {"distance": 10.0, "duration": 0.40, "oscillations": 8, "decay": 0.70, "return_mult": 1.8},
	HitShakePreset.BLOCK_HIT: {"distance": 6.0,  "duration": 0.20, "oscillations": 5, "decay": 0.60, "return_mult": 1.3},
}

## Активный пресет. При значении CUSTOM используются экспорты ниже.
@export var hit_shake_preset: HitShakePreset = HitShakePreset.MEDIUM

## Случайный разброс на каждый удар (±доля от базового значения).
@export_range(0.0, 0.5) var hit_shake_distance_jitter: float = 0.1
@export_range(0.0, 0.5) var hit_shake_duration_jitter: float = 0.0
@export_range(0.0, 0.5) var hit_shake_decay_jitter: float = 0.0

## Используются только при hit_shake_preset == CUSTOM.
@export var hit_shake_distance: float = 14.0
@export var hit_shake_duration: float = 0.3
@export_range(0, 10) var hit_shake_oscillations: int = 7
@export_range(0.0, 1.0) var hit_shake_decay: float = 0.65
@export var hit_shake_return_mult: float = 1.5

@export var flash_color: Color = Color(1, 0.4, 0.4, 1)
@export var flash_in_duration: float = 0.05
@export var flash_out_duration: float = 0.1

## ── блокирование ──
## Блок удерживается, пока не вызван unblock(). Таймаута нет, turn_finished
## не эмитится — блок не тратит ход, а «замораживает» персонажа в стойке.
@export var block_flash_color: Color = Color(0.4, 0.65, 1.0, 1)
@export var block_flash_in_duration: float = 0.03
@export var block_flash_out_duration: float = 0.12
@export var block_shake_distance: float = 6.0
## Сколько урона блок выдержит до принудительного снятия. 0 = бесконечно.
@export var block_max_absorbed_damage: float = 0.0

@export var death_knockback_distance: float = 100.0
@export var death_knockback_duration: float = 0.45
@export var death_knockback_arc: float = 0.0
@export var death_knockback_rotation_deg: float = 0.0

@export var death_fade_duration: float = 0.5
@export var death_fade_delay: float = 0.0

@export var z_attack_priority: int = 1000

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var target: CharacterBase
var idle_point: Vector2
var health: float

var _is_dead: bool = false
var _is_busy: bool = false
var _is_attacking: bool = false
var _is_blocking: bool = false
var _z_before_attack: int = 0

var _active_tween: Tween
var _hit_shake_tween: Tween
var _flash_tween: Tween
var _block_flash_tween: Tween

var _block_absorbed: float = 0.0
var _last_hit_from: Vector2 = Vector2.INF
var _sprite_base_position: Vector2

const ANIM_IDLE   := &"idle"
const ANIM_ATTACK := &"attack"
const ANIM_DAMAGE := &"damage"
const ANIM_DEATH  := &"death"
const ANIM_BLOCK  := &"block"


func _ready() -> void:
	character_stats = character_stats.duplicate()
	health = character_stats.max_health
	reset_idle_point()
	_play_anim(ANIM_IDLE)
	if animated_sprite:
		_sprite_base_position = animated_sprite.position


func reset_idle_point() -> void:
	idle_point = global_position


func is_busy() -> bool:
	return _is_busy


func is_dead() -> bool:
	return _is_dead


func is_attacking() -> bool:
	return _is_attacking


func is_blocking() -> bool:
	return _is_blocking


## Сколько урона блок гасит при попадании (плоское вычитание).
## Гарантированно неотрицательное; при отсутствии ресурса — 0.
func get_block_damage_reduction() -> float:
	if character_stats == null:
		return 0.0
	return maxf(0.0, character_stats.block_damage_reduction)


func set_z_priority(priority: int) -> void:
	z_index = priority


# ── public ──

func attack(enemy: CharacterBase) -> void:
	if _is_dead or _is_busy or not is_instance_valid(enemy) or enemy.is_dead():
		return
	_is_busy = true
	target = enemy

	_is_attacking = true
	_z_before_attack = z_index
	z_index = z_attack_priority

	var start := global_position
	var dir := start - enemy.global_position
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	var strike_pos := start
	if start.distance_to(enemy.global_position) > strike_distance:
		strike_pos = enemy.global_position + dir * strike_distance

	var speed_px := maxf(character_stats.speed, 0.01) * pixels_per_unit
	var approach_dist := start.distance_to(strike_pos)
	var approach_time := clampf(approach_dist / speed_px, min_phase_duration, max_phase_duration)
	var retreat_time := clampf(strike_pos.distance_to(idle_point) / speed_px, min_phase_duration, max_phase_duration)

	if approach_dist > 1.0:
		_active_tween = create_tween()
		_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(self, "global_position", strike_pos, approach_time)
		await _wait_tween(_active_tween)
		if _is_dead:
			return

	_play_anim(ANIM_ATTACK)
	if weapon:
		await _await_attack_frame()
		if _is_dead:
			return
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.take_damage(weapon.damage, global_position)
	await _await_anim_end()
	if _is_dead:
		return

	retreat_started.emit()

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(self, "global_position", idle_point, retreat_time)
	await _wait_tween(_active_tween)
	if _is_dead:
		return

	_is_attacking = false
	z_index = _z_before_attack

	_is_busy = false
	_play_anim(ANIM_IDLE)
	turn_finished.emit()


## Вход в стойку блокирования. Удерживается, пока не вызван unblock().
func block() -> void:
	if _is_dead or _is_blocking:
		return
	if _is_busy:
		return
	_is_busy = true
	_is_blocking = true
	_block_absorbed = 0.0
	if _has_anim(ANIM_BLOCK):
		_play_anim(ANIM_BLOCK)
	block_started.emit()


func unblock() -> void:
	if not _is_blocking:
		return
	_is_blocking = false
	_block_absorbed = 0.0
	_is_busy = false
	if not _is_dead:
		_play_anim(ANIM_IDLE)
	block_ended.emit()


func take_damage(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if _is_dead:
		return

	_last_hit_from = from_position

	if _is_blocking:
		await _on_blocked_hit(amount, from_position)
		return

	if _is_busy or not _has_anim(ANIM_DAMAGE):
		_apply_damage(amount)
		return

	_play_anim(ANIM_DAMAGE)
	await _await_anim_frame(ANIM_DAMAGE, animation_frame_damage)
	if _is_dead:
		return
	_apply_damage(amount)
	if _is_dead:
		return
	await _await_anim_end()
	if not _is_dead and not _is_busy:
		_play_anim(ANIM_IDLE)


func move_to_idle_point(duration: float = 0.3) -> void:
	if _is_dead or _is_busy:
		return
	if _active_tween and _active_tween.is_valid() and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "global_position", idle_point, duration)
	_active_tween.finished.connect(func(): turn_finished.emit(), CONNECT_ONE_SHOT)


func get_health() -> float:
	return health


func get_max_health() -> float:
	return character_stats.max_health


func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	health = minf(character_stats.max_health, health + amount)


# ── internal: урон ──

func _apply_damage(amount: float, flash: bool = true) -> void:
	health = maxf(0.0, health - amount)
	damaged.emit(amount)
	if health <= 0.0:
		_die()
	elif flash:
		_flash_damage()
		_play_hit_shake(_last_hit_from)


func _die() -> void:
	_is_dead = true
	_is_blocking = false
	_block_absorbed = 0.0

	if _active_tween and _active_tween.is_valid() and _active_tween.is_running():
		_active_tween.kill()
	if _hit_shake_tween and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _block_flash_tween and _block_flash_tween.is_valid():
		_block_flash_tween.kill()

	if animated_sprite:
		animated_sprite.position = _sprite_base_position
		animated_sprite.modulate = Color.WHITE

	_play_anim(ANIM_DEATH)

	died.emit()

	_start_death_knockback()
	_start_death_fade()


# ── internal: реакция на удар ──

## Возвращает результирующие параметры shake для указанного пресета.
## Для HitShakePreset.CUSTOM берёт экспорты экземпляра.
func _resolve_hit_shake(preset_override: int = -1) -> Dictionary:
	var preset: int = preset_override if preset_override >= 0 else hit_shake_preset
	if preset == HitShakePreset.CUSTOM:
		return {
			"distance": hit_shake_distance,
			"duration": hit_shake_duration,
			"oscillations": hit_shake_oscillations,
			"decay": hit_shake_decay,
			"return_mult": hit_shake_return_mult,
		}
	return HIT_SHAKE_PRESETS.get(preset, HIT_SHAKE_PRESETS[HitShakePreset.MEDIUM])


## Запускает hit-shake.
## distance_override >= 0 — переопределяет distance пресета (используется блоком).
## preset_override >= 0 — принудительный пресет (используется блоком).
## Jitter применяется поверх финальных значений.
func _play_hit_shake(
	from_position: Vector2,
	distance_override: float = -1.0,
	preset_override: int = -1
) -> void:
	if not animated_sprite or _is_dead:
		return

	var p := _resolve_hit_shake(preset_override)
	var distance: float = distance_override if distance_override >= 0.0 else p["distance"]
	var duration: float = p["duration"]
	var oscillations: int = p["oscillations"]
	var decay: float = p["decay"]
	var return_mult: float = p["return_mult"]

	# Рандомный разброс на каждый удар.
	if hit_shake_distance_jitter > 0.0:
		distance *= randf_range(1.0 - hit_shake_distance_jitter, 1.0 + hit_shake_distance_jitter)
	if hit_shake_duration_jitter > 0.0:
		duration *= randf_range(1.0 - hit_shake_duration_jitter, 1.0 + hit_shake_duration_jitter)
	if hit_shake_decay_jitter > 0.0:
		decay = clampf(decay + randf_range(-hit_shake_decay_jitter, hit_shake_decay_jitter), 0.0, 1.0)

	var dir := Vector2.UP
	if from_position != Vector2.INF:
		var d := global_position - from_position
		if d.length_squared() > 0.0001:
			dir = d.normalized()

	if _hit_shake_tween and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()

	_hit_shake_tween = create_tween()
	_hit_shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	oscillations = maxi(1, oscillations)
	var half_steps := oscillations * 2
	var step_duration := maxf(duration / float(half_steps + 1), 0.01)

	var amp := distance
	for i in range(half_steps):
		var sign := 1.0 if i % 2 == 0 else -1.0
		var tw := _hit_shake_tween.tween_property(
			animated_sprite, "position",
			_sprite_base_position + dir * amp * sign,
			step_duration
		)
		if i == 0:
			tw.set_ease(Tween.EASE_OUT)
		amp *= decay

	_hit_shake_tween.tween_property(
		animated_sprite, "position",
		_sprite_base_position,
		maxf(step_duration * return_mult, 0.01)
	).set_ease(Tween.EASE_OUT)


func _flash_damage() -> void:
	if not animated_sprite or _is_dead:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _block_flash_tween and _block_flash_tween.is_valid():
		_block_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", flash_color, flash_in_duration)
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, flash_out_duration)


# ── internal: блок ──

func play_block_reaction(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if _is_dead:
		return

	var total := _get_anim_frame_time(ANIM_DAMAGE, animation_frame_damage)
	var lead := total * block_anim_lead_ratio
	var rest := total - lead

	if lead > 0.0:
		await get_tree().create_timer(lead).timeout
		if _is_dead:
			return
	_play_anim(ANIM_BLOCK)

	if rest > 0.0:
		await get_tree().create_timer(rest).timeout
		if _is_dead:
			return

	hit_blocked.emit(amount)
	_flash_block()
	_play_hit_shake(from_position, block_shake_distance, HitShakePreset.BLOCK_HIT)


func _wait_anim_frame_time(anim: StringName, frame: int) -> void:
	if not _has_anim(anim) or frame <= 0:
		return
	var speed := animated_sprite.sprite_frames.get_animation_speed(anim)
	if speed <= 0.0:
		return
	var delay := float(frame) / speed
	if delay <= 0.0:
		return
	await get_tree().create_timer(delay).timeout


func _get_anim_frame_time(anim: StringName, frame: int) -> float:
	if not _has_anim(anim) or frame <= 0:
		return 0.0
	var speed := animated_sprite.sprite_frames.get_animation_speed(anim)
	if speed <= 0.0:
		return 0.0
	return float(frame) / speed


func _on_blocked_hit(amount: float, from_position: Vector2) -> void:
	var reduction := get_block_damage_reduction()
	var leaked := maxf(0.0, amount - reduction)

	_block_absorbed += amount - leaked

	await play_block_reaction(amount, from_position)
	if _is_dead:
		return

	if leaked > 0.0:
		_apply_damage(leaked, false)
		if _is_dead:
			return

	if block_max_absorbed_damage > 0.0 and _block_absorbed >= block_max_absorbed_damage:
		unblock()


func _flash_block() -> void:
	if not animated_sprite or _is_dead:
		return
	if _block_flash_tween and _block_flash_tween.is_valid():
		_block_flash_tween.kill()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_block_flash_tween = create_tween()
	_block_flash_tween.tween_property(
		animated_sprite, "modulate", block_flash_color, block_flash_in_duration
	)
	_block_flash_tween.tween_property(
		animated_sprite, "modulate", Color.WHITE, block_flash_out_duration
	)


# ── internal: смертельный отлёт ──

func _start_death_knockback() -> void:
	var from := _last_hit_from
	if from == Vector2.INF:
		from = global_position + Vector2.DOWN

	var dir := global_position - from
	if dir.length_squared() < 0.0001:
		dir = Vector2.UP
	dir = dir.normalized()

	var start := global_position
	var land := start + dir * death_knockback_distance
	var peak := (start + land) * 0.5 + Vector2(0, -death_knockback_arc)
	var half := death_knockback_duration * 0.5

	var pt := create_tween()
	pt.set_trans(Tween.TRANS_QUAD)
	pt.tween_property(self, "global_position", peak, half).set_ease(Tween.EASE_OUT)
	pt.tween_property(self, "global_position", land, half).set_ease(Tween.EASE_IN)

	if animated_sprite:
		var rot_dir := 1.0 if dir.x >= 0.0 else -1.0
		var rt := create_tween()
		rt.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rt.tween_property(
			animated_sprite, "rotation",
			deg_to_rad(death_knockback_rotation_deg) * rot_dir,
			death_knockback_duration
		)


func _start_death_fade() -> void:
	var ft := create_tween()
	if death_fade_delay > 0.0:
		ft.tween_interval(death_fade_delay)
	ft.tween_property(self, "modulate:a", 0.0, death_fade_duration)
	ft.tween_callback(queue_free)


# ── internal: анимации ──

func _play_anim(anim: StringName) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if not animated_sprite.sprite_frames.has_animation(anim):
		return
	if animated_sprite.animation == anim and animated_sprite.is_playing():
		return
	animated_sprite.play(anim)


func _has_anim(anim: StringName) -> bool:
	return animated_sprite != null \
		and animated_sprite.sprite_frames != null \
		and animated_sprite.sprite_frames.has_animation(anim)


func _await_anim_end() -> void:
	if not animated_sprite:
		return
	var target_anim := animated_sprite.animation
	while not _is_dead and animated_sprite.animation == target_anim and animated_sprite.is_playing():
		await get_tree().process_frame


func _await_anim_frame(anim: StringName, frame: int) -> void:
	if not _has_anim(anim):
		return
	var target_frame := maxi(frame, 0)
	var fc := animated_sprite.sprite_frames.get_frame_count(anim)
	if fc > 0:
		target_frame = mini(target_frame, fc - 1)

	while not _is_dead \
			and animated_sprite.animation == anim \
			and animated_sprite.is_playing():
		if animated_sprite.frame >= target_frame:
			return
		await animated_sprite.frame_changed


func _await_attack_frame() -> void:
	if not weapon:
		return
	await _await_anim_frame(ANIM_ATTACK, weapon.animation_frame_attack)


# ── internal: tween ──

func _wait_tween(tw: Tween) -> void:
	await get_tree().process_frame
	while not _is_dead and tw.is_valid() and tw.is_running():
		await get_tree().process_frame


# ── internal: UI ──

func _init_bar(bar: Bar, value: float, max_value: float) -> void:
	if bar:
		bar.setup(value, max_value)


func _sync_bar(bar: Bar, value: float, max_value: float) -> void:
	if bar:
		bar.update_value(value, max_value)
