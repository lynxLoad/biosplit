#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Точечный генератор: добавляет глобальный hitstop на блок (только игроку).

Трогает ТОЛЬКО:
    game/character/services/block_controller.gd
    game/character/nodes/player/player.gd

Character / Enemy / остальные сервисы не изменяются.

    python generate_hitstop.py                 # записать
    python generate_hitstop.py --dry-run       # показать план
    python generate_hitstop.py --no-overwrite  # пропустить существующие
    python generate_hitstop.py --root .        # явный корень проекта
"""

import argparse
import sys
from pathlib import Path

FILES: dict[str, str] = {}

# ─────────────────────────────────────────────────────────────────────────────
# game/character/services/block_controller.gd
# ─────────────────────────────────────────────────────────────────────────────

FILES["game/character/services/block_controller.gd"] = r"""class_name BlockController
extends RefCounted

const BLOCK_ANIM := &"block"

var _host: Node2D
var _anim: AnimationHelper
var _flash: FlashService
var _hit_shake: HitShakeService
var _juice: CombatJuice
var _get_damage_pick: Callable
var _is_dead: Callable

# state
var absorbed: float = 0.0
var hitstop_duration: float = 0.0
var _hitstop_active: bool = false

# config
var max_absorbed: float = 0.0
var damage_reduction: float = 0.0
var lead_ratio: float = 1.0
var flash_color: Color = Color(0.4, 0.65, 1.0, 1.0)
var flash_in: float = 0.03
var flash_out: float = 0.12
var shake_distance: float = 6.0


func setup(
	host: Node2D,
	anim: AnimationHelper,
	flash: FlashService,
	hit_shake: HitShakeService,
	juice: CombatJuice,
	get_damage_pick: Callable,
	is_dead: Callable
) -> void:
	_host = host
	_anim = anim
	_flash = flash
	_hit_shake = hit_shake
	_juice = juice
	_get_damage_pick = get_damage_pick
	_is_dead = is_dead


func reset() -> void:
	absorbed = 0.0


func should_drop() -> bool:
	return max_absorbed > 0.0 and absorbed >= max_absorbed


## Полная реакция: трекинг absorbed + визуал. Возвращает просочившийся урон.
func on_hit(amount: float, from_position: Vector2, on_impact: Callable) -> float:
	var leaked := maxf(0.0, amount - maxf(0.0, damage_reduction))
	absorbed += amount - leaked
	await _play_reaction(from_position, on_impact)
	return leaked


## Только визуал (без трекинга absorbed).
func play_reaction(from_position: Vector2, on_impact: Callable) -> void:
	await _play_reaction(from_position, on_impact)


func _play_reaction(from_position: Vector2, on_impact: Callable) -> void:
	var pick: Dictionary = _get_damage_pick.call()
	var total := _anim.frame_time(pick["anim"], int(pick["frame"]))
	var lead := total * lead_ratio

	if lead > 0.0:
		await _host.get_tree().create_timer(lead).timeout
		if _is_dead.call():
			return

	_anim.play(BLOCK_ANIM)

	var rest := total - lead
	if rest > 0.0:
		await _host.get_tree().create_timer(rest).timeout
		if _is_dead.call():
			return

	on_impact.call()
	_flash.flash(flash_color, flash_in, flash_out)
	_hit_shake.play(from_position, HitShakePresets.Preset.BLOCK_HIT, shake_distance)
	_juice.play_block_recoil(from_position)

	if hitstop_duration > 0.0:
		await _do_hitstop(hitstop_duration)


func _do_hitstop(duration: float) -> void:
	if duration <= 0.0 or _host == null or _hitstop_active:
		return
	_hitstop_active = true
	var old := Engine.time_scale
	Engine.time_scale = 0.0
	# 4-й аргумент = ignore_time_scale, иначе таймер сам себя остановит.
	await _host.get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = old
	_hitstop_active = false
"""

# ─────────────────────────────────────────────────────────────────────────────
# game/character/nodes/player/player.gd
# ─────────────────────────────────────────────────────────────────────────────

FILES["game/character/nodes/player/player.gd"] = r"""extends Character
class_name Player

signal screen_shake_requested(intensity: float, duration: float)

const PLAYER_GROUP := &"player"

@export_group("Block Feedback")
## Глобальный freeze-frame при успешном блоке. 0 = выключен.
@export var block_hitstop_duration: float = 0.06

var enemies: Array[Character] = []

