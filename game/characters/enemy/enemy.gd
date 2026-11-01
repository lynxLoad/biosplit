extends CharacterBase
class_name Enemy

@onready var health_bar: Bar = $HealthBar

@export_range(0.0, 1.0) var block_chance: float = .5
@export var reactive_block_hold: float = 0.35
## Минимальный холд — защита от случайного 0 в инспекторе.
@export var reactive_block_min_hold: float = 0.15

var _reactive_block_tween: Tween


func _ready() -> void:
	super._ready()
	_init_bar(health_bar, health, character_stats.max_health)


func heal(amount: float) -> void:
	super.heal(amount)
	_sync_bar(health_bar, health, character_stats.max_health)


func take_damage(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if _is_dead:
		return

	if is_blocking():
		super.take_damage(amount, from_position)
		return

	var roll := randf()
	if roll < block_chance:
		_reactive_block(amount, from_position)
		return

	super.take_damage(amount, from_position)


func _reactive_block(amount: float, from_position: Vector2) -> void:
	await play_block_reaction(amount, from_position)
	if _is_dead:
		return
	_schedule_return_to_idle()


func _schedule_return_to_idle() -> void:
	if _reactive_block_tween and _reactive_block_tween.is_valid():
		_reactive_block_tween.kill()
	var hold := maxf(reactive_block_hold, reactive_block_min_hold)
	_reactive_block_tween = create_tween()
	_reactive_block_tween.tween_interval(hold)
	_reactive_block_tween.tween_callback(_return_to_idle_after_block)


func _return_to_idle_after_block() -> void:
	if _is_dead:
		return
	if is_blocking():
		return
	if not animated_sprite:
		return
	if animated_sprite.animation != ANIM_BLOCK:
		# Кто-то (damage/attack/retreat) уже перебил block — не трогаем.
		return
	_play_anim(ANIM_IDLE)


func _apply_damage(amount: float) -> void:
	super._apply_damage(amount)
	_sync_bar(health_bar, health, character_stats.max_health)
