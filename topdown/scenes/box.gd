extends StaticBody2D

@export var has_shadow := true

@onready var grid: Node = get_node("/root/Grid")


func _ready() -> void:
	add_to_group("grid_actor")
	add_to_group("box")
	position = grid.snap_to_cell(position)
