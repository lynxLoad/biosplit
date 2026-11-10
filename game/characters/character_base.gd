extends Node2D
class_name CharacterBase

signal turn_finished
signal damaged(amount: float)
signal died
signal retreat_started
signal block_started
signal block_ended
signal hit_blocked(amount: float)
signal dodge_started
signal attack_dodged(amount: float)
signal attack_missed

enum State { IDLE, MOVING_TO_IDLE, ATTACKING, RETREATING, BLOCKING, DODGING, HIT, DEAD }
enum HitShakePreset { LIGHT, MEDIUM, HEAVY, CRITICAL, JAB, MAGIC, BLOCK_HIT, CUSTOM, NONE }

## Формат: [distance, duration, oscillations, decay, return_mult]
const HIT_SHAKE_PRESETS := {
	HitShakePreset.LIGHT:     [6.0,  0.18, 4, 0.55, 1.2],
	HitShakePreset.MEDIUM:    [14.0, 0.30, 7, 0.65, 1.5],
	HitShakePreset.HEAVY:     [24.0, 0.45, 6, 0.78, 1.6],
	HitShakePreset.CRITICAL:  [32.0, 0.55, 9, 0.80, 2.0],
	HitShakePreset.JAB:       [8.0,  0.12, 3, 0.45, 1.0],
	HitShakePreset.MAGIC:     [10.0, 0.40, 8, 0.70, 1.8],
	HitShakePreset.BLOCK_HIT: [6.0,  0.20, 5, 0.60, 1.3],
	HitShakePreset.NONE:      [0.0,  0.0,  0, 0.0,  0.0],
}

const ANIM_IDLE := &"idle"
const ANIM_ATTACK := &"attack"
const ANIM_DAMAGE := &"damage"
const ANIM_DEATH := &"death"
const ANIM_BLOCK := &"block"
const ANIM_WAIT_TIMEOUT := 3.0
const CORPSE_GROUP := &"corpses"

# ── stats & weapon ──
@export_group("Stats & Weapon")
@export var character_stats: CharacterStats
@export var weapon: Weapon

# ── combat geometry ──
@export_group("Combat Geometry")
@export var strike_distance: float = 80.0
@export var pixels_per_unit: float = 100.0

# ── timing ──
@export_group("Timing")
@export var min_phase_duration: float = 0.08
@export var max_phase_duration: float = 1.5

# ── animations ──
@export_group("Animations")
@export var animation_frame_damage: int = 1
@export var _attack_frames: Dictionary[StringName, int] = {}
@export var _attack_weights: Dictionary[StringName, int] = {}

# ── attack juice ──
@export_group("Attack Juice")
@export_range(0.1, 1.0) var attack_anticipation_speed: float = 0.45
@export_range(1.0, 4.0) var attack_impact_speed: float = 2.0
@export_range(0, 5) var attack_anticipation_frames: int = 2
@export_range(0.0, 16.0) var attack_lunge_distance: float = 4.0
@export_range(0.0, 16.0) var attack_recoil_distance: float = 5.0

# ── strike slow-mo ──
@export_group("Strike Slow-Mo")
## Включать глобальное замедление времени перед ударом.
@export var strike_slowmo_enabled: bool = true
## До какой скорости замедляется время (1.0 = норма, 0.25 = четверть).
@export_range(0.05, 1.0) var strike_slowmo_scale: float = 0.25
## Реальное время (сек) плавного замедления.
@export var strike_slowmo_ramp_down: float = 0.15
## Минимальная длительность slow-mo в реальном времени (сек).
## Гарантирует, что замедление видно, даже если impact_frame = 0.
@export var strike_slowmo_min_duration: float = 0.12

# ── hit shake ──
@export_group("Hit Shake")
@export var hit_shake_preset: HitShakePreset = HitShakePreset.JAB
@export_range(0.0, 0.5) var hit_shake_distance_jitter: float = 0.1
@export_range(0.0, 0.5) var hit_shake_duration_jitter: float = 0.0
@export_range(0.0, 0.5) var hit_shake_decay_jitter: float = 0.0

