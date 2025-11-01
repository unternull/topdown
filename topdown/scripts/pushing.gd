class_name Pushing
extends Node
## Enables its parent actor to push adjacent actors that have a Pushable child.

@onready var grid: Node = get_node("/root/Grid")
@onready var actor: Node2D = get_parent() as Node2D


func try_push(dir: Vector2i) -> bool:
	var world: Node = actor.get_parent()
	if world == null or not world.has_method("get_actor_at"):
		return false
	var from: Vector2i = grid.world_to_cell(actor.position)
	var to: Vector2i = from + dir
	if not grid.in_bounds(to):
		return false

	var target: Node = world.get_actor_at(to)
	if target == null:
		return false

	var pushable: Node = target.get_node_or_null("Pushable")
	if pushable == null:
		return false
	if not pushable.has_method("push"):
		return false
	return pushable.push(dir, world)
