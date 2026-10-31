extends Node
var btn_ataka_najata: bool = false#кнопка атака нажата
var hero_state = 0 #что делает игрок
var enemy_01_state = 0 #фаза реакции противника
var udar_culdaun = 0 #кулдаун после удара ножом

#region РЕСПАВНЫ ГЕРОЯ ВСЕХ МОНСТРОВ
#респавны героя всех монстров
var hero_respavn_point = Vector2 (330,340)
var hero_atack_point =  Vector2(490, 340) 

var enemy_respavn_point = {
	"enemy1": Vector2 (570,340),
	"enemy2": Vector2 (720,305),
	"enemy3": Vector2 (820,355)
}

var kolvo_sozdanih_mobov = 3 #создали 3х мобов
#если мобов 0 показываем экран конец игры


#endregion

#region ПОДГРУЗКА ИНИ и ДАННЫЕ МОНСТРОВ
var config = ConfigFile.new()# 1. Создаем объект ConfigFile
var error = config.load("res://test/data/all_enemy.ini")# 2. Загружаем файл ini

var enemy_name
var enemy_helth
var enemy_lvl

var variant_enemy: int #какой монстр появился(его номер в ини), выбирается рандомно
#endregion

@onready var hero_anim: AnimatedSprite2D = $Hero/AnimatedSprite2D
#@onready var enemy1: AnimatedSprite2D  = $Enemy1/AnimSpr_Zombi_01

@onready var timer_udar_culdaun: Timer = $timer_udar_culdaun

var obj_atack #объект который мы атакуем
var obj_atack_animator: AnimatedSprite2D
var spisok_mobov: Array = [] #список мобов и их имена при создании, если 0, конец игры
var spisok_umershih_mobov: Array = []
#var animator: AnimatedSprite2D

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

func _ready() -> void:
	
	#region ВСЁ ДЛЯ ЭНИМИ
	for i in range(1, 4): #создаем цикл для 3 мобов
		#загружаем сцену с мобом
		var enemy_path = "res://test/all_enemy/Enemy_" + str(randi_range(1, 3)) + ".tscn"
		var enemy = load(enemy_path).instantiate()# Шаг 2: Создаем экземпляр сцены в памяти
		enemy.position = enemy_respavn_point["enemy"+str(i)]#меняем позицию
		enemy.name = "Enemy_" +str(i)#нужен ренейм ноды перед заносом в список его имени
		spisok_mobov.append(enemy.name)#добавляем имена в арей
		add_child(enemy)#Добавляем объект в текущую сцену
		
	#spisok_mobov.pop_front()
	
	obj_atack = get_node(str(spisok_mobov[0]))
	obj_atack_animator = get_node(str(spisok_mobov[0])+"/anim_Enemy")
	print(spisok_mobov[0])
	
	#enemy.enemy_name = config.get_value("enemy"+str(random), "name")
	#enemy.enemy_node_name = config.get_value("enemy"+str(random), "node_name")
	#enemy.enemy_lvl = config.get_value("enemy"+str(random), "lvl")
	#enemy.enemy_health = config.get_value("enemy"+str(random), "health")
	
	#spisok_mobov.append("enemy_"+str(i))#добавляем имена в арей
	#add_child(enemy)#Добавляем объект в текущую сцену
	
	
	
	
	#variant_enemy = 1
	#var obj_atack = get_node("Enemy_"+str(variant_enemy))#объект атаки
	#obj_atack.show()
	#
	#enemy_name = config.get_value("Enemy_"+str(variant_enemy), "name")
	#enemy_helth = config.get_value("Enemy_"+str(variant_enemy), "health")
	#enemy_lvl = config.get_value("Enemy_"+str(variant_enemy), "lvl")
	#print(str(enemy_helth))
	#$txt_lvl.text = str(enemy_lvl)
	#$txt_name.text = str(enemy_name)
	
	#endregion
	#объект атаки
	#obj_atack = get_node("Enrmy1")
	#animator = get_node("Enemy1/anim_Zombi_01") as AnimatedSprite2D
	#animator.play("idle")
	
	
	# Подключаем сигнал окончания анимации к нашей функции
	hero_anim.animation_finished.connect(_on_hero_animation_finished)
	obj_atack_animator.animation_finished.connect(_on_enemy_animation_finished)
	
	
	hero_anim.play("idle")
	#print_tree_pretty()
	print(spisok_mobov)
	
	#obj_atack = get_node(spisok_mobov[0]) #НАХОДИМ МОБА КОТОРОГО БУДЕМ БИТЬ
	#подключили конец анимации моба
	#obj_atack.enemy_visible.animation_finished.connect(_on_enemy_animation_finished)

