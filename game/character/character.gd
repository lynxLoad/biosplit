extends Node2D
class_name Character

signal turn_finished
signal damaged(amount: float)
signal died
signal retreat_started
signal block_started
signal block_ended
signal hit_blocked(amount: float)

enum State { IDLE, MOVING_TO_IDLE, ATTACKING, RETREATING, BLOCKING, HIT, DEAD }

const ANIM_IDLE := &"idle"
const ANIM_ATTACK := &"attack"
const ANIM_DAMAGE := &"damage"
const ANIM_DEATH := &"death"
const ANIM_BLOCK := &"block"

# ── config ──

@export_group("Stats")
@export var character_stats: CharacterStats
@export var weapon: Weapon

@export_group("Movement")
@export var strike_distance: float = 80.0
@export var pixels_per_unit: float = 100.0
@export var min_phase_duration: float = 0.08
@export var max_phase_duration: float = 1.5

@export_group("Attack")
@export var _attack_frames: Dictionary[StringName, int] = {}
@export var _attack_weights: Dictionary[StringName, int] = {}
@export var animation_frame_damage: int = 1
@export var z_attack_priority: int = 1000

@export_group("Hit Shake")
@export var hit_shake_preset: HitShakePresets.Preset = HitShakePresets.Preset.JAB
@export_range(0.0, 0.5) var hit_shake_distance_jitter: float = 0.1
@export_range(0.0, 0.5) var hit_shake_duration_jitter: float = 0.0
@export_range(0.0, 0.5) var hit_shake_decay_jitter: float = 0.0

@export_subgroup("Custom")
@export var hit_shake_distance: float = 14.0
@export var hit_shake_duration: float = 0.3
@export_range(0, 10) var hit_shake_oscillations: int = 7
@export_range(0.0, 1.0) var hit_shake_decay: float = 0.65
@export var hit_shake_return_mult: float = 1.5

@export_group("Flash")
@export var flash_color: Color = Color(1.0, 0.4, 0.4, 1.0)
@export var flash_in_duration: float = 0.05
@export var flash_out_duration: float = 0.1

@export_subgroup("Block")
@export var block_flash_color: Color = Color(0.4, 0.65, 1.0, 1.0)
@export var block_flash_in_duration: float = 0.03
@export var block_flash_out_duration: float = 0.12

@export_group("Juice")
@export_range(0.0, 0.25) var hit_stop_duration: float = 0.06
@export_range(0.1, 1.0) var attack_anticipation_speed: float = 0.45
@export_range(1.0, 4.0) var attack_impact_speed: float = 2.0
@export_range(0, 5) var attack_anticipation_frames: int = 2
@export_range(0.0, 16.0) var attack_lunge_distance: float = 4.0
@export_range(0.0, 16.0) var attack_recoil_distance: float = 5.0

@export_group("Block")
@export_range(0.0, 1.0) var block_anim_lead_ratio: float = 1.0
@export var block_shake_distance: float = 6.0
@export_range(0.0, 16.0) var block_recoil_distance: float = 4.0
@export var block_max_absorbed_damage: float = 0.0

@export_group("Death")
@export var death_arc_height: float = 8.0
@export var death_knockback_distance: float = 120.0
@export var death_knockback_speed: float = 500.0
@export var death_knockback_angle_jitter: float = 0.2
@export var death_knockback_distance_jitter: float = 0.3
@export var death_min_corpse_distance: float = 150.0
@export_range(1, 40) var death_landing_attempts: int = 40
@export var death_landing_bounds: Rect2 = Rect2()
@export var death_landing_viewport_pad: Vector2 = Vector2(60.0, 60.0)

@export_subgroup("Corpse")
@export var death_disappear: bool = false
@export_range(0.0, 1.0) var death_corpse_alpha: float = 1.0
@export var death_flying_z: int = 2000
@export var death_corpse_z: int = -1
@export_range(0, 4096) var death_corpse_z_sort_span: int = 1500
@export var death_corpse_sort_y_range: Vector2 = Vector2.ZERO
@export var death_fade_duration: float = 0.5
@export var death_fade_delay: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# ── state ──

var target: Character
var idle_point: Vector2

var _state: State = State.IDLE
var _z_before_attack: int = 0
var _last_hit_from: Vector2 = Vector2.INF
var _sprite_base_position: Vector2
var _idle_point_set: bool = false

# ── services ──

var _ctx: ActionContext
var _health: HealthComponent
var _anim: AnimationHelper
var _flash: FlashService
var _hit_shake: HitShakeService
var _hit_stop: HitStopService
var _move: MovementService
var _juice: CombatJuice
var _death: DeathService
var _block: BlockController


func _ready() -> void:
	if character_stats == null:
		push_error("Character: character_stats не задан на %s" % name)
		character_stats = CharacterStats.new()
	character_stats = character_stats.duplicate()

	_health = HealthComponent.new()
	_health.setup(character_stats.max_health)

	if not _idle_point_set:
		reset_idle_point()

	if animated_sprite:
		_sprite_base_position = animated_sprite.position
		_setup_services()
		_anim.play(ANIM_IDLE)


