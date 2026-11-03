class_name CombatJuice
extends RefCounted

var _host: Node2D
var _sprite: AnimatedSprite2D
var _base_pos: Vector2
var _anim: AnimationHelper
var _recoil_tween: Tween

# config
var attack_anticipation_speed: float = 0.45
var attack_impact_speed: float = 2.0
var attack_anticipation_frames: int = 2
var attack_lunge_distance: float = 4.0
var attack_recoil_distance: float = 5.0
var block_recoil_distance: float = 4.0


func setup(host: Node2D, sprite: AnimatedSprite2D, base_pos: Vector2, anim: AnimationHelper) -> void:
	_host = host
	_sprite = sprite
	_base_pos = base_pos
	_anim = anim


func play_lunge(dir: Vector2) -> void:
	if _sprite == null or attack_lunge_distance <= 0.0:
		return
	kill()
	_recoil_tween = _sprite.create_tween()
	_recoil_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(
		_sprite, "position", _base_pos - dir * attack_lunge_distance, 0.06
	)
	_recoil_tween.tween_property(_sprite, "position", _base_pos, 0.08)


func play_attack_recoil(dir: Vector2) -> void:
	if _sprite == null or attack_recoil_distance <= 0.0:
		return
	_play_recoil(dir, attack_recoil_distance, 0.05, 0.10)


func play_block_recoil(from_position: Vector2) -> void:
	if _sprite == null or block_recoil_distance <= 0.0:
		return
	var dir := Vector2.UP
	if from_position != Vector2.INF:
		var delta: Vector2 = _host.global_position - from_position
		if delta.length_squared() > 0.0001:
			dir = delta.normalized()
	_play_recoil(dir, block_recoil_distance, 0.05, 0.12)


func _play_recoil(dir: Vector2, distance: float, out_dur: float, in_dur: float) -> void:
	kill()
	_recoil_tween = _sprite.create_tween()
	_recoil_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(_sprite, "position", _base_pos + dir * distance, out_dur)
	_recoil_tween.tween_property(_sprite, "position", _base_pos, in_dur)


func play_anticipation(anim: StringName, impact_frame: int, ctx: ActionContext, id: int) -> void:
	if _sprite == null or not _anim.has(anim):
		return
	if attack_anticipation_frames <= 0 or attack_anticipation_speed >= 1.0:
		return

	var frame_count := _sprite.sprite_frames.get_frame_count(anim)
	var target_frame := clampi(
		impact_frame - attack_anticipation_frames, 0, maxi(frame_count - 1, 0)
	)
	var old_speed := _sprite.speed_scale
	_sprite.speed_scale = attack_anticipation_speed

	while ctx.is_current(id) \
			and _sprite.animation == anim \
			and _sprite.is_playing() \
			and _sprite.frame < target_frame:
		await _sprite.frame_changed

	if not is_instance_valid(_sprite):
		return
	_sprite.speed_scale = old_speed


func play_impact(anim: StringName) -> void:
	if _sprite == null or attack_impact_speed <= 1.0:
		return
	var old_speed := _sprite.speed_scale
	_sprite.speed_scale = attack_impact_speed
	var impact_time := _anim.frame_time(anim, 1)
	await _sprite.get_tree().create_timer(maxf(impact_time * 0.5, 0.02)).timeout
	if is_instance_valid(_sprite):
		_sprite.speed_scale = old_speed


func kill() -> void:
	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()
