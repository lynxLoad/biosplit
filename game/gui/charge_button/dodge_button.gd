class_name ChargeButton
extends SmoothBar
## Кнопка, которая заполняется через value (0..1).
## Отдаёт сигнал pressed только когда заполнена.

signal pressed

## Порог заполнения, при котором кнопка считается готовой.
@export_range(0.0, 1.0, 0.01) var ready_threshold: float = 1.0

## Если false — нажимается всегда, независимо от заполнения.
@export var require_full_to_press: bool = true

## Мини-кулдаун, чтобы клик не сработал дважды подряд, пока идёт анимация слива.
@export var press_cooldown_sec: float = 0.15

## Визуал недозаполненной кнопки (можно убрать, если не нужно).
@export var disabled_modulate: Color = Color(0.7, 0.7, 0.7, 1.0)
@export var enabled_modulate:  Color = Color.WHITE

var _cooldown_until: float = 0.0

func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_visual()

func snap_to(v: float) -> void:
	super.snap_to(v)
	_refresh_visual()

func smooth_to(v: float) -> void:
	super.smooth_to(v)
	_refresh_visual()

## Готова ли сейчас (по фактически отображаемому value).
func is_ready() -> bool:
	return value >= ready_threshold

func _refresh_visual() -> void:
	modulate = enabled_modulate if is_ready() else disabled_modulate

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	accept_event()

	var now := Time.get_ticks_msec() / 1000.0
	if now < _cooldown_until:
		return
	if require_full_to_press and not is_ready():
		return

	_cooldown_until = now + press_cooldown_sec
	pressed.emit()
