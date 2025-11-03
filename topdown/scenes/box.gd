extends Node2D

@export var has_shadow := false
@export var texture: Texture2D = preload("res://assets/simple_block.png")

@onready var grid: Node = get_node("/root/Grid")
@onready var sprite: Sprite2D = %Sprite2D


func _ready() -> void:
	add_to_group("grid_actor")
	add_to_group("box")
	position = grid.snap_to_cell(position)
	sprite.texture = texture
