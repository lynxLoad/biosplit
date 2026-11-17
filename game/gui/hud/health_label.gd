
class_name PlayerHealthLabel
extends Label


# ============================================================
# JUICE
# ============================================================

@export_group("Juice")

@export var damage_color: Color = Color(1.0, 0.25, 0.25, 1.0)
@export var heal_color: Color = Color(0.45, 1.0, 0.45, 1.0)

@export var flash_time: float = 0.12

@export var punch_scale: float = 1.25
@export var punch_time: float = 0.2

@export var shake_pixels: float = 3.0
@export var shake_time: float = 0.16


# ============================================================
# FLOATING NUMBERS
# ============================================================

@export_group("Floating Numbers")

@export var show_damage_number: bool = true
@export var show_heal_number: bool = true

@export var floating_distance: Vector2 = Vector2(0.0, -45.0)
@export var floating_duration: float = 0.75

@export var floating_scale: float = 1.15
@export var floating_start_scale: float = 0.35
@export var floating_peak_scale: float = 1.65

@export var floating_pop_time: float = 0.12
@export var floating_fade_delay: float = 0.25

@export var floating_random_offset: float = 15.0
@export var floating_horizontal_spread: float = 35.0

@export var floating_rotation: float = 12.0


# ============================================================
# FLOATING NUMBER OUTLINE
# ============================================================

@export_group("Floating Number Outline")

@export var floating_outline_size: int = 5

@export var damage_outline_color: Color = Color(0.15, 0.015, 0.015, 1.0)
@export var heal_outline_color: Color = Color(0.02, 0.15, 0.04, 1.0)


# ============================================================
# FLOATING NUMBER FLASH
# ============================================================

@export_group("Floating Number Flash")

@export var floating_flash_strength: float = 1.5
@export var floating_flash_time: float = 0.12


# ============================================================
# LOW HP
# ============================================================

@export_group("Low HP")

@export_range(0.0, 1.0, 0.01)
var low_hp_threshold: float = 0.25

@export var low_hp_pulse_speed: float = 5.0

@export_range(0.0, 1.0, 0.01)
var low_hp_pulse_amount: float = 0.0


# ============================================================
# REFERENCES
# ============================================================

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


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_base_scale = scale
	_base_pos = position

	_try_bind()


# ============================================================
# PLAYER BINDING
# ============================================================

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
		node.ready.connect(
			_bind_if_player.bind(node),
			CONNECT_ONE_SHOT
		)


func _bind_if_player(node: CharacterBase) -> void:
	if _player != null:
		return

	if not node.is_in_group(player_group) or node.is_dead():
		return

	_player = node

	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

	_connect_player()


func _connect_player() -> void:
	if not _player.damaged.is_connected(_on_damaged):
		_player.damaged.connect(_on_damaged)

	if not _player.healed.is_connected(_on_healed):
		_player.healed.connect(_on_healed)

	_update_label()


# ============================================================
# HEALTH EVENTS
# ============================================================

func _on_damaged(amount: float) -> void:
	_update_label()

	if show_damage_number:
		_spawn_floating_number(
			amount,
			"-",
			damage_color,
			damage_outline_color
		)

	_flash(damage_color)

	_punch(
		punch_scale,
		Tween.TRANS_ELASTIC,
		punch_time
	)

	_shake()


func _on_healed(amount: float) -> void:
	_update_label()

	if show_heal_number:
		_spawn_floating_number(
			amount,
			"+",
			heal_color,
			heal_outline_color
		)

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


# ============================================================
# FLOATING NUMBERS
# ============================================================

