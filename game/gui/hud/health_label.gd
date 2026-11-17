
class_name PlayerHealthLabel
extends Label

@export_group("Juice")
@export var damage_color: Color = Color(1.0, 0.25, 0.25, 1.0)
@export var heal_color: Color = Color(0.45, 1.0, 0.45, 1.0)
@export var flash_time: float = 0.12

@export var punch_scale: float = 1.25
@export var punch_time: float = 0.2

@export var shake_pixels: float = 3.0
@export var shake_time: float = 0.16

@export_group("Floating Numbers")
@export var show_damage_number: bool = true
@export var show_heal_number: bool = true
@export var floating_distance: Vector2 = Vector2(0.0, -30.0)
@export var floating_duration: float = 0.65
@export var floating_scale: float = 1.15
@export var floating_fade_delay: float = 0.2
@export var floating_random_offset: float = 0.0

@export_group("Low HP")
@export_range(0.0, 1.0, 0.01) var low_hp_threshold: float = 0.25
@export var low_hp_pulse_speed: float = 5.0
@export_range(0.0, 1.0, 0.01) var low_hp_pulse_amount: float = 0.0

var _player: CharacterBase

var _flash_tween: Tween
var _punch_tween: Tween
var _shake_tween: Tween

var _base_scale: Vector2
var _base_pos: Vector2

var _pulse_time: float = 0.0
var _shake_origin: Vector2

var player_group: StringName = &"player"
var hud_group: StringName = &"hud"

func _ready() -> void:
	_base_scale = scale
	_base_pos = position
	_try_bind()


func _try_bind() -> void:
	if _player != null:
		return

	for n in get_tree().get_nodes_in_group(player_group):
		if n is CharacterBase and not n.is_dead():
			_player = n
			break

	if _player == null:
		get_tree().node_added.connect(_on_node_added)
		return

	_connect_player()


func _on_node_added(node: Node) -> void:
	if _player != null:
		return

	if node is CharacterBase:
		node.ready.connect(_bind_if_player.bind(node), CONNECT_ONE_SHOT)


func _bind_if_player(node: CharacterBase) -> void:
	if _player != null:
		return

	if not node.is_in_group(player_group) or node.is_dead():
		return

	_player = node
	get_tree().node_added.disconnect(_on_node_added)
	_connect_player()


func _connect_player() -> void:
	_player.damaged.connect(_on_damaged)
	_player.healed.connect(_on_healed)

	_update_label()


# --- Health events ---

func _on_damaged(amount: float) -> void:
	_update_label()

	if show_damage_number:
		_spawn_floating_number(amount, "-", damage_color)

	_flash(damage_color)
	_punch(punch_scale, Tween.TRANS_ELASTIC, punch_time)
	_shake()


func _on_healed(amount: float) -> void:
	_update_label()

	if show_heal_number:
		_spawn_floating_number(amount, "+", heal_color)

	_flash(heal_color)
	_punch(
		1.0 + (punch_scale - 1.0) * 0.5,
		Tween.TRANS_BACK,
		punch_time * 0.7
	)


func _update_label() -> void:
	if not is_instance_valid(_player):
		return

	text = str(int(_player.get_health()))


# --- Floating Numbers ---

func _spawn_floating_number(
	amount: float,
	prefix: String,
	color: Color
) -> void:
	var floating := duplicate() as Label

	# Убираем скрипт и дочерние эффекты с клона.
	# Это просто визуальная копия Label.
	floating.set_script(null)
	floating.remove_theme_color_override("font_color")

	floating.text = prefix + str(int(round(amount)))
	floating.modulate = Color.WHITE
	floating.self_modulate = color
	floating.scale = _base_scale * floating_scale
	floating.pivot_offset = floating.size * 0.5

	floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating.z_index = z_index + 1

	# Добавляем в того же родителя, чтобы координаты совпадали.
	(get_tree().get_nodes_in_group(hud_group)[0] as Control).add_child(floating)

	floating.position = position + Vector2(
		size.x + floating_random_offset + 110,
		randf_range(-floating_random_offset, floating_random_offset) + 5
	)

	var start_position := floating.position
	var end_position := start_position + floating_distance

	var tween := floating.create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		floating,
		"position",
		end_position,
		floating_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		floating,
		"scale",
		_base_scale,
		floating_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		floating,
		"modulate:a",
		0.0,
		floating_duration - floating_fade_delay
	).set_delay(floating_fade_delay)

	tween.chain().tween_callback(floating.queue_free)


# --- Flash ---

func _flash(color: Color) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	self_modulate = color

	_flash_tween = create_tween()
	_flash_tween.tween_property(
		self,
		"self_modulate",
		Color.WHITE,
		flash_time
	)


# --- Punch ---

func _punch(
	to_mult: float,
	trans: Tween.TransitionType,
	duration: float
) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()

	scale = _base_scale * to_mult

	_punch_tween = create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", _base_scale, duration)


# --- Shake ---

func _shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _shake_origin

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
	if not is_instance_valid(_player):
		return

	var max_health := _player.get_max_health()
	var health_ratio := 0.0 if max_health <= 0.0 else _player.get_health() / max_health

	if health_ratio > 0.0 and health_ratio <= low_hp_threshold:
		_pulse_time += delta * low_hp_pulse_speed

		var p := sin(_pulse_time) * 0.5 + 0.5
		modulate.a = 1.0 - low_hp_pulse_amount * p

	elif _pulse_time != 0.0:
		_pulse_time = 0.0
		modulate.a = 1.0
