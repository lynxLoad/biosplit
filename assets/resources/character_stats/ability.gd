@tool
class_name Ability
extends Resource
## Одна способность.
## ap_delta > 0 — генерирует AP (обычно ap_need = 0).
## ap_delta < 0 — тратит AP.

#region Exports
@export_group("Identity")
@export var name: StringName = &"ability_name":
	set(value):
		name = value if value != &"" else &"ability_name"

@export_group("Animation")
## База имени анимации атаки. При animation_variants > 1 к имени
## добавляется суффикс _0, _1, ... (0-based).
@export var animation_name: StringName = &"ability_animation_name"
@export_range(1, 32, 1, "or_greater") var animation_variants: int = 1
## Анимация замаха. Если её нет в SpriteFrames — шаг пропускается.
@export var prepare_name: StringName = &"prepare"

@export_group("Combat")
@export_range(0.0, 10_000.0, 0.1, "or_greater", "suffix:dmg") var damage: float = 10.0

@export_group("Action Points")
## Минимальный AP, при котором способность доступна.
@export_range(0.0, 100.0, 0.5, "or_greater", "suffix:AP") var ap_need: float = 0.0
## Знаковая дельта: > 0 — генерирует, < 0 — тратит, 0 — нейтральная.
@export_range(-100.0, 100.0, 0.5, "suffix:AP") var ap_delta: float = 0.5
#endregion

#region Helpers
func get_animation_name(variant: int = 0) -> StringName:
	if animation_variants <= 1:
		return animation_name
	return StringName("%s_%d" % [animation_name, clampi(variant, 0, animation_variants - 1)])

func has_prepare() -> bool:
	return prepare_name != &""

func is_generator() -> bool:
	return ap_delta > 0.0

func is_consumer() -> bool:
	return ap_delta < 0.0

func is_neutral() -> bool:
	return is_zero_approx(ap_delta)

func get_ap_cost() -> float:
	return maxf(0.0, -ap_delta)

func get_ap_gain() -> float:
	return maxf(0.0, ap_delta)

func can_use(current_ap: float) -> bool:
	if current_ap < ap_need:
		return false
	if current_ap + ap_delta < 0.0:
		return false
	return true

func _to_string() -> String:
	var tag := "gain" if is_generator() else ("cost" if is_consumer() else "free")
	return "Ability(%s, %s %.1fAP, %.1fdmg)" % [name, tag, absf(ap_delta), damage]
#endregion
