extends Node2D
class_name CharacterBase

signal turn_finished
signal damaged(amount: float)
signal died
signal retreat_started

@export var character_stats: CharacterStats
@export var weapon: Weapon

@export var strike_distance: float = 80.0
@export var pixels_per_unit: float = 100.0
@export var min_phase_duration: float = 0.08
@export var max_phase_duration: float = 1.5

## Кадр анимации "damage", на котором реально уменьшается HP и обновляется бар.
@export var animation_frame_damage: int = 3

## ── реакция на удар (без сквоша) ──
## Короткое смещение спрайта «от удара» и обратно.
## Узел (global_position) не трогаем — только animated_sprite.position.
@export var hit_shake_distance: float = 14.0
@export var hit_shake_duration: float = 0.12      # в одну сторону
@export var hit_shake_return_mult: float = 1.5    # возврат чуть медленнее

## ── флэш при уроне ──
@export var flash_color: Color = Color(1, 0.4, 0.4, 1)
@export var flash_in_duration: float = 0.05
@export var flash_out_duration: float = 0.1

## ── смерть: отлёт ──
@export var death_knockback_distance: float = 100.0
@export var death_knockback_duration: float = 0.45
@export var death_knockback_arc: float = 0.0
@export var death_knockback_rotation_deg: float = 0.0

## ── смерть: затухание ──
## Весь fade тела и самоудаление узла — здесь, в персонаже.
## Держи >= death_knockback_duration, чтобы труп не исчез на середине дуги.
@export var death_fade_duration: float = 0.5
@export var death_fade_delay: float = 0.0

## Приоритет отрисовки во время собственной атаки.
## Атакующий всегда выше всех остальных (и живых, и умирающих).
@export var z_attack_priority: int = 1000

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var target: CharacterBase
var idle_point: Vector2
var health: float

var _is_dead: bool = false
var _is_busy: bool = false
var _is_attacking: bool = false
var _z_before_attack: int = 0

var _active_tween: Tween
var _hit_shake_tween: Tween
var _flash_tween: Tween
var _last_hit_from: Vector2 = Vector2.INF
var _sprite_base_position: Vector2

const ANIM_IDLE   := &"idle"
const ANIM_ATTACK := &"attack"
const ANIM_DAMAGE := &"damage"
const ANIM_DEATH  := &"death"


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


## Атакующий ли персонаж прямо сейчас (подлёт + анимация атаки).
## Спавнер использует этот флаг, чтобы не перебивать z атакующего
## во время reflow.
func is_attacking() -> bool:
	return _is_attacking


## Задаёт приоритет отрисовки всего узла (спрайт + health bar).
## z_index перебивает y-sort, поэтому лидер останется сверху
## даже во время knockback/fade при смерти.
func set_z_priority(priority: int) -> void:
	z_index = priority


# ── public ──

func attack(enemy: CharacterBase) -> void:
	if _is_dead or _is_busy or not is_instance_valid(enemy) or enemy.is_dead():
		return
	_is_busy = true
	target = enemy

	# Поднимаемся над всеми на время своей атаки.
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

	# 1) Подлёт
	if approach_dist > 1.0:
		_active_tween = create_tween()
		_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(self, "global_position", strike_pos, approach_time)
		await _wait_tween(_active_tween)
		if _is_dead:
			return

	# 2) Анимация атаки — урон на конкретном кадре
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

	# 3) Отход
	retreat_started.emit()

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(self, "global_position", idle_point, retreat_time)
	await _wait_tween(_active_tween)
	if _is_dead:
		return

	# Возвращаем нормальный z. Если за время атаки лидерство сменилось,
	# спавнер сразу после turn_finished пересчитает z через reflow
	# (см. подписку turn_finished -> _apply_z_order в спавнере).
	_is_attacking = false
	z_index = _z_before_attack

	_is_busy = false
	_play_anim(ANIM_IDLE)
	turn_finished.emit()


func take_damage(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if _is_dead:
		return

	_last_hit_from = from_position

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

func _apply_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	damaged.emit(amount)
	if health <= 0.0:
		_die()
	else:
		_flash_damage()
		_play_hit_shake(_last_hit_from)


func _die() -> void:
	_is_dead = true
	if _active_tween and _active_tween.is_valid() and _active_tween.is_running():
		_active_tween.kill()
	if _hit_shake_tween and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if animated_sprite:
		animated_sprite.position = _sprite_base_position
		animated_sprite.modulate = Color.WHITE

	_play_anim(ANIM_DEATH)

	# Сначала сообщаем миру (спавнер прочитает корректный global_position
	# ещё до того, как knockback-твин сдвинет узел), потом — визуал.
	died.emit()

	_start_death_knockback()
	_start_death_fade()


# ── internal: реакция на удар ──

## Короткий «флинч» спрайта: смещение от удара и обратно.
## Не трогает global_position узла — безопасно во время движения/атаки.
func _play_hit_shake(from_position: Vector2) -> void:
	if not animated_sprite or _is_dead:
		return

	var dir := Vector2.UP
	if from_position != Vector2.INF:
		var d := global_position - from_position
		if d.length_squared() > 0.0001:
			dir = d.normalized()

	var offset := dir * hit_shake_distance

	if _hit_shake_tween and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()

	# tween_property берёт текущее значение как старт — если удар
	# прилетел посреди прошлого шейка, интерполяция начнётся оттуда,
	# без снапа.
	_hit_shake_tween = create_tween()
	_hit_shake_tween.set_trans(Tween.TRANS_QUAD)
	_hit_shake_tween.tween_property(
		animated_sprite, "position",
		_sprite_base_position + offset,
		hit_shake_duration
	).set_ease(Tween.EASE_OUT)
	_hit_shake_tween.tween_property(
		animated_sprite, "position",
		_sprite_base_position,
		hit_shake_duration * hit_shake_return_mult
	).set_ease(Tween.EASE_IN_OUT)


## Красная вспышка спрайта при получении урона.
## Вызывается из _apply_damage — срабатывает на любой удар,
## в том числе когда персонаж занят или уже проигрывает damage.
func _flash_damage() -> void:
	if not animated_sprite or _is_dead:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", flash_color, flash_in_duration)
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, flash_out_duration)


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


## Полное затухание + queue_free. Спавнер сюда не вмешивается.
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