@export_subgroup("Custom Shake (используется только при preset = CUSTOM)")
@export var hit_shake_distance: float = 14.0
@export var hit_shake_duration: float = 0.3
@export_range(0, 10) var hit_shake_oscillations: int = 7
@export_range(0.0, 1.0) var hit_shake_decay: float = 0.65
@export var hit_shake_return_mult: float = 1.5

# ── hit flash ──
@export_group("Hit Flash")
@export var flash_color: Color = Color(1.0, 0.4, 0.4, 1.0)
@export var flash_in_duration: float = 0.05
@export var flash_out_duration: float = 0.1

# ── block ──
@export_group("Block")
@export var block_max_absorbed_damage: float = 0.0
@export var block_shake_distance: float = 6.0
@export_range(0.0, 16.0) var block_recoil_distance: float = 4.0

@export_subgroup("Block Flash")
@export var block_flash_color: Color = Color(0.4, 0.65, 1.0, 1.0)
@export var block_flash_in_duration: float = 0.03
@export var block_flash_out_duration: float = 0.12

# ── death: knockback ──
@export_group("Death Knockback")
@export var death_knockback_distance: float = 120.0
@export var death_knockback_speed: float = 500.0
@export var death_knockback_angle_jitter: float = 0.2
@export var death_knockback_distance_jitter: float = 0.3
@export_range(0.0, 32.0) var death_arc_height: float = 8.0

@export_group("Death Landing")
@export var death_min_corpse_distance: float = 150.0
@export_range(1, 40) var death_landing_attempts: int = 40
@export var death_landing_bounds: Rect2 = Rect2()
@export var death_landing_viewport_pad: Vector2 = Vector2(60.0, 60.0)

@export_group("Death Corpse & Z")
@export var death_disappear: bool = false
@export_range(0.0, 1.0) var death_corpse_alpha: float = 1.0
@export var death_flying_z: int = 2000
@export var death_corpse_z: int = -1
@export_range(0, 4096) var death_corpse_z_sort_span: int = 1500
@export var death_corpse_sort_y_range: Vector2 = Vector2.ZERO
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
var _idle_bob_tween: Tween
var _recoil_tween: Tween
var _block_absorbed: float = 0.0
var _last_hit_from: Vector2 = Vector2.INF
var _sprite_base_position: Vector2
var _idle_point_set: bool = false
var _corpse_landing_pos: Vector2 = Vector2.INF
var _invulnerable: bool = false
var _slowmo_token: int = 0
var _slowmo_active: bool = false
var _slowmo_prev_scale: float = 1.0	

func _ready() -> void:
	#Engine.time_scale = 0.2
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

func _exit_tree() -> void:
	_end_strike_slowmo()

# ── idle point ──

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

func is_moving_to_idle() -> bool:
	return _state == State.MOVING_TO_IDLE

func is_blocking() -> bool:
	return _state == State.BLOCKING

func is_invulnerable() -> bool:
	return _invulnerable

func is_dodging() -> bool:
	return _state == State.DODGING

func get_health() -> float:
	return health

func get_max_health() -> float:
	return character_stats.max_health if character_stats else 0.0

func set_z_priority(priority: int) -> void:
	z_index = priority

func get_block_damage_reduction() -> float:
	return maxf(0.0, character_stats.block_damage_reduction) if character_stats else 0.0