func _setup_services() -> void:
	_ctx = ActionContext.new()

	_anim = AnimationHelper.new()
	_anim.setup(self, animated_sprite)

	_flash = FlashService.new()
	_flash.setup(animated_sprite, func() -> bool: return is_dead())

	_hit_shake = HitShakeService.new()
	_hit_shake.setup(
		animated_sprite,
		_sprite_base_position,
		func() -> Vector2: return global_position,
		func() -> bool: return is_dead()
	)
	_hit_shake.distance_jitter = hit_shake_distance_jitter
	_hit_shake.duration_jitter = hit_shake_duration_jitter
	_hit_shake.decay_jitter = hit_shake_decay_jitter
	_hit_shake.custom = {
		"distance": hit_shake_distance,
		"duration": hit_shake_duration,
		"oscillations": hit_shake_oscillations,
		"decay": hit_shake_decay,
		"return_mult": hit_shake_return_mult,
	}

	_hit_stop = HitStopService.new()
	_hit_stop.setup(self, animated_sprite)

	_move = MovementService.new()
	_move.setup(self, _ctx)

	_juice = CombatJuice.new()
	_juice.setup(self, animated_sprite, _sprite_base_position, _anim)
	_juice.attack_anticipation_speed = attack_anticipation_speed
	_juice.attack_impact_speed = attack_impact_speed
	_juice.attack_anticipation_frames = attack_anticipation_frames
	_juice.attack_lunge_distance = attack_lunge_distance
	_juice.attack_recoil_distance = attack_recoil_distance
	_juice.block_recoil_distance = block_recoil_distance

	_death = DeathService.new()
	_death.setup(
		self,
		animated_sprite,
		_sprite_base_position,
		_anim,
		func() -> Vector2: return _last_hit_from
	)
	_death.arc_height = death_arc_height
	_death.knockback_distance = death_knockback_distance
	_death.knockback_speed = death_knockback_speed
	_death.knockback_angle_jitter = death_knockback_angle_jitter
	_death.knockback_distance_jitter = death_knockback_distance_jitter
	_death.min_corpse_distance = death_min_corpse_distance
	_death.landing_attempts = death_landing_attempts
	_death.landing_bounds = death_landing_bounds
	_death.landing_viewport_pad = death_landing_viewport_pad
	_death.disappear = death_disappear
	_death.corpse_alpha = death_corpse_alpha
	_death.flying_z = death_flying_z
	_death.corpse_z = death_corpse_z
	_death.corpse_z_sort_span = death_corpse_z_sort_span
	_death.corpse_sort_y_range = death_corpse_sort_y_range
	_death.fade_duration = death_fade_duration
	_death.fade_delay = death_fade_delay

	_block = BlockController.new()
	_block.setup(
		self,
		_anim,
		_flash,
		_hit_shake,
		_juice,
		func() -> Dictionary: return _pick_damage(),
		func() -> bool: return is_dead()
	)
	_block.lead_ratio = block_anim_lead_ratio
	_block.flash_color = block_flash_color
	_block.flash_in = block_flash_in_duration
	_block.flash_out = block_flash_out_duration
	_block.shake_distance = block_shake_distance
	_block.max_absorbed = block_max_absorbed_damage
	_block.damage_reduction = get_block_damage_reduction()


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


func is_blocking() -> bool:
	return _state == State.BLOCKING


func get_health() -> float:
	return _health.health if _health else 0.0


func get_max_health() -> float:
	return _health.max_health if _health else 0.0


func set_z_priority(priority: int) -> void:
	z_index = priority


func get_block_damage_reduction() -> float:
	if character_stats == null:
		return 0.0
	return maxf(0.0, character_stats.block_damage_reduction)


func get_corpse_anchor() -> Vector2:
	return _death.get_corpse_anchor() if _death else global_position


# ── public actions ──

func attack(enemy: Character) -> void:
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
	var retreat_dist := strike_pos.distance_to(idle_point)
	var approach_time := clampf(approach_dist / speed_px, min_phase_duration, max_phase_duration)
	var retreat_time := clampf(retreat_dist / speed_px, min_phase_duration, max_phase_duration)

	if approach_dist > 1.0:
		var ok := await _move.move_to(
			strike_pos, approach_time, id, Tween.TRANS_QUAD, Tween.EASE_OUT
		)
		if not ok:
			return

	var pick := _pick_attack()
	var attack_anim: StringName = pick["anim"]
	var impact_frame := int(pick["frame"])

	_anim.play(attack_anim)
	_juice.play_lunge(dir)

	if weapon:
		await _juice.play_anticipation(attack_anim, impact_frame, _ctx, id)
		if not _ctx.is_current(id): return
		await _anim.await_frame(attack_anim, impact_frame, _ctx, id)
		if not _ctx.is_current(id): return
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.take_damage(weapon.damage, global_position)

	_juice.play_impact(attack_anim)
	_juice.play_attack_recoil(dir)

	await _anim.await_end(attack_anim, _ctx, id)
	if not _ctx.is_current(id):
		return

	retreat_started.emit()
	_state = State.RETREATING

	var ok := await _move.move_to(
		idle_point, retreat_time, id, Tween.TRANS_QUAD, Tween.EASE_IN
	)
	if not ok:
		return

	z_index = _z_before_attack
	_state = State.IDLE
	_anim.play(ANIM_IDLE)
	turn_finished.emit()


