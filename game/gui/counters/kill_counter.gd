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
## Базовый цвет счётчика.
@export var base_color: Color = Color.WHITE
## Цвет вспышки при обновлении счётчика.
@export var flash_color: Color = Color(1.0, 0.2, 0.2, 1.0)
## Длительность вспышки (сек).
@export var flash_time: float = 0.30
@export var fade_out_time: float = 0.30

@export_group("Milestones")
## На каких значениях слать сигнал milestone_reached.
@export var milestone_values: Array[int] = [10, 20, 25, 50, 100]

var _total_kills: int = 0
var _combo: int = 0
var _combo_time_left: float = 0.0
var _fade_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
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


# ── подключение ────────────────────────────────────────────────────────

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


# ── события ────────────────────────────────────────────────────────────

func _on_enemy_died() -> void:
	_total_kills += 1
	if use_combo:
		_combo += 1
		_combo_time_left = combo_timeout
	if debug_log:
		print("[KillCounter] enemy died → total=%d combo=%d" % [_total_kills, _combo])
	_refresh_visual()


func _on_player_damaged(_amount: float) -> void:
	if _combo > 0:
		_reset_combo()


# ── отображение ────────────────────────────────────────────────────────

func _refresh_visual() -> void:
	var value := _combo if use_combo else _total_kills
	if value < show_at_combo:
		if debug_log:
			print("[KillCounter] skip (value %d < show_at_combo %d)" % [value, show_at_combo])
		return

	_kill_tween(_fade_tween)
	_fade_tween = null
	visible = true
	modulate.a = 1.0

	kill_counter_label.text = "x%d" % value

	# простой красный флэш, гаснущий в базовый цвет
	_kill_tween(_flash_tween)
	kill_counter_label.modulate = flash_color
	kill_counter_icon.modulate = flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(kill_counter_label, "modulate", base_color, flash_time)
	_flash_tween.parallel().tween_property(kill_counter_icon, "modulate", base_color, flash_time)

	if value in milestone_values:
		milestone_reached.emit(value)
		if debug_log:
			print("[KillCounter] MILESTONE reached: x%d" % value)


func _reset_combo() -> void:
	if not use_combo:
		return
	_combo = 0
	_combo_time_left = 0.0
	_kill_tween(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_out_time)
	_fade_tween.tween_callback(func(): visible = false)


func _kill_tween(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()


# ── API ────────────────────────────────────────────────────────────────

func get_total_kills() -> int: return _total_kills
func get_combo() -> int: return _combo
func register_enemy(e: Node) -> void: _hook_enemy(e)

func reset() -> void:
	_total_kills = 0
	_reset_combo()
	_kill_tween(_fade_tween)
	_kill_tween(_flash_tween)
	visible = false
	modulate.a = 0.0