var _attack_locked: bool = false
var _attack_turn_active: bool = false
var _block_held: bool = false


func _ready() -> void:
	super()
	add_to_group(PLAYER_GROUP)
	if _attack_frames.is_empty():
		_attack_frames = { &"attack_1": 0, &"attack_2": 1 }
	if _attack_weights.is_empty():
		_attack_weights = { &"attack_1": 1.75, &"attack_2": 1.0 }
	if _block:
		_block.hitstop_duration = block_hitstop_duration


func _physics_process(delta: float) -> void:
	_maybe_enter_queued_block()


func _apply_damage(amount: float, flash: bool = true) -> void:
	_emit_screen_shake(amount)
	super(amount, flash)


func _emit_screen_shake(amount: float) -> void:
	var p := HitShakePresets.resolve(hit_shake_preset, _hit_shake.custom)
	var dist := float(p["distance"])
	var max_hp := maxf(get_max_health(), 1.0)
	# 0.5× на «чирик», до 2× на тяжёлый удар по отношению к max HP.
	var scale := clampf(0.5 + (amount / max_hp) * 1.5, 0.5, 2.0)
	screen_shake_requested.emit(dist * scale, float(p["duration"]))


func set_attack_locked(value: bool) -> void:
	var was_locked := _attack_locked
	_attack_locked = value
	if was_locked and not value:
		_maybe_enter_queued_block()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		_try_attack()
	elif event.is_action_pressed(&"block"):
		_block_held = true
		_try_block()
	elif event.is_action_released(&"block"):
		_block_held = false
		if _state == State.BLOCKING:
			unblock()


func _try_attack() -> void:
	if _attack_locked or _attack_turn_active or _state == State.DEAD:
		return
	if _state == State.BLOCKING:
		unblock()
	if is_busy():
		return
	if _any_enemy_attacking():
		return

	var enemy := _nearest_enemy()
	if enemy == null:
		return

	_attack_turn_active = true
	attack(enemy)
	_wait_turn_end()


func _try_block() -> void:
	if _attack_locked or _attack_turn_active or _state == State.DEAD:
		return
	if _state == State.BLOCKING or is_busy():
		return
	block()


func _wait_turn_end() -> void:
	if is_busy():
		await turn_finished
	_attack_turn_active = false
	_maybe_enter_queued_block()


func _maybe_enter_queued_block() -> void:
	if not _block_held or _attack_locked or _attack_turn_active:
		return
	if _state != State.IDLE:
		return
	block()


func _nearest_enemy() -> Character:
	var best: Character = null
	var best_d2 := INF
	for e in enemies:
		if not is_instance_valid(e) or e.is_dead():
			continue
		var d2 := global_position.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


func _any_enemy_attacking() -> bool:
	for e in enemies:
		if is_instance_valid(e) and e.is_attacking():
			return true
	return false
"""


# ─────────────────────────────────────────────────────────────────────────────

def main() -> int:
	parser = argparse.ArgumentParser(
		description="Точечная правка: hitstop на блок только для игрока."
	)
	parser.add_argument("--root", default=".", help="Корень проекта Godot")
	parser.add_argument("--dry-run", action="store_true", help="Только показать план")
	parser.add_argument("--no-overwrite", action="store_true", help="Не трогать существующие файлы")
	args = parser.parse_args()

	root = Path(args.root).resolve()

	if not args.dry_run and not (root / "project.godot").exists():
		print(f"⚠  В {root} нет project.godot — всё равно продолжаю.")

	print(f"Цель: {root}\n")

	created = updated = skipped = 0

	for relpath, content in FILES.items():
		target = root / relpath

		if target.exists() and args.no_overwrite:
			print(f"  SKIP    {relpath}")
			skipped += 1
			continue

		action = "UPDATE" if target.exists() else "CREATE"

		if args.dry_run:
			print(f"  WOULD {action:6} {relpath}  ({len(content.encode('utf-8'))} b)")
			continue

		target.parent.mkdir(parents=True, exist_ok=True)
		target.write_text(content, encoding="utf-8")
		print(f"  {action:6} {relpath}  ({len(content.encode('utf-8'))} b)")

		if action == "UPDATE":
			updated += 1
		else:
			created += 1

	if not args.dry_run:
		print(f"\nГотово: created={created}, updated={updated}, skipped={skipped}")
		print("Дальше: открыть проект в Godot, дождаться пересборки class_name, F5.")

	return 0


if __name__ == "__main__":
	sys.exit(main())