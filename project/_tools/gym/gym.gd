class_name Gym
extends Node3D

@onready var CAR:PackedScene = load("uid://cybdinxiojqlp")
@onready var ENEMY:PackedScene = load("uid://cgqtho0svu7jw")

@onready var car = %Car
@onready var enemy:Character = %Enemy
@onready var props:Node3D = $Props

@onready var car_spawn:Transform3D = car.global_transform
@onready var enemy_spawn:Transform3D = enemy.global_transform

func respawn_car(_player:Character):
	if is_instance_valid(car):
		car.queue_free()
	car = CAR.instantiate()
	props.add_child(car)
	car.global_transform = car_spawn


func respawn_enemy(_player:Character):
	if is_instance_valid(enemy):
		enemy.queue_free()
	enemy = ENEMY.instantiate()
	props.add_child(enemy)
	enemy.global_transform = enemy_spawn


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.key_label == KEY_H:
			get_tree().reload_current_scene()
