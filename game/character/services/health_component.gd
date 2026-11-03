class_name HealthComponent
extends RefCounted

var health: float = 0.0
var max_health: float = 0.0


func setup(value: float) -> void:
	max_health = value
	health = value


func apply(amount: float) -> void:
	health = maxf(0.0, health - amount)


func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	health = minf(max_health, health + amount)


func is_dead() -> bool:
	return health <= 0.0
