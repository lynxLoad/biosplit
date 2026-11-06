class_name HitStopService
extends RefCounted

var _host: Node
var _active: int = 0
var _saved_time_scale: float = 1.0


func setup(host: Node) -> void:
	_host = host


func play(duration: float) -> void:
	if duration <= 0.0 or _host == null:
		return

	_active += 1
	if _active == 1:
		_saved_time_scale = Engine.time_scale
		Engine.time_scale = .1

	await _host.get_tree().create_timer(duration, true, false, true).timeout

	_active -= 1
	if _active == 0:
		Engine.time_scale = _saved_time_scale
