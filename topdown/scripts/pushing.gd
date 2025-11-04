class_name Pushing
extends Node
## Enables its parent actor to push adjacent actors that have a Pushable child.

@export var pushing_power: int = 1

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

	# Power checks and competition
	var req_power: int = 1
	if pushable != null and (pushable as Object).has_method("get"):
		var v = (pushable as Object).get("required_pushing_power")
		if typeof(v) == TYPE_INT:
			req_power = int(v)
	var allowed := pushing_power >= req_power
	# Competition with another pusher
	var target_pushing: Node = target.get_node_or_null("Pushing")
	if target_pushing != null and (target_pushing as Object).has_method("get"):
		var their_power_v = (target_pushing as Object).get("pushing_power")
		if typeof(their_power_v) == TYPE_INT:
			var their_power: int = int(their_power_v)
			if their_power >= pushing_power:
				allowed = false
	print("[Pushing] ", actor.name, " -> attempt push dir:", dir, " allowed:", allowed)
	if not allowed:
		return false
	var pushed: bool = pushable.push(dir, world)
	print("[Pushing] ", actor.name, " target started:", pushed)
	if not pushed:
		return false
	# Chain the player's step into the vacated cell once the target finishes moving.
	var target_ga: Node = target.get_node_or_null("GridActor")
	if target_ga != null:
		# Use a deferred, one-shot connection to start the actor's move after the box finishes.
		target_ga.move_finished.connect(
			Callable(self, "_on_target_pushed").bind(to),
			Object.CONNECT_DEFERRED | Object.CONNECT_ONE_SHOT
		)
	return true


func _on_target_pushed(_pushed_to: Vector2i, vacated_cell: Vector2i) -> void:
	print("[Pushing] ", actor.name, " stepping into vacated:", vacated_cell)
	var player_ga: Node = actor.get_node_or_null("GridActor")
	if player_ga == null or not player_ga.has_method("move_to"):
		return
	var world: Node = actor.get_parent()
	if world == null:
		return
	player_ga.call_deferred("move_to", vacated_cell, world)
