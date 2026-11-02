extends CharacterBase
class_name Enemy

@onready var health_bar: Bar = $HealthBar

@export var reactive_block_hold: float = 0.35
@export var reactive_block_min_hold: float = 0.15

var _reactive_block_tween: Tween
var _reactive_pending: bool = false


func _ready() -> void:
	super._ready()
	_init_bar(health_bar, health, character_stats.max_health)


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
	super._apply_damage(amount, flash)
	_sync_bar(health_bar, health, character_stats.max_health)


func _hide_ui_on_death() -> void:
	if health_bar:
		health_bar.visible = false
