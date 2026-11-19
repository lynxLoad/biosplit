class_name ChargeButton
extends SmoothBar
## Кнопка, которая заполняется через value (0..1).
## Отдаёт сигнал pressed только когда заполнена.

const AlphaHitMask = preload("res://game/gui/alpha_hit_mask.gd")

signal pressed
signal button_down
signal button_up
## Испускается, когда пользователь кликнул по незаполненной кнопке
## (только если require_full_to_press == true).
signal press_failed

@export var action_id: StringName = &""
@export var input_action: StringName = &""
@export_range(0.0, 1.0, 0.01) var ready_threshold: float = 1.0
@export var require_full_to_press: bool = true
@export var press_cooldown_sec: float = 0.15
@export_range(0.0, 120.0, 0.1) var refill_time_sec: float = 0.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var reset_animation_duration_sec: float = 0.3

@export var disabled_modulate: Color = Color(0.7, 0.7, 0.7, 1.0)
@export var enabled_modulate: Color = Color.WHITE

@export_group("Juice")
@export var color_lerp_sec: float = 0.25
@export var hover_scale: float = 1.05
@export var hover_lerp_sec: float = 0.12
@export var press_scale: float = 0.86
@export var press_hold_sec: float = 0.05
@export var press_recover_sec: float = 0.24
@export var ready_punch_scale: float = 1.14
@export var ready_punch_sec: float = 0.38
@export var fail_shake_deg: float = 3.0
@export var fail_shake_sec: float = 0.28
@export var fail_tint: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var fail_tint_sec: float = 0.22

var _cooldown_until: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _hovered: bool = false
var _was_ready: bool = false
var _in_press_anim: bool = false
var _pointer_pressed: bool = false
var _active_touch_index: int = -1
var _target_modulate: Color = Color.WHITE
var _alpha_hit_mask: BitMap

var _scale_tween: Tween
var _rot_tween: Tween
var _mod_tween: Tween
var _refill_tween: Tween

func _ready() -> void:
	#smooth_speed = 20.0
	super._ready()
	if action_id != &"":
		add_to_group(&"player_action_buttons")
	mouse_filter = Control.MOUSE_FILTER_STOP
	var mask_texture := texture_progress if texture_progress != null else texture_under
	_alpha_hit_mask = AlphaHitMask.build(mask_texture)
	if _alpha_hit_mask == null:
		push_warning("%s: не удалось создать альфа-маску для ChargeButton." % name)
	_base_scale = scale
	value_changed.connect(_on_value_changed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_update_pivot)
	_update_pivot()

	# Первичное состояние — без «punch»-анимации на старте.
	_was_ready = is_ready()
	_target_modulate = enabled_modulate if _was_ready else disabled_modulate
	modulate = _target_modulate

func _has_point(point: Vector2) -> bool:
	if _alpha_hit_mask == null:
		return Rect2(Vector2.ZERO, size).has_point(point)
	return AlphaHitMask.contains(_alpha_hit_mask, point, size)

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func snap_to(v: float) -> void:
	super.snap_to(v)
	_refresh_visual()

func smooth_to(v: float) -> void:
	if is_zero_approx(v):
		smooth_to_with_duration(v, reset_animation_duration_sec)
	else:
		super.smooth_to(v)
	_refresh_visual()

func is_ready() -> bool:
	return value >= ready_threshold

# ---------------------------------------------------------------- visuals

func _refresh_visual() -> void:
	var button_is_ready := is_ready()
	if button_is_ready != _was_ready:
		_was_ready = button_is_ready
		if button_is_ready:
			_play_ready_punch()
	_tint_to(enabled_modulate if button_is_ready else disabled_modulate)

func _tint_to(color: Color) -> void:
	if _target_modulate == color:
		return
	_target_modulate = color
	if _mod_tween:
		_mod_tween.kill()
	_mod_tween = create_tween()
	_mod_tween.tween_property(self, "modulate", color, color_lerp_sec)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_value_changed(_value: float) -> void:
	_refresh_visual()

# ---------------------------------------------------------------- tweens

func _target_scale() -> Vector2:
	return _base_scale * (hover_scale if _hovered else 1.0)

func _kill_scale_tween() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = null

func _tween_scale_to(
	target: Vector2, dur: float, trans: Tween.TransitionType, ease_type: Tween.EaseType
) -> void:
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", target, dur).set_trans(trans).set_ease(ease_type)

