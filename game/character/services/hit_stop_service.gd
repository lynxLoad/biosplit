class_name HitStopService
extends RefCounted

var _host: Node
var _sprite: AnimatedSprite2D
var _token: int = 0


func setup(host: Node, sprite: AnimatedSprite2D) -> void:
	_host = host
	_sprite = sprite


func play(duration: float) -> void:
	if duration <= 0.0 or _sprite == null:
		return
	_token += 1
	var token := _token
	var old_speed := _sprite.speed_scale
	_sprite.speed_scale = 0.0
	await _host.get_tree().create_timer(duration).timeout
	if token != _token or not is_instance_valid(_sprite):
		return
	_sprite.speed_scale = old_speed
