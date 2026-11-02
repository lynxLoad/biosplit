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

## ── состояния ──
enum State { IDLE, MOVING_TO_IDLE, ATTACKING, RETREATING, BLOCKING, HIT, DEAD }

@export_range(0.0, 1.0) var block_anim_lead_ratio: float = 1

@export var character_stats: CharacterStats
@export var weapon: Weapon

@export var strike_distance: float = 80.0
@export var pixels_per_unit: float = 100.0
@export var min_phase_duration: float = 0.08
@export var max_phase_duration: float = 1.5

## Кадр по умолчанию для анимации реакции на урон. См. _pick_damage().
@export var animation_frame_damage: int = 1

## ── hit shake ──
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

@export var hit_shake_preset: HitShakePreset = HitShakePreset.MEDIUM

@export_range(0.0, 0.5) var hit_shake_distance_jitter: float = 0.1
@export_range(0.0, 0.5) var hit_shake_duration_jitter: float = 0.0
@export_range(0.0, 0.5) var hit_shake_decay_jitter: float = 0.0

@export var hit_shake_distance: float = 14.0
@export var hit_shake_duration: float = 0.3
@export_range(0, 10) var hit_shake_oscillations: int = 7
@export_range(0.0, 1.0) var hit_shake_decay: float = 0.65
@export var hit_shake_return_mult: float = 1.5

@export var flash_color: Color = Color(1, 0.4, 0.4, 1)
@export var flash_in_duration: float = 0.05
@export var flash_out_duration: float = 0.1

## ── блок ──
@export var block_flash_color: Color = Color(0.4, 0.65, 1.0, 1)
@export var block_flash_in_duration: float = 0.03
@export var block_flash_out_duration: float = 0.12
@export var block_shake_distance: float = 6.0
## 0 = бесконечно.
@export var block_max_absorbed_damage: float = 0.0

@export var death_knockback_distance: float = 100.0
@export var death_knockback_duration: float = 0.45

@export var death_fade_duration: float = 0.5
@export var death_fade_delay: float = 0.0

@export var z_attack_priority: int = 1000

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var target: CharacterBase
var idle_point: Vector2
var health: float

var _state: State = State.IDLE
var _action_id: int = 0
var _z_before_attack: int = 0

var _active_tween: Tween
var _hit_shake_tween: Tween
var _flash_tween: Tween
var _block_flash_tween: Tween

var _block_absorbed: float = 0.0
var _last_hit_from: Vector2 = Vector2.INF
var _sprite_base_position: Vector2

var _idle_point_set: bool = false

const ANIM_IDLE   := &"idle"
const ANIM_ATTACK := &"attack"
const ANIM_DAMAGE := &"damage"
const ANIM_DEATH  := &"death"
const ANIM_BLOCK  := &"block"

## Сколько максимум ждать завершения/кадра анимации. Защита от looped-anim.
const ANIM_WAIT_TIMEOUT := 3.0


func _ready() -> void:
	if character_stats == null:
		push_error("CharacterBase: character_stats не задан на %s" % name)
		character_stats = CharacterStats.new()
	character_stats = character_stats.duplicate()
	health = character_stats.max_health

	if not _idle_point_set:
		reset_idle_point()

	if animated_sprite:
		_sprite_base_position = animated_sprite.position

	_play_anim(ANIM_IDLE)


# ── idle point ──

## BattleManager должен звать это после расстановки бойцов.
func set_idle_point(point: Vector2) -> void:
	idle_point = point
	_idle_point_set = true


func reset_idle_point() -> void:
	idle_point = global_position
	_idle_point_set = true


# ── state queries ──

func is_busy() -> bool:
	return _state != State.IDLE and _state != State.DEAD


func is_dead() -> bool:
	return _state == State.DEAD


func is_attacking() -> bool:
	return _state == State.ATTACKING or _state == State.RETREATING


func is_blocking() -> bool:
	return _state == State.BLOCKING


func get_block_damage_reduction() -> float:
	if character_stats == null:
		return 0.0
	return maxf(0.0, character_stats.block_damage_reduction)


func set_z_priority(priority: int) -> void:
	z_index = priority


# ── public actions ──

