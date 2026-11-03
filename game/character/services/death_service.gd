class_name DeathService
extends RefCounted

const CORPSE_GROUP := &"corpses"
const DEATH_ANIM := &"death"

var _host: Node2D
var _sprite: AnimatedSprite2D
var _base_pos: Vector2
var _anim: AnimationHelper
var _get_last_hit_from: Callable

var _corpse_landing_pos: Vector2 = Vector2.INF

# config
var arc_height: float = 8.0
var knockback_distance: float = 120.0
var knockback_speed: float = 500.0
var knockback_angle_jitter: float = 0.2
var knockback_distance_jitter: float = 0.3
var min_corpse_distance: float = 150.0
var landing_attempts: int = 40
var landing_bounds: Rect2 = Rect2()
var landing_viewport_pad: Vector2 = Vector2(60.0, 60.0)
var disappear: bool = false
var corpse_alpha: float = 1.0
var flying_z: int = 2000
var corpse_z: int = -1
var corpse_z_sort_span: int = 1500
var corpse_sort_y_range: Vector2 = Vector2.ZERO
var fade_duration: float = 0.5
var fade_delay: float = 0.0


func setup(
	host: Node2D,
	sprite: AnimatedSprite2D,
	base_pos: Vector2,
	anim: AnimationHelper,
	get_last_hit_from: Callable
) -> void:
	_host = host
	_sprite = sprite
	_base_pos = base_pos
	_anim = anim
	_get_last_hit_from = get_last_hit_from


func get_corpse_anchor() -> Vector2:
	if _corpse_landing_pos != Vector2.INF:
		return _corpse_landing_pos
	return _host.global_position


func play_death() -> void:
	var from: Vector2 = _get_last_hit_from.call()
	if from == Vector2.INF:
		from = _host.global_position + Vector2.DOWN

	var base_dir := _host.global_position - from
	if base_dir.length_squared() < 0.0001:
		base_dir = Vector2.UP
	base_dir = base_dir.normalized()

	var land := _find_corpse_landing(base_dir)
	_corpse_landing_pos = land

	_host.z_index = flying_z

	var dist := _host.global_position.distance_to(land)
	var speed := maxf(knockback_speed, 1.0)
	var fly_duration := maxf(dist / speed, 0.08)

	var knockback := _host.create_tween()
	knockback.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	knockback.tween_property(_host, "global_position", land, fly_duration)

	_play_arc(fly_duration)

	if not disappear:
		_drop_z_when_settled(knockback)

	_start_fade()


func _play_arc(fly_duration: float) -> void:
	if _sprite == null or arc_height <= 0.0:
		return
	var arc := _host.create_tween()
	arc.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc.tween_property(
		_sprite, "position", _base_pos + Vector2(0.0, -arc_height), fly_duration * 0.4
	)
	arc.tween_property(_sprite, "position", _base_pos, fly_duration * 0.6)


func _drop_z_when_settled(knockback_tween: Tween) -> void:
	if knockback_tween and knockback_tween.is_valid() and knockback_tween.is_running():
		await knockback_tween.finished
	await _await_death_last_frame()
	_host.z_index = _compute_corpse_z()


func _await_death_last_frame() -> void:
	if not _anim.has(DEATH_ANIM):
		return
	if _sprite == null or _sprite.animation != DEATH_ANIM:
		return
	var last_frame := maxi(_sprite.sprite_frames.get_frame_count(DEATH_ANIM) - 1, 0)
	if _sprite.frame >= last_frame:
		return
	var elapsed := 0.0
	while _sprite.animation == DEATH_ANIM and _sprite.is_playing():
		if _sprite.frame >= last_frame:
			return
		await _sprite.frame_changed
		elapsed += _host.get_process_delta_time()
		if elapsed > AnimationHelper.WAIT_TIMEOUT:
			return


func _find_corpse_landing(base_dir: Vector2) -> Vector2:
	var corpses := _host.get_tree().get_nodes_in_group(CORPSE_GROUP)
	var bounds := _resolve_landing_bounds()
	var best := _host.global_position + base_dir * knockback_distance
	var best_min_dist := -1.0

	for _attempt in landing_attempts:
		var angle := 0.0
		if knockback_angle_jitter > 0.0:
			angle = randf_range(-knockback_angle_jitter, knockback_angle_jitter)

		var dist := knockback_distance
		if knockback_distance_jitter > 0.0:
			dist *= randf_range(1.0 - knockback_distance_jitter, 1.0 + knockback_distance_jitter)

		var candidate := _host.global_position + base_dir.rotated(angle) * dist
		if bounds.size != Vector2.ZERO:
			candidate = _clamp_to_rect(candidate, bounds)

		var min_dist := _min_dist_to_corpses(candidate, corpses)
		if min_dist >= min_corpse_distance:
			return candidate
		if min_dist > best_min_dist:
			best_min_dist = min_dist
			best = candidate

	return best


func _min_dist_to_corpses(pos: Vector2, corpses: Array) -> float:
	var min_dist := INF
	for corpse in corpses:
		if corpse == _host or not is_instance_valid(corpse):
			continue
		var corpse_pos: Vector2 = corpse.global_position
		if corpse.has_method("get_corpse_anchor"):
			corpse_pos = corpse.get_corpse_anchor()
		min_dist = minf(min_dist, pos.distance_to(corpse_pos))
	return min_dist


func _resolve_landing_bounds() -> Rect2:
	if landing_bounds.size != Vector2.ZERO:
		return landing_bounds
	var viewport := _host.get_viewport()
	if viewport == null:
		return Rect2()
	var visible_rect := viewport.get_visible_rect()
	var pad := landing_viewport_pad
	var inner := Rect2(visible_rect.position + pad, visible_rect.size - pad * 2.0)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return Rect2()
	return inner


func _clamp_to_rect(pos: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clampf(pos.x, rect.position.x, rect.end.x),
		clampf(pos.y, rect.position.y, rect.end.y)
	)


func _compute_corpse_z() -> int:
	if corpse_z_sort_span <= 0:
		return corpse_z
	var y_range := _resolve_corpse_sort_y_range()
	if y_range.y <= y_range.x:
		return corpse_z
	var t := clampf(inverse_lerp(y_range.x, y_range.y, _corpse_landing_pos.y), 0.0, 1.0)
	var z := corpse_z - int(round((1.0 - t) * float(corpse_z_sort_span)))
	return maxi(z, -4096)


func _resolve_corpse_sort_y_range() -> Vector2:
	if corpse_sort_y_range.y > corpse_sort_y_range.x:
		return corpse_sort_y_range
	var bounds := _resolve_landing_bounds()
	if bounds.size.y > 0.0:
		return Vector2(bounds.position.y, bounds.end.y)
	return Vector2.ZERO


func _start_fade() -> void:
	if not disappear and is_equal_approx(corpse_alpha, 1.0):
		return
	var fade := _host.create_tween()
	if fade_delay > 0.0:
		fade.tween_interval(fade_delay)
	if disappear:
		fade.tween_property(_host, "modulate:a", 0.0, maxf(fade_duration, 0.01))
		fade.tween_callback(_host.queue_free)
	elif fade_duration > 0.0:
		fade.tween_property(_host, "modulate:a", corpse_alpha, fade_duration)
	else:
		_host.modulate.a = corpse_alpha
