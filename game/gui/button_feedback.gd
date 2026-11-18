extends TextureButton

const AlphaHitMask = preload("res://game/gui/alpha_hit_mask.gd")

enum PressAnimationMode { ON_RELEASE, WHILE_HELD }

@export_group("Juice")
@export var hover_scale: float = 1.05
@export var hover_lerp_sec: float = 0.12
@export var press_animation_mode: PressAnimationMode = PressAnimationMode.ON_RELEASE
@export var press_scale: float = 0.86
@export var press_hold_sec: float = 0.05
@export var press_recover_sec: float = 0.24

var _base_scale: Vector2 = Vector2.ONE
var _hovered: bool = false
var _in_press_anim: bool = false
var _scale_tween: Tween

func _ready() -> void:
	_setup_click_mask()
	_base_scale = scale
	resized.connect(_update_pivot)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	match press_animation_mode:
		PressAnimationMode.WHILE_HELD:
			button_down.connect(_begin_hold_feedback)
			button_up.connect(_end_hold_feedback)
		_:
			pressed.connect(_play_press_feedback)
	_update_pivot()

func _setup_click_mask() -> void:
	if texture_click_mask != null:
		return
	var source_texture := texture_normal
	if source_texture == null:
		source_texture = texture_hover
	if source_texture == null:
		source_texture = texture_pressed
	if source_texture == null:
		source_texture = texture_disabled
	if source_texture == null:
		source_texture = texture_focused
	texture_click_mask = AlphaHitMask.build(source_texture)
	if texture_click_mask == null:
		push_warning("%s: не удалось создать альфа-маску для TextureButton." % name)

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func _target_scale() -> Vector2:
	return _base_scale * (hover_scale if _hovered else 1.0)

func _kill_scale_tween() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = null

func _tween_scale_to(
	target: Vector2, duration: float, transition: Tween.TransitionType, ease_type: Tween.EaseType
) -> void:
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", target, duration)\
		.set_trans(transition).set_ease(ease_type)

func _on_mouse_entered() -> void:
	_hovered = true
	if not _in_press_anim:
		_tween_scale_to(_target_scale(), hover_lerp_sec, Tween.TRANS_SINE, Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	_hovered = false
	if not _in_press_anim:
		_tween_scale_to(_target_scale(), hover_lerp_sec, Tween.TRANS_SINE, Tween.EASE_OUT)

func _play_press_feedback() -> void:
	_in_press_anim = true
	_kill_scale_tween()
	var down := _target_scale() * press_scale
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", down, press_hold_sec)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", _target_scale(), press_recover_sec)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.finished.connect(_finish_press_anim)

func _begin_hold_feedback() -> void:
	_in_press_anim = true
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.tween_property(
		self, "scale", _target_scale() * press_scale, press_hold_sec
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _end_hold_feedback() -> void:
	if not _in_press_anim:
		return
	_in_press_anim = false
	_tween_scale_to(_target_scale(), press_recover_sec, Tween.TRANS_BACK, Tween.EASE_OUT)

func _finish_press_anim() -> void:
	_in_press_anim = false
	_tween_scale_to(_target_scale(), 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
