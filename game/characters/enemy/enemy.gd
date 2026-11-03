extends CharacterBase
class_name Enemy

@onready var health_bar: HealthBar = $HealthBar

@export var reactive_block_hold: float = 0.35
@export var reactive_block_min_hold: float = 0.15

@export_group("Attack Energy")
## Порог, при котором враг идёт в атаку.
@export var attack_energy_threshold: float = 100.0
## Скорость накопления у «первого стоящего» врага (ед/сек).
@export var energy_rate_front: float = 33.0
## Скорость накопления у остальных (ед/сек).
@export var energy_rate_others: float = 8.0

const ENEMY_GROUP := &"enemies"

var _reactive_block_tween: Tween
var _reactive_pending: bool = false

# ── скрытая энергия атаки ──
var _attack_energy: float = randf_range(50, 65)
var _is_front: bool = false
var _attack_target: CharacterBase


func _ready() -> void:
	super()
	_init_bar(health_bar, health, character_stats.max_health)
	add_to_group(ENEMY_GROUP)


# ── энергия атаки ──

## Кого бить. Ставит BattleManager при спавне.
func set_attack_target(t: CharacterBase) -> void:
	_attack_target = t


## Флаг «первый стоящий». Ставит BattleManager из _apply_z_order.
func set_is_front(value: bool) -> void:
	_is_front = value


func get_attack_energy() -> float:
	return _attack_energy


func _process(delta: float) -> void:
	if _state == State.DEAD:
		return
	if is_busy():          # копим и бьём только из IDLE
		return
	if _attack_target == null or not is_instance_valid(_attack_target) or _attack_target.is_dead():
		return

	var rate := energy_rate_front if _is_front else energy_rate_others
	_attack_energy = minf(_attack_energy + rate * delta, attack_energy_threshold)

	if _attack_energy < attack_energy_threshold:
		return

	# Пока игрок атакует — не бьём, но заряд сохраняем.
	if _attack_target.is_attacking():
		return
	# Только один враг атакует за раз.
	if _any_enemy_attacking():
		return

	_attack_energy = 0.0
	attack(_attack_target)


func _any_enemy_attacking() -> bool:
	for other in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if other == self or not is_instance_valid(other):
			continue
		if other.is_attacking():
			return true
	return false


# ── урон / хил ──

func heal(amount: float) -> void:
	super.heal(amount)
	_sync_bar(health_bar, health, character_stats.max_health)


func take_damage(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if _state == State.DEAD:
		return

	if _state == State.BLOCKING:
		super.take_damage(amount, from_position)
		return

	if _state == State.IDLE and not _reactive_pending and randf() < character_stats.block_chance:
		_reactive_block(amount, from_position)
		return

	super.take_damage(amount, from_position)


func _reactive_block(amount: float, from_position: Vector2) -> void:
	_reactive_pending = true
	_last_hit_from = from_position

	var leaked := maxf(0.0, amount - get_block_damage_reduction())

	await play_block_reaction(amount, from_position)
	_reactive_pending = false

	if _state == State.DEAD:
		return
	if leaked > 0.0:
		_apply_damage(leaked, false)
	if _state != State.DEAD:
		_schedule_return_to_idle()


func _schedule_return_to_idle() -> void:
	_kill_tween(_reactive_block_tween)
	_reactive_block_tween = create_tween()
	_reactive_block_tween.tween_interval(maxf(reactive_block_hold, reactive_block_min_hold))
	_reactive_block_tween.tween_callback(_return_to_idle_after_block)


func _return_to_idle_after_block() -> void:
	if _state == State.IDLE and animated_sprite and animated_sprite.animation == ANIM_BLOCK:
		_play_anim(ANIM_IDLE)


func _apply_damage(amount: float, flash: bool = true) -> void:
	super(amount, flash)
	_sync_bar(health_bar, health, character_stats.max_health)


func _hide_ui_on_death() -> void:
	if health_bar:
		health_bar.visible = false
