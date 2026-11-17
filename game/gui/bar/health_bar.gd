extends Control
class_name HealthBar

@export_group("Juice")
@export var show_trail: bool = true
@export var trail_color: Color = Color(1.0, 0.35, 0.35, 0.85)
@export_range(1.0, 20.0, 0.5) var trail_speed: float = 4.0
@export var flash_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var heal_color: Color = Color(0.45, 1.0, 0.45, 1.0)
@export var flash_time: float = 0.12
@export var punch_scale: float = 1.12
@export var punch_time: float = 0.2
@export var shake_pixels: float = 4.0
@export var shake_time: float = 0.2
@export var low_hp_threshold: float = 0.25
@export var low_hp_pulse_speed: float = 5.0
@export var low_hp_pulse_amount: float = 0.18

@onready var _progress: SmoothBar = $Progress
@onready var _under: TextureRect = $Under

var _target: float = 1.0
var _flash_tween: Tween
var _punch_tween: Tween
var _shake_tween: Tween
var _trail: SmoothBar
var _base_scale: Vector2
var _base_pos: Vector2
var _base_size: Vector2
var _pulse_time: float = 0.0
var _shake_origin: Vector2

func _ready() -> void:
	_target = _progress.value
	_base_scale = scale
	_base_pos = position
	_base_size = size
	if show_trail:
		_create_trail()

## Trail — копия _progress, но с медленным smooth_speed и красным тинтом.
## Вставляем СРАЗУ после Under → рисуется над фоном, под основным баром.
func _create_trail() -> void:
	_trail = _progress.duplicate() as SmoothBar
	_trail.smooth_speed = trail_speed
	_trail.tint_progress = trail_color
	_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_trail)
	move_child(_trail, _under.get_index() + 1)

## Спавн / респавн из пула — мгновенно на нужном значении.
func setup(current: float, maximum: float) -> void:
	_kill_juice_tweens()
	_target = _ratio(current, maximum)
	_progress.snap_to(_target)
	if _trail:
		_trail.snap_to(_target)
	scale = _base_scale
	#position = _base_pos
	#size = _base_size
	modulate.a = 1.0
	_progress.self_modulate = Color.WHITE
	_pulse_time = 0.0
	_apply_bar_alpha(1.0)

## Изменение HP — бар сам плавно доедет, плюс juice.
func update_value(current: float, maximum: float) -> void:
	var new_target := _ratio(current, maximum)
	var is_damage := new_target < _target - 0.0001
	_target = new_target

	_progress.smooth_to(_target)

	if _trail:
		if is_damage:
			_trail.smooth_to(_target)   # trail отстаёт
		else:
			_trail.snap_to(_target)     # на хиле сразу подтягиваем

	if is_damage:
		_flash(flash_color)
		_punch(punch_scale, Tween.TRANS_ELASTIC, punch_time)
		_shake()
	else:
		_flash(heal_color)
		_punch(1.0 + (punch_scale - 1.0) * 0.5, Tween.TRANS_BACK, punch_time * 0.7)


# --- Flash ---

func _flash(color: Color) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_progress.self_modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_progress, "self_modulate", Color.WHITE, flash_time)

# --- Punch ---

func _punch(to_mult: float, trans: Tween.TransitionType, duration: float) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	scale = _base_scale * to_mult
	_punch_tween = create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", _base_scale, duration)

# --- Shake ---

func _shake() -> void:
	# Если предыдущая тряска ещё идёт — возвращаем исходную позицию.
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _shake_origin

	# Запоминаем актуальную позицию прямо перед тряской.
	_shake_origin = position

	_shake_tween = create_tween().set_trans(Tween.TRANS_SINE)

	var steps := 5

	for i in steps:
		var strength := shake_pixels * (1.0 - float(i) / steps)

		_shake_tween.tween_property(
			self,
			"position",
			_shake_origin + Vector2(
				randf_range(-strength, strength),
				randf_range(-strength * 0.4, strength * 0.4)
			),
			shake_time / steps
		)

		_shake_tween.tween_property(
			self,
			"position",
			_shake_origin,
			shake_time / steps
		)

# --- Low HP pulse ---

func _process(delta: float) -> void:
	if _target > 0.0 and _target <= low_hp_threshold:
		_pulse_time += delta * low_hp_pulse_speed
		var p := sin(_pulse_time) * 0.5 + 0.5
		_apply_bar_alpha(1.0 - low_hp_pulse_amount * p)
	elif _pulse_time != 0.0:
		_pulse_time = 0.0
		_apply_bar_alpha(1.0)

func _apply_bar_alpha(a: float) -> void:
	_under.modulate.a = a
	_progress.modulate.a = a
	if _trail:
		_trail.modulate.a = a

# --- Utils ---

func _kill_juice_tweens() -> void:
	for t: Tween in [_flash_tween, _punch_tween, _shake_tween]:
		if t and t.is_valid():
			t.kill()
	_flash_tween = null
	_punch_tween = null
	_shake_tween = null

func _ratio(current: float, maximum: float) -> float:
	return 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