func block() -> void:
	if _state not in [State.IDLE, State.MOVING_TO_IDLE]:
		return
	_begin_action()
	_state = State.BLOCKING
	_block.reset()
	if _anim.has(ANIM_BLOCK):
		_anim.play(ANIM_BLOCK)
	block_started.emit()


func unblock() -> void:
	if _state != State.BLOCKING:
		return
	_block.reset()
	_state = State.IDLE
	if _anim.has(ANIM_IDLE):
		_anim.play(ANIM_IDLE)
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

	if _state != State.IDLE or not _anim.has(damage_anim):
		_apply_damage(amount)
		return

	var id := _begin_action()
	_state = State.HIT
	_anim.play(damage_anim)

	await _anim.await_frame(damage_anim, int(pick["frame"]), _ctx, id)
	if not _ctx.is_current(id):
		return

	_apply_damage(amount)

	await _anim.await_end(damage_anim, _ctx, id)
	if not _ctx.is_current(id):
		return

	_state = State.IDLE
	if _anim.has(ANIM_IDLE):
		_anim.play(ANIM_IDLE)


func move_to_idle_point(duration: float = 0.3) -> void:
	if _state not in [State.IDLE, State.MOVING_TO_IDLE]:
		return

	var id := _begin_action()
	_state = State.MOVING_TO_IDLE

	var ok := await _move.move_to(
		idle_point, duration, id, Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	if not ok:
		return

	_state = State.IDLE
	_anim.play(ANIM_IDLE)
	turn_finished.emit()


func heal(amount: float) -> void:
	if _state == State.DEAD or amount <= 0.0:
		return
	_health.heal(amount)


# ── hooks for subclasses ──

func _pick_attack() -> Dictionary:
	if _attack_frames.is_empty():
		return {
			"anim": ANIM_ATTACK,
			"frame": weapon.animation_frame_attack if weapon else 1,
		}

	var available: Array[StringName] = []
	var total_weight := 0.0

	for anim in _attack_frames:
		if _anim.has(anim):
			available.append(anim)
			total_weight += _attack_weight(anim)

	if available.is_empty():
		return {
			"anim": ANIM_ATTACK,
			"frame": weapon.animation_frame_attack if weapon else 1,
		}

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


func _attack_weight(anim: StringName) -> float:
	return float(_attack_weights.get(anim, 1.0))


func _pick_damage() -> Dictionary:
	return {"anim": ANIM_DAMAGE, "frame": animation_frame_damage}


func _after_block_hit() -> void:
	if _block.should_drop():
		unblock()


func _hide_ui_on_death() -> void:
	pass


# ── action lifecycle ──

func _begin_action() -> int:
	_move.kill()
	return _ctx.begin()


# ── damage / death ──

func _apply_damage(amount: float, flash: bool = true) -> void:
	_health.apply(amount)
	damaged.emit(amount)

	if _health.is_dead():
		_die()
		return

	if flash:
		_flash.flash(flash_color, flash_in_duration, flash_out_duration)

	_hit_shake.play(_last_hit_from, hit_shake_preset)
	_hit_stop.play(hit_stop_duration)


func _die() -> void:
	if _state == State.DEAD:
		return

	_state = State.DEAD
	_block.reset()
	_begin_action()
	_hit_shake.kill()
	_flash.kill()
	_juice.kill()

	if animated_sprite:
		animated_sprite.position = _sprite_base_position
		animated_sprite.modulate = Color.WHITE

	_hide_ui_on_death()
	_anim.play(ANIM_DEATH)

	if not death_disappear:
		add_to_group(DeathService.CORPSE_GROUP)

	died.emit()
	_death.play_death()


func _on_blocked_hit(amount: float, from_position: Vector2) -> void:
	var leaked := await _block.on_hit(
		amount, from_position, func() -> void: hit_blocked.emit(amount)
	)
	if _state == State.DEAD:
		return

	if leaked > 0.0:
		_apply_damage(leaked, false)

	_after_block_hit()


# ── backward-compat для сабклассов ──

var health: float:
	get:
		return _health.health if _health else 0.0
	set(value):
		if _health:
			_health.health = value


func _play_anim(anim: StringName) -> void:
	_anim.play(anim)


func _kill_tween(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()


## Публичная «визуальная» реакция блока (без учёта absorbed).
## Используется сабклассами (Enemy reactive block).
func play_block_reaction(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if is_dead():
		return
	await _block.play_reaction(from_position, func() -> void: hit_blocked.emit(amount))

func _init_bar(bar: HealthBar, value: float, max_value: float) -> void:
	if bar:
		bar.setup(value, max_value)


func _sync_bar(bar: HealthBar, value: float, max_value: float) -> void:
	if bar:
		bar.update_value(value, max_value)