func _on_mouse_entered() -> void:
	_hovered = true
	if not _in_press_anim:
		_tween_scale_to(_target_scale(), hover_lerp_sec, Tween.TRANS_SINE, Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	_hovered = false
	if not _in_press_anim:
		_tween_scale_to(_target_scale(), hover_lerp_sec, Tween.TRANS_SINE, Tween.EASE_OUT)

func _play_ready_punch() -> void:
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", _target_scale() * ready_punch_scale, ready_punch_sec * 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", _target_scale(), ready_punch_sec * 0.65)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_press_feedback() -> void:
	_in_press_anim = true
	_kill_scale_tween()
	_scale_tween = create_tween()
	var down := _target_scale() * press_scale
	_scale_tween.tween_property(self, "scale", down, press_hold_sec)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", _target_scale(), press_recover_sec)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.finished.connect(_finish_press_anim)

func _finish_press_anim() -> void:
	_in_press_anim = false
	# После press-анимации аккуратно доезжаем до актуальной hover-цели,
	# даже если курсор ушёл/пришёл во время squash-а.
	_tween_scale_to(_target_scale(), 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)

func _play_fail_feedback() -> void:
	# Красная вспышка — тинт туда и обратно.
	if _mod_tween:
		_mod_tween.kill()
	_mod_tween = create_tween()
	_mod_tween.tween_property(self, "modulate", fail_tint, fail_tint_sec * 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_mod_tween.tween_property(self, "modulate", _target_modulate, fail_tint_sec * 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Вращательная тряска — безопасна внутри контейнеров
	# (position здесь трогать нельзя, layout перезапишет).
	if _rot_tween:
		_rot_tween.kill()
	var amp := deg_to_rad(fail_shake_deg)
	_rot_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_rot_tween.tween_property(self, "rotation", -amp, fail_shake_sec * 0.14)
	_rot_tween.tween_property(self, "rotation", amp, fail_shake_sec * 0.18)
	_rot_tween.tween_property(self, "rotation", -amp * 0.6, fail_shake_sec * 0.18)
	_rot_tween.tween_property(self, "rotation", amp * 0.35, fail_shake_sec * 0.18)
	_rot_tween.tween_property(self, "rotation", 0.0, fail_shake_sec * 0.32)

# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event.button_index != MOUSE_BUTTON_LEFT
			or not mouse_event.pressed
			or _pointer_pressed
		):
			return
		accept_event()
		_active_touch_index = -1
		_begin_pointer_press()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if not touch_event.pressed or _pointer_pressed:
			return
		accept_event()
		_active_touch_index = touch_event.index
		_begin_pointer_press()

func _input(event: InputEvent) -> void:
	if not _pointer_pressed:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
			return
		_finish_pointer_press(_is_inside_control(mouse_event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed or touch_event.index != _active_touch_index:
			return
		_active_touch_index = -1
		_finish_pointer_press(_is_inside_control(touch_event.position))
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _pointer_pressed:
		_active_touch_index = -1
		_finish_pointer_press(false)

func _begin_pointer_press() -> void:
	if _pointer_pressed:
		return
	_pointer_pressed = true
	button_down.emit()

func _finish_pointer_press(released_inside: bool) -> void:
	if not _pointer_pressed:
		return
	_pointer_pressed = false
	button_up.emit()
	if not released_inside:
		return

	try_activate()

func try_activate() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _cooldown_until:
		return false
	if require_full_to_press and not is_ready():
		_play_fail_feedback()
		press_failed.emit()
		return false

	_cooldown_until = now + press_cooldown_sec
	_play_press_feedback()
	_start_refill()
	pressed.emit()
	return true

func _start_refill() -> void:
	if refill_time_sec <= 0.0:
		return
	if _refill_tween and _refill_tween.is_valid():
		_refill_tween.kill()
	var reset_duration := minf(reset_animation_duration_sec, refill_time_sec)
	_refill_tween = create_tween()
	_refill_tween.tween_property(self, "value", 0.0, reset_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_refill_tween.tween_property(self, "value", 1.0, refill_time_sec - reset_duration)\
		.set_trans(Tween.TRANS_LINEAR)
	_refill_tween.tween_callback(_finish_refill)

func _finish_refill() -> void:
	_refill_tween = null
	snap_to(1.0)

func _is_inside_control(viewport_position: Vector2) -> bool:
	var local_position := get_global_transform_with_canvas().affine_inverse() * viewport_position
	if _alpha_hit_mask == null:
		return Rect2(Vector2.ZERO, size).has_point(local_position)
	return AlphaHitMask.contains(_alpha_hit_mask, local_position, size)