func get_corpse_anchor() -> Vector2:
	return _corpse_landing_pos if _corpse_landing_pos != Vector2.INF else global_position

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
	var anchor := _resolve_strike_anchor(enemy)
	var dir := _safe_dir(start - anchor, Vector2.RIGHT)
	var strike_pos := start
	if start.distance_to(anchor) > strike_distance:
		strike_pos = anchor + dir * strike_distance
	var speed_px := maxf(character_stats.speed, 0.01) * pixels_per_unit

	# ── подход ──
	if start.distance_to(strike_pos) > 1.0:
		if not (await _move_to(strike_pos, speed_px, id)):
			return
		# ретаргет: цель могла сместиться
		var retarget_anchor := _resolve_strike_anchor(enemy)
		var to_anchor := global_position - retarget_anchor
		var retarget_pos := global_position
		if to_anchor.length() > strike_distance:
			retarget_pos = retarget_anchor + to_anchor.normalized() * strike_distance
		if global_position.distance_to(retarget_pos) > 2.0:
			if not (await _move_to(retarget_pos, speed_px, id)):
				return
		dir = _safe_dir(global_position - _resolve_strike_anchor(enemy), Vector2.RIGHT)

	# ── анимация атаки ──
	var pick := _pick_attack()
	var attack_anim: StringName = pick["anim"]
	var impact_frame := int(pick["frame"])
	_play_anim(attack_anim)
	_play_attack_lunge(dir)
	_start_strike_slowmo()
	if weapon:
		var have_impact_frame := impact_frame > 0 and _has_anim(attack_anim)
		if have_impact_frame:
			await _await_anim_frame(attack_anim, impact_frame, id)
			if id != _action_id:
				_end_strike_slowmo()
				return
			await _play_attack_anticipation(attack_anim, impact_frame, id)
			if id != _action_id:
				_end_strike_slowmo()
				return
		else:
			# Fallback: нет реального кадра удара → даём slow-mo время проявиться.
			# ignore_time_scale = true, иначе таймер замедлится вместе с миром.
			var hold := maxf(strike_slowmo_ramp_down, strike_slowmo_min_duration)
			await get_tree().create_timer(hold, true, false, true).timeout
			if id != _action_id:
				_end_strike_slowmo()
				return

	# ── удар ──
	_end_strike_slowmo()
	if is_instance_valid(enemy) and not enemy.is_dead():
		if _is_strike_in_range(enemy, dir):
			enemy.take_damage(weapon.damage, global_position)
		else:
			attack_missed.emit()
	_play_attack_impact(attack_anim)
	_play_attack_recoil(dir)
	await _await_anim_end(attack_anim, id)
	if id != _action_id:
		return

	# ── отход ──
	retreat_started.emit()
	_state = State.RETREATING
	var retreat_time := clampf(
		global_position.distance_to(idle_point) / speed_px,
		min_phase_duration, max_phase_duration
	)
	if not (await _tween_self_to(idle_point, retreat_time, id, Tween.EASE_IN)):
		return
	z_index = _z_before_attack
	_state = State.IDLE
	_play_anim(ANIM_IDLE)
	turn_finished.emit()

func _is_strike_in_range(enemy: CharacterBase, attack_dir: Vector2) -> bool:
	var to_target := enemy.global_position - global_position
	if to_target.length() > strike_distance * 1.5:
		return false
	return attack_dir.length_squared() <= 0.0001 or to_target.dot(attack_dir) <= 0.0

func block() -> void:
	if _state not in [State.IDLE, State.MOVING_TO_IDLE]:
		return
	_begin_action()
	_state = State.BLOCKING
	_block_absorbed = 0.0
	_play_anim(ANIM_BLOCK)
	block_started.emit()

func unblock() -> void:
	if _state != State.BLOCKING:
		return
	_block_absorbed = 0.0
	_state = State.IDLE
	_play_anim(ANIM_IDLE)
	block_ended.emit()

