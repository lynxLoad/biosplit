extends HealthBar
class_name PlayerHealthBar

## Группа, в которой находится игрок (Player сам себя туда добавляет).
@export var player_group: StringName = &"player"
## Если true — при смерти игрока бар плавно скрывается.
@export var hide_on_death: bool = false

var _player: CharacterBase

func _ready() -> void:
	super()
	_try_bind()

func _try_bind() -> void:
	if _player != null:
		return

	for n in get_tree().get_nodes_in_group(player_group):
		if n is CharacterBase and not n.is_dead():
			_player = n
			break

	if _player == null:
		# Игрока ещё нет в дереве — ждём появления.
		get_tree().node_added.connect(_on_node_added)
		return

	_connect_player()

func _on_node_added(node: Node) -> void:
	if _player != null:
		get_tree().node_added.disconnect(_on_node_added)
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
	_player.damaged.connect(_on_player_health_changed)
	_player.healed.connect(_on_player_health_changed)
	_player.died.connect(_on_player_died)
	setup(_player.get_health(), _player.get_max_health())

func _on_player_health_changed(_amount: float) -> void:
	if not is_instance_valid(_player):
		return
	update_value(_player.get_health(), _player.get_max_health())

func _on_player_died() -> void:
	if not is_instance_valid(_player):
		return

	# Обновляем значение HP без ложной анимации лечения.
	_target = _ratio(_player.get_health(), _player.get_max_health())
	_progress.smooth_to(_target)

	if _trail:
		_trail.smooth_to(_target)

	_flash(flash_color)
	_punch(punch_scale, Tween.TRANS_ELASTIC, punch_time)
	_shake()

	if hide_on_death:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
