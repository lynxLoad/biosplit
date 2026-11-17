
class_name Mood
extends CanvasModulate

@export var enable: bool = true

@export_group("Flash Colors")
@export var damage_color: Color = Color(1.0, 0.4, 0.4)
@export var block_color: Color = Color(0.4, 0.7, 1.0)

@export_group("Flash Settings")
@export_range(0.0, 1.0, 0.01) var flash_intensity: float = 0.65
@export_range(0.01, 1.0, 0.01) var flash_duration: float = 0.05
@export_range(0.01, 2.0, 0.01) var fade_duration: float = 0.15

const PLAYER_GROUP: StringName = &"player"

var _tween: Tween
var _player: CharacterBase
var _base_color: Color


func _ready() -> void:
	if not enable: return
	_base_color = color
	_try_bind()


func _exit_tree() -> void:
	_disconnect_player()


func _try_bind() -> void:
	if _player != null:
		return

	for node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if node is CharacterBase and not node.is_dead():
			_player = node
			break

	if _player == null:
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

	if not node.is_in_group(PLAYER_GROUP) or node.is_dead():
		return

	_player = node
	get_tree().node_added.disconnect(_on_node_added)
	_connect_player()


func _connect_player() -> void:
	if _player == null:
		return

	if not _player.damaged.is_connected(_on_player_damaged):
		_player.damaged.connect(_on_player_damaged)

	if not _player.hit_blocked.is_connected(_on_player_hit_blocked):
		_player.hit_blocked.connect(_on_player_hit_blocked)


func _disconnect_player() -> void:
	if _player == null:
		return

	if _player.damaged.is_connected(_on_player_damaged):
		_player.damaged.disconnect(_on_player_damaged)

	if _player.hit_blocked.is_connected(_on_player_hit_blocked):
		_player.hit_blocked.disconnect(_on_player_hit_blocked)


# Damage flash
func _on_player_damaged(_amount: float) -> void:
	_flash(damage_color)


# Block flash
func _on_player_hit_blocked() -> void:
	_flash(block_color)


func _flash(flash_color: Color) -> void:
	# Stop previous animation.
	if _tween and _tween.is_running():
		_tween.kill()

	# Calculate flash color.
	var target_color := _base_color.lerp(
		flash_color,
		flash_intensity
	)

	# Start flash animation.
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		self,
		"color",
		target_color,
		flash_duration
	)

	# Return to original color.
	_tween.set_ease(Tween.EASE_IN_OUT)

	_tween.tween_property(
		self,
		"color",
		_base_color,
		fade_duration
	)
