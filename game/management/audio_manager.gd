extends Node

const SAMPLE_RATE := 22050
const PITCH_SCALE := 0.65
# Процедурная генерация здесь — временная заглушка; позже замените её готовыми звуковыми эффектами.
const SOUND_PRESETS := {
	&"attack": [0.16, 620.0, 170.0, 0.18, 0.28, 1.4, -5.0],
	&"block": [0.12, 360.0, 220.0, 0.22, 0.2, 1.1, -6.0],
	&"unblock": [0.1, 190.0, 340.0, 0.12, 0.16, 1.4, -8.0],
	&"dodge": [0.2, 900.0, 260.0, 0.52, 0.0, 1.6, -8.0],
	&"block_hit": [0.18, 1180.0, 310.0, 0.25, 0.32, 1.5, -4.0],
	&"hit": [0.16, 190.0, 68.0, 0.46, 0.16, 1.3, -7.0],
	&"heal": [0.36, 420.0, 920.0, 0.04, 0.18, 0.8, -9.0],
	&"death": [0.62, 260.0, 58.0, 0.28, 0.3, 0.9, -8.0],
}

var _stream_cache: Dictionary = {}
var _tracked_characters: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func track_character(character: CharacterBase) -> void:
	if not is_instance_valid(character):
		return
	var instance_id := character.get_instance_id()
	if _tracked_characters.has(instance_id):
		return
	_tracked_characters[instance_id] = true
	character.tree_exiting.connect(_forget_character.bind(instance_id))
	character.attack_started.connect(_on_attack_started.bind(character))
	character.block_started.connect(play_action.bind(&"block", character))
	character.block_ended.connect(play_action.bind(&"unblock", character))
	character.dodge_started.connect(play_action.bind(&"dodge", character))
	character.hit_blocked.connect(_on_blocked_hit.bind(character))
	character.damaged.connect(_on_damaged.bind(character))
	character.healed.connect(_on_healed.bind(character))
	character.died.connect(play_action.bind(&"death", character))

func play_action(action: StringName, source: Node2D = null) -> void:
	if not SOUND_PRESETS.has(action):
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = _get_stream(action)
	player.volume_db = float(SOUND_PRESETS[action][6])
	player.pitch_scale = randf_range(0.94, 1.06)
	if is_instance_valid(source) and source.is_inside_tree():
		source.add_child(player)
	else:
		add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _get_stream(action: StringName) -> AudioStreamWAV:
	if _stream_cache.has(action):
		return _stream_cache[action] as AudioStreamWAV

	var preset: Array = SOUND_PRESETS[action]
	var duration := float(preset[0])
	var start_frequency := float(preset[1])
	var end_frequency := float(preset[2])
	var noise_mix := float(preset[3])
	var harmonic := float(preset[4])
	var envelope_power := float(preset[5])
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var phase := 0.0
	for index in sample_count:
		var progress := float(index) / float(sample_count)
		var frequency := lerpf(start_frequency, end_frequency, progress) * PITCH_SCALE
		phase += TAU * frequency / SAMPLE_RATE
		var tone := sin(phase) + harmonic * sin(phase * 2.0)
		var noise := randf_range(-1.0, 1.0)
		var envelope := pow(1.0 - progress, envelope_power)
		var sample := lerpf(tone, noise, noise_mix) * envelope
		data.encode_s16(index * 2, roundi(clampf(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	_stream_cache[action] = stream
	return stream

func _on_attack_started(_ability: Ability, character: CharacterBase) -> void:
	play_action(&"attack", character)

func _on_blocked_hit(_amount: float, character: CharacterBase) -> void:
	play_action(&"block_hit", character)

func _on_damaged(_amount: float, character: CharacterBase) -> void:
	play_action(&"hit", character)

func _on_healed(_amount: float, character: CharacterBase) -> void:
	play_action(&"heal", character)

func _forget_character(instance_id: int) -> void:
	_tracked_characters.erase(instance_id)
