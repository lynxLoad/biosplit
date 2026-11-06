class_name HitShakeService
extends RefCounted

var _sprite: AnimatedSprite2D
var _base_pos: Vector2
var _get_origin: Callable
var _is_invalid: Callable
var _tween: Tween

# config
var distance_jitter: float = 0.0
var duration_jitter: float = 0.0
var decay_jitter: float = 0.0
var custom: Dictionary = {
    "distance": 14.0, "duration": 0.3, "oscillations": 7,
    "decay": 0.65, "return_mult": 1.5
}


func setup(
    sprite: AnimatedSprite2D,
    base_pos: Vector2,
    get_origin: Callable,
    is_invalid: Callable
) -> void:
    _sprite = sprite
    _base_pos = base_pos
    _get_origin = get_origin
    _is_invalid = is_invalid


func play(from_position: Vector2, preset: int, distance_override := -1.0) -> void:
    if _sprite == null or _is_invalid.call():
        return

    var data := HitShakePresets.resolve(preset, custom)
    var distance: float = distance_override if distance_override >= 0.0 else data["distance"]
    var duration: float = data["duration"]
    var oscillations: int = maxi(1, data["oscillations"])
    var decay: float = data["decay"]
    var return_mult: float = data["return_mult"]

    if distance_jitter > 0.0:
        distance *= randf_range(1.0 - distance_jitter, 1.0 + distance_jitter)
    if duration_jitter > 0.0:
        duration *= randf_range(1.0 - duration_jitter, 1.0 + duration_jitter)
    if decay_jitter > 0.0:
        decay = clampf(decay + randf_range(-decay_jitter, decay_jitter), 0.0, 1.0)

    var dir := Vector2.UP
    if from_position != Vector2.INF:
        var delta: Vector2 = _get_origin.call() - from_position
        if delta.length_squared() > 0.0001:
            dir = delta.normalized()

    kill()
    _tween = _sprite.create_tween()
    _tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    var half_steps := oscillations * 2
    var step_duration := maxf(duration / float(half_steps + 1), 0.01)
    var amp := distance

    for i in range(half_steps):
        var target := _base_pos + dir * amp
        if i % 2 == 1:
            target = _base_pos - dir * amp
        var tweener := _tween.tween_property(_sprite, "position", target, step_duration)
        if i == 0:
            tweener.set_ease(Tween.EASE_OUT)
        amp *= decay

    _tween.tween_property(
        _sprite, "position", _base_pos, maxf(step_duration * return_mult, 0.01)
    ).set_ease(Tween.EASE_OUT)


func kill() -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
