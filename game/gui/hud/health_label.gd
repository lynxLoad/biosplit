
extends Label
class_name PlayerHealthLabel

@export var player_group: StringName = &"player"

var _player: CharacterBase


func _ready() -> void:
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
	_player.damaged.connect(_update_label)
	_player.healed.connect(_update_label)

	_update_label(0.0)


func _update_label(_amount: float) -> void:
	if not is_instance_valid(_player):
		return

	text = str(int(_player.get_health()))
