class_name MovementService
extends RefCounted

var _host: Node2D
var _ctx: ActionContext
var _tween: Tween


func setup(host: Node2D, ctx: ActionContext) -> void:
	_host = host
	_ctx = ctx


func move_to(
	target: Vector2,
	duration: float,
	id: int,
	trans := Tween.TRANS_QUAD,
	ease_type := Tween.EASE_IN_OUT
) -> bool:
	kill()
	_tween = _host.create_tween()
	_tween.set_trans(trans).set_ease(ease_type)
	_tween.tween_property(_host, "global_position", target, duration)
	return await _wait(id)


func _wait(id: int) -> bool:
	await _host.get_tree().process_frame
	while _ctx.is_current(id) and _tween.is_valid() and _tween.is_running():
		await _host.get_tree().process_frame
	return _ctx.is_current(id)


func kill() -> void:
	if _tween and _tween.is_valid() and _tween.is_running():
		_tween.kill()