func attack(enemy: CharacterBase) -> void:
	if _state not in [State.IDLE, State.MOVING_TO_IDLE]:
		return
	if not is_instance_valid(enemy) or enemy.is_dead():
		return

	var id := _begin_action()
	_state = State.ATTACKING
	target = enemy
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
		await _wait_tween(_active_tween, id)
		if id != _action_id:
			return

	var pick := _pick_attack()
	var attack_anim: StringName = pick["anim"]
	_play_anim(attack_anim)
	if weapon:
		await _await_anim_frame(attack_anim, int(pick["frame"]), id)
		if id != _action_id:
			return
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.take_damage(weapon.damage, global_position)
	await _await_anim_end(attack_anim, id)
	if id != _action_id:
		return

	retreat_started.emit()
	_state = State.RETREATING

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(self, "global_position", idle_point, retreat_time)
	await _wait_tween(_active_tween, id)
	if id != _action_id:
		return

	z_index = _z_before_attack
	_state = State.IDLE
	_play_anim(ANIM_IDLE)
	turn_finished.emit()


func block() -> void:
	if _state not in [State.IDLE, State.MOVING_TO_IDLE]:
		return
	_cancel_active_tween()
	_state = State.BLOCKING
	_block_absorbed = 0.0
	if _has_anim(ANIM_BLOCK):
		_play_anim(ANIM_BLOCK)
	block_started.emit()


func unblock() -> void:
	if _state != State.BLOCKING:
		return
	_block_absorbed = 0.0
	_state = State.IDLE
	if _has_anim(ANIM_IDLE):
		_play_anim(ANIM_IDLE)
	block_ended.emit()


func take_damage(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if _state == State.DEAD:
		return

	_last_hit_from = from_position

	if _state == State.BLOCKING:
		await _on_blocked_hit(amount, from_position)
		return

	var pick := _pick_damage()
	var damage_anim: StringName = pick["anim"]

	# Не в IDLE (атака/отход/хит) или нет анимации — применяем тихо.
	if _state != State.IDLE or not _has_anim(damage_anim):
		_apply_damage(amount)
		return

	var id := _begin_action()
	_state = State.HIT
	_play_anim(damage_anim)
	await _await_anim_frame(damage_anim, int(pick["frame"]), id)
	if id != _action_id:
		return
	_apply_damage(amount)
	if _state == State.DEAD:
		return
	await _await_anim_end(damage_anim, id)
	if id != _action_id:
		return
	_state = State.IDLE
	if _has_anim(ANIM_IDLE):
		_play_anim(ANIM_IDLE)


func move_to_idle_point(duration: float = 0.3) -> void:
	if _state not in [State.IDLE, State.MOVING_TO_IDLE]:
		return
	var id := _begin_action()
	_state = State.MOVING_TO_IDLE
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "global_position", idle_point, duration)
	await _wait_tween(_active_tween, id)
	if id != _action_id:
		return
	_state = State.IDLE
	turn_finished.emit()


func get_health() -> float:
	return health


func get_max_health() -> float:
	return character_stats.max_health if character_stats else 0.0


func heal(amount: float) -> void:
	if _state == State.DEAD or amount <= 0.0:
		return
	health = minf(character_stats.max_health, health + amount)


# ── hooks for subclasses ──

## Возвращает { anim: StringName, frame: int } для атаки.
## База: дефолтная анимация удара + кадр из оружия.
## Player переопределяет и отдаёт случайный вариант attack_1/2/3 со своим кадром.
func _pick_attack() -> Dictionary:
	return {
		"anim": ANIM_ATTACK,
		"frame": weapon.animation_frame_attack if weapon else 1,
	}


## Возвращает { anim: StringName, frame: int } для реакции на урон.
## База: ANIM_DAMAGE + animation_frame_damage.
func _pick_damage() -> Dictionary:
	return {
		"anim": ANIM_DAMAGE,
		"frame": animation_frame_damage,
	}


## Вызывается после успешного блокирования (после визуальной реакции).
## База: проверяет разрыв блока по block_max_absorbed_damage.
func _after_block_hit() -> void:
	if block_max_absorbed_damage > 0.0 and _block_absorbed >= block_max_absorbed_damage:
		unblock()


# ── internal: action lifecycle ──

func _begin_action() -> int:
	_cancel_active_tween()
	_action_id += 1
	return _action_id


func _cancel_active_tween() -> void:
	if _active_tween and _active_tween.is_valid() and _active_tween.is_running():
		_active_tween.kill()