func _process(delta: float) -> void:
	#obj_atack = get_node(spisok_mobov[0]) #взяли объект
	
	if (hero_state == 101): #ЕДЕМ ВПЕРЕД
		$Hero.position.x = lerp($Hero.position.x, hero_atack_point.x+10, 20*delta)
		if ($Hero.position.x > hero_atack_point.x):
			$Hero.position.x = hero_atack_point.x
			hero_state = 1 #ДЕЛАЕМ АНИМАЦИЮ АТАКА 1
	
	if (hero_state == 103): #ЕДЕМ НАЗАД
		$Hero.position.x = lerp($Hero.position.x, $Hero.position.x-335, 20*delta)
		if ($Hero.position.x <= 329): ### ГЕРОЙ ПРИЕХАЛ НА МЕСТО !!!!!!!!
			$Hero.position.x = 330
			hero_anim.play("idle")
			#if is_instance_valid($All_Enemy):
				#enemy1.play("idle")
			timer_udar_culdaun.start() #запустили таймер на кулдаун
			#print("Кулдаун начат")
			udar_culdaun = 1 #кулдаун запущен
			hero_state = 0
	
	if (btn_ataka_najata == true && udar_culdaun == 0):#ЕДЕМ ВПЕРЕД
		hero_state = 101 #ЕДЕМ ВПЕРЕД
	
	### - - - - - - - - - - - - - - - - - - - - - - - -
	###         ГЕРОЙ ПРИЕХАЛ К ЗОМБИ И АТАКУЕТ
	### - - - - - - - - - - - - - - - - - - - - - - - -
	if (hero_state == 1):
		hero_anim.play("atack_1") #ДЕЛАЕМ АНИМАЦИЮ АТАКА 1
		obj_atack_animator.play("damag")#проиграть аним урона мобу
		

##### НАЖАЛИ АТАКУ
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_SPACE"):
		if(udar_culdaun == 0 && hero_state == 0 && kolvo_sozdanih_mobov > 0):#если кулдауна на удар нет
#			btn_ataka_najata = true
			hero_state = 101 #пошла первая фаза атаки, позъезд к мобу
	
#	if event.is_action_released("btn_SPACE"):
#		btn_ataka_najata = false

##### АНИМАЦИЯ  ГЕРОЯ  ЗАКОНЧИЛАСЬ
func _on_hero_animation_finished() -> void:
	# Проверяем: если только что закончилась атака, возвращаем idle
	if (hero_anim.animation == "atack_1"):
		obj_atack.health_bar()
		hero_state = 103 #едем обратно
#		obj_atack.enemy_helth -= 50

##### АНИМАЦИЯ  ENEMY  ЗАКОНЧИЛАСЬ
func _on_enemy_animation_finished() -> void:
	if (obj_atack_animator.animation == "damag"):
		obj_atack_animator.play("idle")

###таймер кулдаун удара доиграл
func _on_timer_udar_culdaun_timeout() -> void:
	#таймер кулдаун удара доиграл
	#print("Кулдаун закончен")
	udar_culdaun = 0

func smena_mest_mobov()->void:
	if (kolvo_sozdanih_mobov >1):
		spisok_mobov.pop_front()
		kolvo_sozdanih_mobov -=1
		print(spisok_mobov[0])
		obj_atack = get_node(str(spisok_mobov[0]))
		obj_atack_animator = get_node(str(spisok_mobov[0])+"/anim_Enemy")
		obj_atack.position = enemy_respavn_point["enemy1"]
		obj_atack = get_node(str(spisok_mobov[1]))
		obj_atack_animator = get_node(str(spisok_mobov[1])+"/anim_Enemy")
		obj_atack.position = enemy_respavn_point["enemy2"]
	else:
		print("КОНЕЦ ИГРЫ")
