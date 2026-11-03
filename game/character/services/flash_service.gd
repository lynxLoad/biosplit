class_name FlashService
extends RefCounted

var _sprite: AnimatedSprite2D
var _is_invalid: Callable
var _tween: Tween


func setup(sprite: AnimatedSprite2D, is_invalid: Callable) -> void:
	_sprite = sprite
	_is_invalid = is_invalid


func flash(color: Color, in_dur: float, out_dur: float) -> void:
	if _sprite == null or _is_invalid.call():
		return
	kill()
	_tween = _sprite.create_tween()
	_tween.tween_property(_sprite, "modulate", color, in_dur)
	_tween.tween_property(_sprite, "modulate", Color.WHITE, out_dur)


func kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