func take_damage(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if _state == State.DEAD:
		return
	if _invulnerable:
		_on_dodged_hit(amount, from_position)
		return
	_last_hit_from = from_position
	if _state == State.BLOCKING:
		await _on_blocked_hit(amount, from_position)
		return
	var pick := _pick_damage()
	var damage_anim: StringName = pick["anim"]
	var can_react := _state == State.IDLE or _state == State.DODGING
	if not can_react or not _has_anim(damage_anim):
		_apply_damage(amount)
		return
	var id := _begin_action()
	_state = State.HIT
	_play_anim(damage_anim)
	_apply_damage(amount)
	await _await_anim_frame(damage_anim, int(pick["frame"]), id)
	if id != _action_id:
		return
	await _await_anim_end(damage_anim, id)
	if id != _action_id:
		return

	_state = State.IDLE
	_play_anim(ANIM_IDLE)

	# Возврат на «строевую» позицию, если наследник её задал
	# (например, Player после доджа, из которого его выбили).
	var return_pt := _get_post_hit_return_point()
	if return_pt != Vector2.INF and global_position.distance_to(return_pt) > 2.0:
		var speed_px := maxf(character_stats.speed, 0.01) * pixels_per_unit
		await _move_to(return_pt, speed_px, id)

func move_to_idle_point(duration: float = 0.3) -> void:
	if _state not in [State.IDLE, State.MOVING_TO_IDLE]:
		return
	var id := _begin_action()
	_state = State.MOVING_TO_IDLE
	if not (await _tween_self_to(idle_point, duration, id, Tween.EASE_IN_OUT)):
		return
	_state = State.IDLE
	_play_anim(ANIM_IDLE)
	turn_finished.emit()

func heal(amount: float) -> void:
	if _state == State.DEAD or amount <= 0.0:
		return
	health = minf(character_stats.max_health, health + amount)

# ── hooks for subclasses ──

func _pick_attack() -> Dictionary:
	var default_attack := {"anim": ANIM_ATTACK, "frame": weapon.animation_frame_attack if weapon else 1}
	if _attack_frames.is_empty():
		return default_attack
	var available: Array[StringName] = []
	var total_weight := 0.0
	for anim in _attack_frames:
		if _has_anim(anim):
			available.append(anim)
			total_weight += _attack_weight(anim)
	if available.is_empty():
		return default_attack
	if total_weight <= 0.0:
		var fallback: StringName = available.pick_random()
		return {"anim": fallback, "frame": _attack_frames[fallback]}
	var roll := randf() * total_weight
	var chosen: StringName = available[available.size() - 1]
	for anim in available:
		roll -= _attack_weight(anim)
		if roll <= 0.0:
			chosen = anim
			break
	return {"anim": chosen, "frame": _attack_frames[chosen]}

func _resolve_strike_anchor(enemy: CharacterBase) -> Vector2:
	return enemy.get_strike_anchor() if enemy.has_method("get_strike_anchor") else enemy.global_position

func get_strike_anchor() -> Vector2:
	return idle_point if _state in [State.IDLE, State.DODGING, State.MOVING_TO_IDLE] else global_position

func _attack_weight(anim: StringName) -> float:
	return float(_attack_weights.get(anim, 1.0))

func _pick_damage() -> Dictionary:
	return {"anim": ANIM_DAMAGE, "frame": animation_frame_damage}

func _after_block_hit() -> void:
	if block_max_absorbed_damage > 0.0 and _block_absorbed >= block_max_absorbed_damage:
		unblock()

func _on_dodged_hit(amount: float, from_position: Vector2) -> void:
	attack_dodged.emit(amount)

func _hide_ui_on_death() -> void:
	pass

func _get_post_hit_return_point() -> Vector2:
	return Vector2.INF

# ── action lifecycle ──

func _begin_action() -> int:
	_kill_tween(_active_tween)
	_end_strike_slowmo()
	_action_id += 1
	return _action_id

func _wait_tween(tw: Tween, id: int) -> void:
	await get_tree().process_frame
	while id == _action_id and tw.is_valid() and tw.is_running():
		await get_tree().process_frame

func _tween_self_to(pos: Vector2, duration: float, id: int, ease: Tween.EaseType = Tween.EASE_OUT) -> bool:
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(ease)
	_active_tween.tween_property(self, "global_position", pos, duration)
	await _wait_tween(_active_tween, id)
	return id == _action_id

func _move_to(pos: Vector2, speed_px: float, id: int) -> bool:
	var t := clampf(global_position.distance_to(pos) / speed_px, min_phase_duration, max_phase_duration)
	return await _tween_self_to(pos, t, id)

# ── juice: attack ──

func _tween_sprite_offset(offset: Vector2, out_time: float, back_time: float, trans: Tween.TransitionType = Tween.TRANS_QUAD) -> void:
	if not animated_sprite:
		return
	_kill_tween(_recoil_tween)
	_recoil_tween = create_tween()
	_recoil_tween.set_trans(trans).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(animated_sprite, "position", _sprite_base_position + offset, out_time)
	_recoil_tween.tween_property(animated_sprite, "position", _sprite_base_position, back_time)

func _play_attack_lunge(dir: Vector2) -> void:
	if attack_lunge_distance <= 0.0:
		return
	_tween_sprite_offset(-dir * attack_lunge_distance, 0.06, 0.08, Tween.TRANS_SINE)

func _play_attack_recoil(dir: Vector2) -> void:
	if attack_recoil_distance <= 0.0:
		return
	_tween_sprite_offset(dir * attack_recoil_distance, 0.05, 0.10)

func _play_attack_anticipation(anim: StringName, impact_frame: int, id: int) -> void:
	if not animated_sprite or not _has_anim(anim):
		return
	if attack_anticipation_frames <= 0 or attack_anticipation_speed >= 1.0:
		return
	var target_frame := clampi(
		impact_frame - attack_anticipation_frames, 0,
		maxi(animated_sprite.sprite_frames.get_frame_count(anim) - 1, 0)
	)
	var old_speed := animated_sprite.speed_scale
	animated_sprite.speed_scale = attack_anticipation_speed
	while id == _action_id \
			and animated_sprite.animation == anim \
			and animated_sprite.is_playing() \
			and animated_sprite.frame < target_frame:
		await animated_sprite.frame_changed
	if id == _action_id and is_instance_valid(animated_sprite):
		animated_sprite.speed_scale = old_speed

func _play_attack_impact(anim: StringName) -> void:
	if not animated_sprite or attack_impact_speed <= 1.0:
		return
	var old_speed := animated_sprite.speed_scale
	animated_sprite.speed_scale = attack_impact_speed
	var impact_time := _get_anim_frame_time(anim, 1)
	await get_tree().create_timer(maxf(impact_time * 0.5, 0.02)).timeout
	if is_instance_valid(animated_sprite):
		animated_sprite.speed_scale = old_speed

# ── strike slow-mo ──

func _start_strike_slowmo() -> void:
	if not strike_slowmo_enabled:
		return
	_slowmo_prev_scale = Engine.time_scale if Engine.time_scale > 0.0 else 1.0
	_slowmo_active = true
	_slowmo_token += 1
	_ramp_time_scale(strike_slowmo_scale, strike_slowmo_ramp_down, _slowmo_token)

func _end_strike_slowmo() -> void:
	if not _slowmo_active:
		return
	_slowmo_active = false
	_slowmo_token += 1
	Engine.time_scale = _slowmo_prev_scale

func _ramp_time_scale(target: float, duration: float, token: int) -> void:
	if duration <= 0.0:
		if token == _slowmo_token:
			Engine.time_scale = target
		return
	var start_scale := Engine.time_scale
	var start_real := Time.get_ticks_msec() / 1000.0
	var elapsed := 0.0
	while token == _slowmo_token and elapsed < duration:
		await get_tree().process_frame
		if token != _slowmo_token:
			return
		elapsed = Time.get_ticks_msec() / 1000.0 - start_real
		var t := clampf(elapsed / duration, 0.0, 1.0)
		Engine.time_scale = lerpf(start_scale, target, t)
	if token == _slowmo_token:
		Engine.time_scale = target

# ── damage ──

func _apply_damage(amount: float, flash: bool = true) -> void:
	health = maxf(0.0, health - amount)
	damaged.emit(amount)
	if health <= 0.0:
		_die()
		return
	if flash:
		_flash(flash_color, flash_in_duration, flash_out_duration)
	_play_hit_shake(_last_hit_from)

func _die() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	_invulnerable = false
	_block_absorbed = 0.0
	_begin_action()
	for tw in [_hit_shake_tween, _flash_tween, _idle_bob_tween, _recoil_tween]:
		_kill_tween(tw)
	if animated_sprite:
		animated_sprite.position = _sprite_base_position
		animated_sprite.modulate = Color.WHITE
	_hide_ui_on_death()
	_play_anim(ANIM_DEATH)
	if not death_disappear:
		add_to_group(CORPSE_GROUP)
	died.emit()
	_start_death_knockback()
	_start_death_fade()

# ── hit reaction ──

func _resolve_hit_shake(preset_override: int = -1) -> Array:
	var preset: int = preset_override if preset_override >= 0 else hit_shake_preset
	if preset == HitShakePreset.CUSTOM:
		return [hit_shake_distance, hit_shake_duration, hit_shake_oscillations, hit_shake_decay, hit_shake_return_mult]
	return HIT_SHAKE_PRESETS.get(preset, HIT_SHAKE_PRESETS[HitShakePreset.MEDIUM])

func _play_hit_shake(from_position: Vector2, distance_override: float = -1.0, preset_override: int = -1) -> void:
	if not animated_sprite or _state == State.DEAD:
		return
	var p := _resolve_hit_shake(preset_override)
	var distance: float = distance_override if distance_override >= 0.0 else p[0]
	var duration: float = p[1]
	var oscillations: int = maxi(1, p[2])
	var decay: float = p[3]
	var return_mult: float = p[4]
	if hit_shake_distance_jitter > 0.0:
		distance *= randf_range(1.0 - hit_shake_distance_jitter, 1.0 + hit_shake_distance_jitter)
	if hit_shake_duration_jitter > 0.0:
		duration *= randf_range(1.0 - hit_shake_duration_jitter, 1.0 + hit_shake_duration_jitter)
	if hit_shake_decay_jitter > 0.0:
		decay = clampf(decay + randf_range(-hit_shake_decay_jitter, hit_shake_decay_jitter), 0.0, 1.0)
	var dir := _dir_from(from_position, Vector2.UP)
	_kill_tween(_hit_shake_tween)
	_hit_shake_tween = create_tween()
	_hit_shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var half_steps := oscillations * 2
	var step_duration := maxf(duration / float(half_steps + 1), 0.01)
	var amp := distance
	for i in range(half_steps):
		var target := _sprite_base_position + dir * amp if i % 2 == 0 else _sprite_base_position - dir * amp
		var tw := _hit_shake_tween.tween_property(animated_sprite, "position", target, step_duration)
		if i == 0:
			tw.set_ease(Tween.EASE_OUT)
		amp *= decay
	_hit_shake_tween.tween_property(
		animated_sprite, "position", _sprite_base_position, maxf(step_duration * return_mult, 0.01)
	).set_ease(Tween.EASE_OUT)

func _flash(color: Color, in_duration: float, out_duration: float) -> void:
	if not animated_sprite or _state == State.DEAD:
		return
	_kill_tween(_flash_tween)
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", color, in_duration)
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, out_duration)