func _wait_tween(tw: Tween, id: int) -> void:
	await get_tree().process_frame
	while id == _action_id and tw.is_valid() and tw.is_running():
		await get_tree().process_frame


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
	if _state == State.DEAD:
		return
	_state = State.DEAD
	_block_absorbed = 0.0
	_begin_action()  # ++id, kill tween

	_kill_tween(_hit_shake_tween)
	_kill_tween(_flash_tween)
	_kill_tween(_block_flash_tween)

	if animated_sprite:
		animated_sprite.position = _sprite_base_position
		animated_sprite.modulate = Color.WHITE

	_play_anim(ANIM_DEATH)

	died.emit()

	_start_death_knockback()
	_start_death_fade()


# ── internal: реакция на удар ──

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


func _play_hit_shake(
	from_position: Vector2,
	distance_override: float = -1.0,
	preset_override: int = -1
) -> void:
	if not animated_sprite or _state == State.DEAD:
		return

	var p := _resolve_hit_shake(preset_override)
	var distance: float = distance_override if distance_override >= 0.0 else p["distance"]
	var duration: float = p["duration"]
	var oscillations: int = p["oscillations"]
	var decay: float = p["decay"]
	var return_mult: float = p["return_mult"]

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

	_kill_tween(_hit_shake_tween)

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
	if not animated_sprite or _state == State.DEAD:
		return
	_kill_tween(_flash_tween)
	_kill_tween(_block_flash_tween)
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", flash_color, flash_in_duration)
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, flash_out_duration)


# ── internal: блок ──

func play_block_reaction(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if _state == State.DEAD:
		return

	var pick := _pick_damage()
	var total := _get_anim_frame_time(pick["anim"], int(pick["frame"]))
	var lead := total * block_anim_lead_ratio
	var rest := total - lead

	if lead > 0.0:
		await get_tree().create_timer(lead).timeout
		if _state == State.DEAD:
			return
	_play_anim(ANIM_BLOCK)

	if rest > 0.0:
		await get_tree().create_timer(rest).timeout
		if _state == State.DEAD:
			return

	hit_blocked.emit(amount)
	_flash_block()
	_play_hit_shake(from_position, block_shake_distance, HitShakePreset.BLOCK_HIT)


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
	if _state == State.DEAD:
		return

	if leaked > 0.0:
		_apply_damage(leaked, false)
		if _state == State.DEAD:
			return

	_after_block_hit()


func _flash_block() -> void:
	if not animated_sprite or _state == State.DEAD:
		return
	_kill_tween(_block_flash_tween)
	_kill_tween(_flash_tween)
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

	var land := global_position + dir * death_knockback_distance

	var pt := create_tween()
	pt.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pt.tween_property(self, "global_position", land, maxf(death_knockback_duration, 0.01))


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


func _await_anim_end(anim: StringName, id: int) -> void:
	if not _has_anim(anim):
		return
	var elapsed := 0.0
	while id == _action_id \
			and animated_sprite.animation == anim \
			and animated_sprite.is_playing():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed > ANIM_WAIT_TIMEOUT:
			push_warning("Anim '%s' не завершилась за %.1fs на %s (looped?)" % [anim, ANIM_WAIT_TIMEOUT, name])
			if animated_sprite:
				animated_sprite.stop()
			return


func _await_anim_frame(anim: StringName, frame: int, id: int) -> void:
	if not _has_anim(anim) or frame <= 0:
		return
	var count := animated_sprite.sprite_frames.get_frame_count(anim)
	var target_frame := clampi(frame, 0, maxi(count - 1, 0))

	var elapsed := 0.0
	while id == _action_id \
			and animated_sprite.animation == anim \
			and animated_sprite.is_playing():
		if animated_sprite.frame >= target_frame:
			return
		await animated_sprite.frame_changed
		elapsed += get_process_delta_time()
		if elapsed > ANIM_WAIT_TIMEOUT:
			push_warning("Anim '%s' не достигла кадра %d за %.1fs на %s" % [anim, target_frame, ANIM_WAIT_TIMEOUT, name])
			if animated_sprite:
				animated_sprite.stop()
			return


# ── internal: UI ──

func _init_bar(bar: Bar, value: float, max_value: float) -> void:
	if bar:
		bar.setup(value, max_value)


func _sync_bar(bar: Bar, value: float, max_value: float) -> void:
	if bar:
		bar.update_value(value, max_value)


# ── internal: helpers ──

func _kill_tween(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()
