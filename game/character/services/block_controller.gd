class_name BlockController
extends RefCounted

const BLOCK_ANIM := &"block"

var _host: Node2D
var _anim: AnimationHelper
var _flash: FlashService
var _hit_shake: HitShakeService
var _juice: CombatJuice
var _get_damage_pick: Callable
var _is_dead: Callable
 
# state
var absorbed: float = 0.0

# config
var max_absorbed: float = 0.0
var damage_reduction: float = 0.0
var lead_ratio: float = 1.0
var flash_color: Color = Color(0.4, 0.65, 1.0, 1.0)
var flash_in: float = 0.03
var flash_out: float = 0.12
var shake_distance: float = 6.0


func setup(
	host: Node2D,
	anim: AnimationHelper,
	flash: FlashService,
	hit_shake: HitShakeService,
	juice: CombatJuice,
	get_damage_pick: Callable,
	is_dead: Callable
) -> void:
	_host = host
	_anim = anim
	_flash = flash
	_hit_shake = hit_shake
	_juice = juice
	_get_damage_pick = get_damage_pick
	_is_dead = is_dead


func reset() -> void:
	absorbed = 0.0


func should_drop() -> bool:
	return max_absorbed > 0.0 and absorbed >= max_absorbed


## Полная реакция: трекинг absorbed + визуал. Возвращает просочившийся урон.
func on_hit(amount: float, from_position: Vector2, on_impact: Callable) -> float:
	var leaked := maxf(0.0, amount - maxf(0.0, damage_reduction))
	absorbed += amount - leaked
	await _play_reaction(from_position, on_impact)
	return leaked


## Только визуал (без трекинга absorbed).
func play_reaction(from_position: Vector2, on_impact: Callable) -> void:
	await _play_reaction(from_position, on_impact)


func _play_reaction(from_position: Vector2, on_impact: Callable) -> void:
	var pick: Dictionary = _get_damage_pick.call()
	var total := _anim.frame_time(pick["anim"], int(pick["frame"]))
	var lead := total * lead_ratio

	if lead > 0.0:
		await _host.get_tree().create_timer(lead).timeout
		if _is_dead.call():
			return

	_anim.play(BLOCK_ANIM)

	var rest := total - lead
	if rest > 0.0:
		await _host.get_tree().create_timer(rest).timeout
		if _is_dead.call():
			return

	on_impact.call()
	_flash.flash(flash_color, flash_in, flash_out)
	_hit_shake.play(from_position, HitShakePresets.Preset.BLOCK_HIT, shake_distance)
	_juice.play_block_recoil(from_position)
