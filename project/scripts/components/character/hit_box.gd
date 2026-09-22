class_name HitBox
extends Area3D

@export var damage:int = 1

var character:CharacterBody3D

var attack_data:
	get:
		return character.attack_data
