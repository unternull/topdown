extends StaticBody2D

@export var has_shadow := true

var moving := false
var tween: Tween

@onready var grid: Node = get_node("/root/Grid")


func _ready() -> void:
	add_to_group("grid_actor")
	add_to_group("box")
	position = grid.snap_to_cell(position)


func move_to_cell(cell: Vector2i, world: Node) -> void:
	if moving:
		return
	moving = true
	var from: Vector2i = grid.world_to_cell(position)
	if "move_actor" in world:
		world.move_actor(from, cell, self)
	var dst: Vector2 = grid.cell_to_world_center(cell)
	if tween and tween.is_valid():
		tween.kill()
	var dist := position.distance_to(dst)
	var dur := dist / 480.0
	tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", dst, max(0.01, dur))
	tween.finished.connect(func(): moving = false)
