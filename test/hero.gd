extends Node2D
# Ссылка на узел анимации (предполагается, что AnimatedSprite2D — дочерний узел)
@onready var animated_sprite = $Hero/AnimatedSprite2D

func _ready():
	# При старте связываем сигнал завершения анимации с нашей функцией
	#animated_sprite.animation_finished.connect(_on_animated_finished)
	animated_sprite.play("idle")
	# Для теста запускаем анимацию атаки
	#start_attack()
	pass

func start_attack():
	# Запуск анимации атаки
	animated_sprite.play("Atack")
	print("ataka ON")

#func _on_animation_finished() -> void:
	# Проверяем: если закончилась именно "attack", то включаем "idle"

func rrr() -> void:
	#animated_sprite.play("idle")
	pass

func _on_animated_finished() -> void:
	if animated_sprite.animation == "atack":
		animated_sprite.play("idle")
		print("ataka OFF!!!!")
