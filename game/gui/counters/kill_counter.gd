
extends HBoxContainer
class_name KillCounter

signal milestone_reached(value: int)

@onready var kill_counter_icon: TextureRect = $KillCounterIcon
@onready var kill_counter_label: Label = $KillCounterLabel


@export_group("Debug")
@export var debug_log: bool = false


@export_group("Combo")
@export var use_combo: bool = false
@export var combo_timeout: float = 3.0
@export var show_at_combo: int = 1
@export var reset_on_player_damage: bool = true


@export_group("Juice")
@export var base_color: Color = Color.WHITE
@export var flash_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var flash_time: float = 0.15

@export var punch_scale: float = 1.2
@export var punch_time: float = 0.25

@export var icon_bounce_distance: float = 5.0
@export var icon_bounce_time: float = 0.25


@export_group("Combo Juice")
@export var combo_punch_bonus: float = 0.025
@export var max_combo_punch_bonus: float = 0.18


@export_group("Milestones")
@export var milestone_values: Array[int] = [10, 20, 25, 50, 100]
@export var milestone_color: Color = Color(1.0, 0.75, 0.2, 1.0)
@export var milestone_punch: float = 1.4
@export var milestone_flash_time: float = 0.3


@export_group("Visibility")
@export var fade_out_time: float = 0.3


var _total_kills: int = 0
var _combo: int = 0
var _combo_time_left: float = 0.0

var _fade_tween: Tween
var _flash_tween: Tween
var _punch_tween: Tween
var _icon_tween: Tween

var _base_icon_offset: Vector2
var _base_label_offset_scale: Vector2


func _ready() -> void:
	_base_icon_offset = kill_counter_icon.offset_transform_position
	_base_label_offset_scale = kill_counter_label.offset_transform_scale

	modulate.a = 0.0
	visible = false

	kill_counter_label.modulate = base_color
	kill_counter_icon.modulate = base_color

	_hook_existing_enemies()
	get_tree().node_added.connect(_on_node_added)

	if reset_on_player_damage:
		var p := get_tree().get_first_node_in_group(&"player")
		if p:
			_hook_player(p)


func _process(delta: float) -> void:
	if _combo <= 0:
		return

	_combo_time_left -= delta

	if _combo_time_left <= 0.0:
		_reset_combo()


# ── Connections ──────────────────────────────────────────────

func _hook_existing_enemies() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		_hook_enemy(e)


func _on_node_added(node: Node) -> void:
	if node is Enemy:
		call_deferred("_hook_enemy", node)
	elif reset_on_player_damage:
		call_deferred("_try_hook_player", node)


func _try_hook_player(node: Node) -> void:
	if is_instance_valid(node) and node.is_in_group(&"player"):
		_hook_player(node)


func _hook_enemy(e: Node) -> void:
	if not is_instance_valid(e):
		return

	if not e.died.is_connected(_on_enemy_died):
		e.died.connect(_on_enemy_died)

		if debug_log:
			print("[KillCounter] hooked enemy: ", e.name)


func _hook_player(p: Node) -> void:
	if p and p.has_signal("damaged") and not p.damaged.is_connected(_on_player_damaged):
		p.damaged.connect(_on_player_damaged)


# ── Events ───────────────────────────────────────────────────

func _on_enemy_died() -> void:
	_total_kills += 1

	if use_combo:
		_combo += 1
		_combo_time_left = combo_timeout

	if debug_log:
		print(
			"[KillCounter] enemy died → total=%d combo=%d"
			% [_total_kills, _combo]
		)

	_refresh_visual()


func _on_player_damaged(_amount: float) -> void:
	if _combo > 0:
		_reset_combo()


# ── Visual ───────────────────────────────────────────────────

func _refresh_visual() -> void:
	var value := _combo if use_combo else _total_kills

	if value < show_at_combo:
		return

	_kill_tween(_fade_tween)
	_fade_tween = null

	visible = true
	modulate.a = 1.0

	kill_counter_label.text = "x%d" % value

	var is_milestone := value in milestone_values

	# Flash
	_flash(
		milestone_color if is_milestone else flash_color,
		milestone_flash_time if is_milestone else flash_time
	)

	# Combo punch bonus
	var combo_bonus := 0.0

	if use_combo:
		combo_bonus = minf(
			_combo * combo_punch_bonus,
			max_combo_punch_bonus
		)

	# Punch
	_punch(
		milestone_punch if is_milestone else punch_scale + combo_bonus,
		0.35 if is_milestone else punch_time
	)

	# Icon bounce
	_bounce_icon()

	# Milestone
	if is_milestone:
		milestone_reached.emit(value)

		if debug_log:
			print("[KillCounter] MILESTONE reached: x%d" % value)


# ── Flash ────────────────────────────────────────────────────

func _flash(color: Color, duration: float) -> void:
	_kill_tween(_flash_tween)

	kill_counter_label.modulate = color
	kill_counter_icon.modulate = color

	_flash_tween = create_tween()

	_flash_tween.tween_property(
		kill_counter_label,
		"modulate",
		base_color,
		duration
	)

	_flash_tween.parallel().tween_property(
		kill_counter_icon,
		"modulate",
		base_color,
		duration
	)


# ── Punch ────────────────────────────────────────────────────

func _punch(multiplier: float, duration: float) -> void:
	_kill_tween(_punch_tween)

	kill_counter_label.offset_transform_scale = _base_label_offset_scale

	_punch_tween = create_tween()

	_punch_tween.tween_property(
		kill_counter_label,
		"offset_transform_scale",
		_base_label_offset_scale * multiplier,
		duration * 0.25
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_punch_tween.tween_property(
		kill_counter_label,
		"offset_transform_scale",
		_base_label_offset_scale,
		duration * 0.75
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ── Icon Bounce ─────────────────────────────────────────────

func _bounce_icon() -> void:
	_kill_tween(_icon_tween)

	kill_counter_icon.offset_transform_position = _base_icon_offset

	_icon_tween = create_tween()

	_icon_tween.tween_property(
		kill_counter_icon,
		"offset_transform_position",
		_base_icon_offset + Vector2(0.0, icon_bounce_distance),
		icon_bounce_time * 0.35
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_icon_tween.tween_property(
		kill_counter_icon,
		"offset_transform_position",
		_base_icon_offset,
		icon_bounce_time * 0.65
	)


# ── Combo Reset ─────────────────────────────────────────────

func _reset_combo() -> void:
	if not use_combo:
		return

	_combo = 0
	_combo_time_left = 0.0

	_kill_tween(_fade_tween)

	_fade_tween = create_tween()

	_fade_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_out_time
	)

	_fade_tween.tween_callback(func():
		visible = false
	)


# ── Utils ────────────────────────────────────────────────────

func _kill_tween(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()


# ── API ──────────────────────────────────────────────────────

func get_total_kills() -> int:
	return _total_kills


func get_combo() -> int:
	return _combo


func register_enemy(e: Node) -> void:
	_hook_enemy(e)


func reset() -> void:
	_total_kills = 0
	_combo = 0
	_combo_time_left = 0.0

	_kill_tween(_fade_tween)
	_kill_tween(_flash_tween)
	_kill_tween(_punch_tween)
	_kill_tween(_icon_tween)

	_fade_tween = null
	_flash_tween = null
	_punch_tween = null
	_icon_tween = null

	kill_counter_icon.offset_transform_position = _base_icon_offset
	kill_counter_label.offset_transform_scale = _base_label_offset_scale

	kill_counter_label.text = "x0"
	kill_counter_label.modulate = base_color
	kill_counter_icon.modulate = base_color

	modulate.a = 0.0
	visible = false
