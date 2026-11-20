extends Camera2D


## В эту группу игрок должен быть добавлен (add_to_group("player")).
const PLAYER_GROUP := &"player"

@export_group("Screen Shake")
## Общий множитель амплитуды. Поставь 0.4–0.7, если 6–32 px слишком много.
@export var shake_scale: float = 0.7
## Скорость экспоненциального затухания (1/сек). Больше = резче.
@export var shake_decay: float = 6.0
## «Частота» шума для ощущения дрожи.
@export var shake_frequency: float = 25.0

var _base_offset: Vector2
var _shake_intensity: float = 0.0
var _phase: float = 0.0
var _subscribed: Node = null


func _ready() -> void:
	_base_offset = offset
	_try_subscribe()
	# Ловим игрока, если он заспавнится позже камеры.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if is_instance_valid(_subscribed):
		return
	if node.is_node_ready():
		_try_subscribe()
	else:
		node.ready.connect(_try_subscribe, CONNECT_ONE_SHOT)


func _try_subscribe() -> void:
	if is_instance_valid(_subscribed):
		return
	var nodes := get_tree().get_nodes_in_group(PLAYER_GROUP)
	for n in nodes:
		if _subscribe(n):
			return


func _subscribe(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_signal("screen_shake_requested"):
		return false
	if not node.screen_shake_requested.is_connected(_on_screen_shake_requested):
		node.screen_shake_requested.connect(_on_screen_shake_requested)
	_subscribed = node
	return true


func _on_screen_shake_requested(intensity: float, _duration: float) -> void:
	# Не даём слабому удару «погасить» сильный, только усиливаем.
	_shake_intensity = maxf(_shake_intensity, intensity * shake_scale)


func _process(delta: float) -> void:
	if _shake_intensity <= 0.05:
		if offset != _base_offset:
			offset = _base_offset
		return

	_phase += delta * shake_frequency
	_shake_intensity = lerpf(_shake_intensity, 0.0, clampf(shake_decay * delta, 0.0, 1.0))

	# Две несинхронные синусоиды — дёргано, но без визуального «паттерна».
	var n1 := sin(_phase * 1.7) + sin(_phase * 3.1) * 0.5
	var n2 := cos(_phase * 2.3) + sin(_phase * 4.7) * 0.5
	offset = _base_offset + Vector2(n1, n2) * _shake_intensity
