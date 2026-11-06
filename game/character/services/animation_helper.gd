class_name AnimationHelper
extends RefCounted

const WAIT_TIMEOUT := 3.0

var _host: Node
var _sprite: AnimatedSprite2D


func setup(host: Node, sprite: AnimatedSprite2D) -> void:
	_host = host
	_sprite = sprite


func has(anim: StringName) -> bool:
	return (
		_sprite != null
		and _sprite.sprite_frames != null
		and _sprite.sprite_frames.has_animation(anim)
	)


func play(anim: StringName) -> void:
	if not has(anim):
		return
	if _sprite.animation == anim and _sprite.is_playing():
		return
	_sprite.play(anim)


func frame_time(anim: StringName, frame: int) -> float:
	if not has(anim) or frame <= 0:
		return 0.0
	var speed := _sprite.sprite_frames.get_animation_speed(anim)
	if speed <= 0.0:
		return 0.0
	return float(frame) / speed


func await_end(anim: StringName, ctx: ActionContext, id: int) -> void:
	if not has(anim):
		return
	var elapsed := 0.0
	while ctx.is_current(id) and _sprite.animation == anim and _sprite.is_playing():
		await _host.get_tree().process_frame
		elapsed += _host.get_process_delta_time()
		if elapsed > WAIT_TIMEOUT:
			push_warning("Anim '%s' не завершилась за %.1fs" % [anim, WAIT_TIMEOUT])
			if is_instance_valid(_sprite):
				_sprite.stop()
			return


func await_frame(anim: StringName, frame: int, ctx: ActionContext, id: int) -> void:
	if not has(anim) or frame <= 0:
		return
	var frame_count := _sprite.sprite_frames.get_frame_count(anim)
	var target_frame := clampi(frame, 0, maxi(frame_count - 1, 0))
	var elapsed := 0.0
	while ctx.is_current(id) and _sprite.animation == anim and _sprite.is_playing():
		if _sprite.frame >= target_frame:
			return
		await _sprite.frame_changed
		elapsed += _host.get_process_delta_time()
		if elapsed > WAIT_TIMEOUT:
			push_warning("Anim '%s' не достигла кадра %d за %.1fs" % [anim, target_frame, WAIT_TIMEOUT])
			if is_instance_valid(_sprite):
				_sprite.stop()
			return

func restart(anim: StringName) -> void:
	if not has(anim):
		return
	_sprite.stop()
	_sprite.play(anim)
