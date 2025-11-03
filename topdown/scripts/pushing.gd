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
	var pushable: Node = null
	if target != null:
		pushable = target.get_node_or_null("Pushable")

	var can_push := pushable != null and pushable.has_method("push")
	if not can_push:
		return false
	var pushed: bool = pushable.push(dir, world)
	if not pushed:
		return false
	# Chain the player's step into the vacated cell once the target finishes moving.
	var target_ga: Node = target.get_node_or_null("GridActor")
	var player_ga: Node = actor.get_node_or_null("GridActor")
	if target_ga != null and player_ga != null and player_ga.has_method("move_to"):
		var next_cell: Vector2i = to
		# Use a deferred, one-shot connection to start the player's move after the box finishes.
		target_ga.move_finished.connect(
			func(_to_cell: Vector2i) -> void: player_ga.call_deferred("move_to", next_cell, world),
			Object.CONNECT_DEFERRED | Object.CONNECT_ONE_SHOT
		)
	return true