func _spawn_floating_number(
	amount: float,
	prefix: String,
	color: Color,
	outline_color: Color
) -> void:

	# Create visual copy.
	var floating := duplicate() as Label

	floating.set_script(null)

	floating.text = prefix + str(int(round(amount)))

	floating.modulate = Color.WHITE
	floating.self_modulate = color

	floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating.z_index = z_index + 1

	# Outline.
	floating.add_theme_color_override(
		"font_outline_color",
		outline_color
	)

	floating.add_theme_constant_override(
		"outline_size",
		floating_outline_size
	)

	# Add to HUD.
	var hud_nodes := get_tree().get_nodes_in_group(hud_group)

	if hud_nodes.is_empty():
		floating.queue_free()
		return

	var hud := hud_nodes[0] as Control

	if hud == null:
		floating.queue_free()
		return

	hud.add_child(floating)

	# Position.
	var random_x := randf_range(
		-floating_horizontal_spread,
		floating_horizontal_spread
	)

	var random_y := randf_range(
		-floating_random_offset,
		floating_random_offset
	)

	floating.position = position + Vector2(
		size.x + 120.0 + random_x,
		random_y + 13.0
	)

	# Center pivot.
	floating.pivot_offset = floating.size * 0.5

	var start_position := floating.position

	var end_position := start_position + floating_distance

	# Random rotation.
	var rotation_direction := -1.0 if randf() < 0.5 else 1.0

	floating.rotation_degrees = (
		rotation_direction * floating_rotation
	)

	# Initial scale.
	floating.scale = _base_scale * floating_start_scale

	# Initial flash.
	floating.modulate = Color(
		floating_flash_strength,
		floating_flash_strength,
		floating_flash_strength,
		1.0
	)

	# Main animation.
	var tween := floating.create_tween()

	tween.set_parallel(true)

	# POP SCALE.
	tween.tween_property(
		floating,
		"scale",
		_base_scale * floating_peak_scale,
		floating_pop_time
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	# ROTATION.
	tween.tween_property(
		floating,
		"rotation_degrees",
		0.0,
		floating_pop_time
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	# FLASH.
	tween.tween_property(
		floating,
		"modulate",
		Color.WHITE,
		floating_flash_time
	)

	# FLOAT AND FADE.
	tween.chain().set_parallel(true)

	tween.tween_property(
		floating,
		"position",
		end_position,
		floating_duration
	).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(
		Tween.EASE_OUT
	)

	# Scale settles after pop.
	tween.tween_property(
		floating,
		"scale",
		_base_scale * floating_scale,
		floating_duration
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	# Fade out.
	var fade_duration := maxf(
		0.01,
		floating_duration - floating_fade_delay
	)

	tween.tween_property(
		floating,
		"modulate:a",
		0.0,
		fade_duration
	).set_delay(
		floating_fade_delay
	)

	# Destroy after animation.
	tween.chain().tween_callback(
		floating.queue_free
	)


# ============================================================
# FLASH
# ============================================================

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


# ============================================================
# PUNCH
# ============================================================

func _punch(
	to_mult: float,
	trans: Tween.TransitionType,
	duration: float
) -> void:

	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()

	scale = _base_scale * to_mult

	_punch_tween = create_tween()

	_punch_tween.set_trans(trans)
	_punch_tween.set_ease(Tween.EASE_OUT)

	_punch_tween.tween_property(
		self,
		"scale",
		_base_scale,
		duration
	)


# ============================================================
# SHAKE
# ============================================================

func _shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

		position = _shake_origin

	_shake_origin = position

	_shake_tween = create_tween()

	_shake_tween.set_trans(Tween.TRANS_SINE)

	var steps := 5

	for i in range(steps):
		var strength := shake_pixels * (
			1.0 - float(i) / steps
		)

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


# ============================================================
# LOW HP PULSE
# ============================================================

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var max_health := _player.get_max_health()

	var health_ratio := (
		0.0 if max_health <= 0.0
		else _player.get_health() / max_health
	)

	if health_ratio > 0.0 and health_ratio <= low_hp_threshold:

		_pulse_time += delta * low_hp_pulse_speed

		var pulse := sin(_pulse_time) * 0.5 + 0.5

		modulate.a = 1.0 - low_hp_pulse_amount * pulse

	elif _pulse_time != 0.0:

		_pulse_time = 0.0
		modulate.a = 1.0
