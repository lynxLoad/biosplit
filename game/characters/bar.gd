extends TextureProgressBar
class_name Bar

## Больше = резче (короче анимация). ~25 → ~0.12 с, ~5 → ~0.6 с.
@export_range(1.0, 40.0, 0.5) var smooth_speed: float = 25.0

var _target: float = 1.0
var _tween: Tween

func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.0          # без step снапа — value хранится как дробное

## Вызывать при спавне — бар сразу на нужном значении, без анимации.
func setup(current: float, maximum: float) -> void:
	_kill_tween()
	_target = _ratio(current, maximum)
	value = _target

## Вызывать при изменении HP — бар сам плавно доедет.
func update_value(current: float, maximum: float) -> void:
	_target = _ratio(current, maximum)

	_kill_tween()
	if is_equal_approx(value, _target):
		return

	# 3/smooth_speed ≈ время до ~95% — та же «резкость», что была у экспоненты.
	var duration := maxf(0.05, 3.0 / smooth_speed)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "value", _target, duration)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

func _ratio(current: float, maximum: float) -> float:
	return 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
