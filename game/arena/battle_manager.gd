extends Node

@export var player_scene: PackedScene
@export var enemy_scene: PackedScene

@export var player_spawn: Vector2 = Vector2(320, 360)
@export var enemy_spawns: Array[Vector2] = [
	Vector2(780, 220),
	Vector2(840, 360),
	Vector2(780, 500),
]

## X точки появления из очереди (за экраном). Y берётся из последнего слота.
@export var offscreen_spawn_x: float = 950.0

## Длительность tween'а пересборки. Должна совпадать с move_to_idle_point(reflow_duration)
## — используется как таймаут ожидания, пока враги доедут.
@export var reflow_duration: float = 0.3

@export var spawn_fade_duration: float = 0.3 

## Всего врагов за волну. Первые enemy_spawns.size() — на поле, остальные в очереди.
@export var total_enemies: int = 6

@export var z_first_enemy: int = 10
@export var z_other_enemy: int = 0
@export var z_dying_first: int = 100

@onready var arena: Node2D = get_parent()

var player: Player
var enemies: Array[CharacterBase] = []
var _reflow_pending: bool = false
var _spawned_count: int = 0
var _reflow_serial: int = 0

func _ready() -> void:
	_spawn_all.call_deferred()

func _spawn_all() -> void:
	assert(player_scene != null, "BattleManager: player_scene не задан")
	assert(enemy_scene != null, "BattleManager: enemy_scene не задан")
	assert(not enemy_spawns.is_empty(), "BattleManager: enemy_spawns пуст")
	player = player_scene.instantiate() as Player
	assert(player != null, "BattleManager: player_scene должен иметь корень Player")
	arena.add_child(player)
	player.global_position = player_spawn
	player.reset_idle_point()
	player.retreat_started.connect(_on_player_retreat_started)
	var initial := mini(enemy_spawns.size(), total_enemies)
	for i in initial:
		enemies.append(_spawn_enemy_at(enemy_spawns[i], false))
	player.enemies = enemies
	_apply_z_order()

func _spawn_enemy_at(pos: Vector2, fade_in: bool) -> CharacterBase:
	var e := enemy_scene.instantiate() as CharacterBase
	assert(e != null, "BattleManager: enemy_scene должен иметь корень CharacterBase")
	arena.add_child(e)
	e.global_position = pos
	e.reset_idle_point()
	if is_instance_valid(player):
		e.set_attack_target(player)
	e.died.connect(_on_enemy_died.bind(e))
	e.turn_finished.connect(_apply_z_order)
	_spawned_count += 1
	if fade_in:
		_start_fade_in(e)
	return e

func _start_fade_in(e: CharacterBase) -> void:
	var final_alpha := e.modulate.a
	e.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(e, "modulate:a", final_alpha, spawn_fade_duration)

func _queue_spawn_point() -> Vector2:
	assert(not enemy_spawns.is_empty(), "BattleManager: enemy_spawns пуст")
	return Vector2(offscreen_spawn_x, enemy_spawns.back().y)

func _has_queued_enemy() -> bool:
	return _spawned_count < total_enemies

func _apply_z_order() -> void:
	for i in enemies.size():
		var e := enemies[i]
		if not is_instance_valid(e):
			continue
		if not e.is_attacking():
			e.set_z_priority(z_first_enemy if i == 0 else z_other_enemy)
		e.set_is_front(i == 0)

func _on_enemy_died(enemy: CharacterBase) -> void:
	var idx := enemies.find(enemy)
	if idx == -1:
		return
	if idx == 0:
		enemy.set_z_priority(z_dying_first)
	enemies.remove_at(idx)
	if _has_queued_enemy():
		var replacement := _spawn_enemy_at(_queue_spawn_point(), true)
		enemies.append(replacement)
	_apply_z_order()
	if is_instance_valid(player) and player.is_attacking():
		_reflow_pending = true
	else:
		_reflow_enemies()

func _on_player_retreat_started() -> void:
	if not _reflow_pending:
		return
	_reflow_pending = false
	_reflow_enemies()

func _reflow_enemies() -> void:
	_reflow_serial += 1
	var serial := _reflow_serial
	if is_instance_valid(player):
		player.set_attack_locked(true)
	for i in enemies.size():
		var e := enemies[i]
		if not is_instance_valid(e):
			continue
		if i >= enemy_spawns.size():
			push_warning("BattleManager: врагов больше, чем слотов (%d >= %d)" % [i, enemy_spawns.size()])
			break
		e.set_idle_point(enemy_spawns[i])
		e.move_to_idle_point(reflow_duration)
	_apply_z_order()
	await get_tree().create_timer(reflow_duration).timeout
	if serial != _reflow_serial:
		return
	if is_instance_valid(player):
		player.set_attack_locked(false)