# ── block ──

func play_block_reaction(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if _state == State.DEAD:
		return
	_play_anim(ANIM_BLOCK)
	hit_blocked.emit()
	_flash(block_flash_color, block_flash_in_duration, block_flash_out_duration)
	_play_hit_shake(from_position, block_shake_distance, HitShakePreset.BLOCK_HIT)
	if block_recoil_distance > 0.0:
		_tween_sprite_offset(_dir_from(from_position, Vector2.UP) * block_recoil_distance, 0.05, 0.12)

func _get_anim_frame_time(anim: StringName, frame: int) -> float:
	if not _has_anim(anim) or frame <= 0:
		return 0.0
	var speed := animated_sprite.sprite_frames.get_animation_speed(anim)
	return float(frame) / speed if speed > 0.0 else 0.0

func _on_blocked_hit(amount: float, from_position: Vector2) -> void:
	var leaked := maxf(0.0, amount - get_block_damage_reduction())
	_block_absorbed += amount - leaked
	await play_block_reaction(amount, from_position)
	if _state == State.DEAD:
		return
	if leaked > 0.0:
		_apply_damage(leaked, false)
	_after_block_hit()

# ── death movement ──

func _start_death_knockback() -> void:
	var base_dir := _dir_from(_last_hit_from, Vector2.UP)
	var land := _find_corpse_landing(base_dir)
	_corpse_landing_pos = land
	z_index = death_flying_z
	var fly_duration := maxf(global_position.distance_to(land) / maxf(death_knockback_speed, 1.0), min_phase_duration)
	var knockback := create_tween()
	knockback.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	knockback.tween_property(self, "global_position", land, fly_duration)
	if animated_sprite and death_arc_height > 0.0:
		var arc := create_tween()
		arc.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		arc.tween_property(animated_sprite, "position", _sprite_base_position + Vector2(0.0, -death_arc_height), fly_duration * 0.4)
		arc.tween_property(animated_sprite, "position", _sprite_base_position, fly_duration * 0.6)
	if not death_disappear:
		_drop_z_when_death_settled(knockback)

func _drop_z_when_death_settled(knockback_tween: Tween) -> void:
	if knockback_tween and knockback_tween.is_valid() and knockback_tween.is_running():
		await knockback_tween.finished
	if _state != State.DEAD:
		return
	await _await_death_anim_last_frame()
	if _state == State.DEAD:
		z_index = _compute_corpse_z()

func _compute_corpse_z() -> int:
	if death_corpse_z_sort_span <= 0:
		return death_corpse_z
	var y_range := _resolve_corpse_sort_y_range()
	if y_range.y <= y_range.x:
		return death_corpse_z
	var t := clampf(inverse_lerp(y_range.x, y_range.y, _corpse_landing_pos.y), 0.0, 1.0)
	return maxi(death_corpse_z - int(round((1.0 - t) * float(death_corpse_z_sort_span))), -4096)

func _resolve_corpse_sort_y_range() -> Vector2:
	if death_corpse_sort_y_range.y > death_corpse_sort_y_range.x:
		return death_corpse_sort_y_range
	var bounds := _resolve_landing_bounds()
	return Vector2(bounds.position.y, bounds.end.y) if bounds.size.y > 0.0 else Vector2.ZERO

func _await_death_anim_last_frame() -> void:
	if not _has_anim(ANIM_DEATH):
		return
	if not animated_sprite or animated_sprite.animation != ANIM_DEATH:
		return
	var last_frame := maxi(animated_sprite.sprite_frames.get_frame_count(ANIM_DEATH) - 1, 0)
	if animated_sprite.frame >= last_frame:
		return
	var elapsed := 0.0
	while animated_sprite.animation == ANIM_DEATH and animated_sprite.is_playing():
		if animated_sprite.frame >= last_frame:
			return
		await animated_sprite.frame_changed
		elapsed += get_process_delta_time()
		if elapsed > ANIM_WAIT_TIMEOUT:
			push_warning("Death anim не дошла до последнего кадра за %.1fs на %s" % [ANIM_WAIT_TIMEOUT, name])
			return

func _find_corpse_landing(base_dir: Vector2) -> Vector2:
	var corpses := get_tree().get_nodes_in_group(CORPSE_GROUP)
	var bounds := _resolve_landing_bounds()
	var best := global_position + base_dir * death_knockback_distance
	var best_min_dist := -1.0
	for _attempt in death_landing_attempts:
		var angle := randf_range(-death_knockback_angle_jitter, death_knockback_angle_jitter) if death_knockback_angle_jitter > 0.0 else 0.0
		var dist := death_knockback_distance
		if death_knockback_distance_jitter > 0.0:
			dist *= randf_range(1.0 - death_knockback_distance_jitter, 1.0 + death_knockback_distance_jitter)
		var candidate := global_position + base_dir.rotated(angle) * dist
		if bounds.size != Vector2.ZERO:
			candidate = _clamp_to_rect(candidate, bounds)
		var min_dist := _min_dist_to_corpses(candidate, corpses)
		if min_dist >= death_min_corpse_distance:
			return candidate
		if min_dist > best_min_dist:
			best_min_dist = min_dist
			best = candidate
	return best

func _min_dist_to_corpses(pos: Vector2, corpses: Array) -> float:
	var min_dist := INF
	for corpse in corpses:
		if corpse == self or not is_instance_valid(corpse):
			continue
		var cp: Vector2 = corpse.get_corpse_anchor() if corpse.has_method("get_corpse_anchor") else corpse.global_position
		min_dist = minf(min_dist, pos.distance_to(cp))
	return min_dist

func _resolve_landing_bounds() -> Rect2:
	if death_landing_bounds.size != Vector2.ZERO:
		return death_landing_bounds
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var inner := Rect2(
		viewport.get_visible_rect().position + death_landing_viewport_pad,
		viewport.get_visible_rect().size - death_landing_viewport_pad * 2.0
	)
	return inner if inner.size.x > 0.0 and inner.size.y > 0.0 else Rect2()

func _clamp_to_rect(pos: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clampf(pos.x, rect.position.x, rect.end.x),
		clampf(pos.y, rect.position.y, rect.end.y)
	)

func _start_death_fade() -> void:
	if not death_disappear and is_equal_approx(death_corpse_alpha, 1.0):
		return
	var fade := create_tween()
	if death_fade_delay > 0.0:
		fade.tween_interval(death_fade_delay)
	if death_disappear:
		fade.tween_property(self, "modulate:a", 0.0, maxf(death_fade_duration, 0.01))
		fade.tween_callback(queue_free)
	elif death_fade_duration > 0.0:
		fade.tween_property(self, "modulate:a", death_corpse_alpha, death_fade_duration)
	else:
		modulate.a = death_corpse_alpha

# ── animation helpers ──

func _play_anim(anim: StringName) -> void:
	if not _has_anim(anim):
		return
	if animated_sprite.animation == anim and animated_sprite.is_playing():
		return
	animated_sprite.play(anim)

func _has_anim(anim: StringName) -> bool:
	return animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(anim)

func _warn_anim_timeout(msg: String) -> void:
	push_warning(msg)
	if animated_sprite:
		animated_sprite.stop()

func _await_anim_end(anim: StringName, id: int) -> void:
	if not _has_anim(anim):
		return
	var elapsed := 0.0
	while id == _action_id and animated_sprite.animation == anim and animated_sprite.is_playing():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed > ANIM_WAIT_TIMEOUT:
			_warn_anim_timeout("Anim '%s' не завершилась за %.1fs на %s (looped?)" % [anim, ANIM_WAIT_TIMEOUT, name])
			return

func _await_anim_frame(anim: StringName, frame: int, id: int) -> void:
	if not _has_anim(anim) or frame <= 0:
		return
	var target := clampi(frame, 0, maxi(animated_sprite.sprite_frames.get_frame_count(anim) - 1, 0))
	var elapsed := 0.0
	while id == _action_id and animated_sprite.animation == anim and animated_sprite.is_playing():
		if animated_sprite.frame >= target:
			return
		await animated_sprite.frame_changed
		elapsed += get_process_delta_time()
		if elapsed > ANIM_WAIT_TIMEOUT:
			_warn_anim_timeout("Anim '%s' не достигла кадра %d за %.1fs на %s" % [anim, target, ANIM_WAIT_TIMEOUT, name])
			return

# ── UI helpers ──

func _init_bar(bar: HealthBar, value: float, max_value: float) -> void:
	if bar:
		bar.setup(value, max_value)

func _sync_bar(bar: HealthBar, value: float, max_value: float) -> void:
	if bar:
		bar.update_value(value, max_value)

# ── generic helpers ──

func _dir_from(from: Vector2, fallback: Vector2 = Vector2.UP) -> Vector2:
	if from == Vector2.INF:
		return fallback
	var d := global_position - from
	return d.normalized() if d.length_squared() > 0.0001 else fallback

func _safe_dir(v: Vector2, fallback: Vector2 = Vector2.RIGHT) -> Vector2:
	return v.normalized() if v.length_squared() > 0.0001 else fallback

func _kill_tween(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()
