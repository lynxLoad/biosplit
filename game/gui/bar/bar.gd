extends Control
class_name HealthBar

## Больше = резче (короче анимация). ~25 → ~0.12 с, ~5 → ~0.6 с.
@export_range(1.0, 40.0, 0.5) var smooth_speed: float = 25.0

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

@onready var _progress: TextureProgressBar = $TextureProgressBar
@onready var _under: TextureRect = $Under

var _target: float = 1.0
var _tween: Tween
var _flash_tween: Tween
var _punch_tween: Tween
var _shake_tween: Tween
var _trail_tween: Tween
var _trail: TextureProgressBar
var _base_scale: Vector2
var _base_pos: Vector2
var _base_size: Vector2
var _pulse_time: float = 0.0


func _ready() -> void:
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.step = 0.0
	_progress.value = clampf(_progress.value, 0.0, 1.0)
	_target = _progress.value
	_base_scale = scale
	_base_pos = position
	_base_size = size
	if show_trail:
		_create_trail()


## Trail-бар — копия основного с красным tint_progress.
## Вставляем в дерево СРАЗУ после Under — рисуется над фоном, под основным.
func _create_trail() -> void:
	_trail = _progress.duplicate() as TextureProgressBar
	_trail.tint_progress = trail_color
	_trail.min_value = 0.0
	_trail.max_value = 1.0
	_trail.step = 0.0
	_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_trail)
	move_child(_trail, _under.get_index() + 1)


## Вызывать при спавне (в т.ч. при респавне из пула) — бар сразу
## на нужном значении, без анимации.
func setup(current: float, maximum: float) -> void:
	_kill_all_tweens()
	_target = _ratio(current, maximum)
	_progress.value = _target
	if _trail:
		_trail.value = _target
	scale = _base_scale
	position = _base_pos
	size = _base_size
	modulate.a = 1.0
	_progress.self_modulate = Color.WHITE
	_pulse_time = 0.0
	_apply_bar_alpha(1.0)


## Вызывать при изменении HP — бар сам плавно доедет.
func update_value(current: float, maximum: float) -> void:
	var new_target := _ratio(current, maximum)
	var is_damage := new_target < _target - 0.0001
	_target = new_target

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	if not is_equal_approx(_progress.value, _target):
		_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_progress, "value", _target, maxf(0.05, 3.0 / smooth_speed))

	if _trail:
		_animate_trail(is_damage)

	if is_damage:
		_flash(flash_color)
		_punch(punch_scale, Tween.TRANS_ELASTIC, punch_time)
		_shake()
	else:
		_flash(heal_color)
		_punch(1.0 + (punch_scale - 1.0) * 0.5, Tween.TRANS_BACK, punch_time * 0.7)


# --- Trail (полоса урона) ---

func _animate_trail(is_damage: bool) -> void:
	if _trail_tween and _trail_tween.is_valid():
		_trail_tween.kill()
	_trail_tween = null
	if not is_damage:
		_trail.value = _target
		return
	_trail_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_trail_tween.tween_property(_trail, "value", _target, maxf(0.1, 3.0 / trail_speed))


# --- Flash (только на баре, чтобы не задевать лейблы) ---

func _flash(color: Color) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_progress.self_modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_progress, "self_modulate", Color.WHITE, flash_time)


# --- Punch (масштаб всего бара — включая лейблы, так сочнее) ---

func _punch(to_mult: float, trans: Tween.TransitionType, duration: float) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	scale = _base_scale * to_mult
	_punch_tween = create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", _base_scale, duration)


# --- Shake ---

func _shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween().set_trans(Tween.TRANS_SINE)
	var steps := 5
	for i in steps:
		var strength := shake_pixels * (1.0 - float(i) / steps)
		_shake_tween.tween_property(self, "position", _base_pos + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength * 0.4, strength * 0.4)
		), shake_time / steps)
	_shake_tween.tween_property(self, "position", _base_pos, shake_time / steps)


# --- Low HP pulse (только полосы + фон, лейблы не мигают) ---

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

func _kill_all_tweens() -> void:
	for t: Tween in [_tween, _flash_tween, _punch_tween, _shake_tween, _trail_tween]:
		if t and t.is_valid():
			t.kill()
	_tween = null
	_flash_tween = null
	_punch_tween = null
	_shake_tween = null
	_trail_tween = null


func _ratio(current: float, maximum: float) -> float:
	return 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
