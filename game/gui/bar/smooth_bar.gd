class_name SmoothBar
extends TextureProgressBar
## Только плавное изменение value. Ничего не знает про HP, trail, flash и т.д.

## Больше = резче (короче анимация). ~25 → ~0.12 с, ~5 → ~0.6 с.
@export_range(1.0, 40.0, 0.5) var smooth_speed: float = 25.0

var _target: float = 0.0
var _tween: Tween

func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.0
	value = clampf(value, 0.0, 1.0)
	_target = value

## Мгновенно, без анимации.
func snap_to(v: float) -> void:
	_target = clampf(v, min_value, max_value)
	_kill_tween()
	value = _target

## Плавно доехать.
func smooth_to(v: float) -> void:
	smooth_to_with_duration(v, maxf(0.05, 3.0 / smooth_speed))

func smooth_to_with_duration(v: float, duration: float) -> void:
	_target = clampf(v, min_value, max_value)
	_kill_tween()
	if is_equal_approx(value, _target):
		return
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "value", _target, maxf(0.05, duration))

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
