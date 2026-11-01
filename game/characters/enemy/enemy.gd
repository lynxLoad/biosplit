extends CharacterBase
class_name Enemy

@onready var health_bar: Bar = $HealthBar

func _ready() -> void:
	super._ready()
	_init_bar(health_bar, health, character_stats.max_health)

func heal(amount: float) -> void:
	super.heal(amount)
	_sync_bar(health_bar, health, character_stats.max_health)

func _apply_damage(amount: float) -> void:
	super._apply_damage(amount)
	_sync_bar(health_bar, health, character_stats.max_health)
