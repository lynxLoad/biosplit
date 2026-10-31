extends Node2D

#var config = ConfigFile.new()# 1. Создаем объект ConfigFile
#var error = config.load("res://data/all_enemy.ini")# 2. Загружаем файл ini

var enemy_name
var enemy_health_max = 120.0
var enemy_health = 120.0
var enemy_lvl
var enemy_node_name
var enemy_visible: AnimatedSprite2D

var bar_scale: float

func health_bar() ->void:
	enemy_health -= 120 #дамаг ножа
	bar_scale = enemy_health/enemy_health_max
	$spr_BarHelth.scale.x = bar_scale
	if (enemy_health <= 0):
		get_node("/root/Main").smena_mest_mobov()#ПУТЬ К НОДЕ МАЙНУ
		#get_node("/root/Main").kolvo_sozdanih_mobov -= 1
		#print(str(get_node("/root/Main").kolvo_sozdanih_mobov))
		queue_free()
	
#var variant_enemy: int #какой монстр появился(его номер в ини), выбирается рандомно

#func _ready() -> void:
	#$txt_lvl.text = str(enemy_lvl)
	#$txt_name.text = str(enemy_name)
	#
	#enemy_visible = get_node(enemy_node_name) #нашли моба по имени
	#enemy_visible.visible = true #показали моба
	#enemy_visible.play("idle")
