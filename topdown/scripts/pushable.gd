class_name Pushable
extends Node
## Enables its parent actor to be pushed by a pusher.

@export var push_speed: float = 480.0

var moving: bool = false
var tween: Tween

@onready var grid: Node = get_node("/root/Grid")
@onready var actor: Node2D = get_parent() as Node2D


func push(dir: Vector2i, world: Node) -> bool:
	if moving:
		return false
	var from: Vector2i = grid.world_to_cell(actor.position)
	var to: Vector2i = from + dir
	if not grid.in_bounds(to):
		return false
	if not (world != null and world.has_method("is_cell_free") and world.is_cell_free(to)):
		return false

	moving = true
	if world != null and world.has_method("move_actor"):
		world.move_actor(from, to, actor)
	var dst: Vector2 = grid.cell_to_world_center(to)
	if tween and tween.is_valid():
		tween.kill()
	var dist := actor.position.distance_to(dst)
	var dur := dist / push_speed
	tween = actor.create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(actor, "position", dst, max(0.01, dur))
	tween.finished.connect(func(): moving = false)
	return true
