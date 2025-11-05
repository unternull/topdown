class_name Pushable
extends Node
## Enables its parent actor to be pushed by a pusher.

@export var push_speed: float = 480.0
@export var required_pushing_power: int = 1

var moving: bool = false
var tween: Tween

@onready var grid: Node = get_node("/root/Grid")
@onready var actor: Node2D = get_parent() as Node2D
@onready var grid_actor: Node = get_parent().get_node_or_null("GridActor")


func push(dir: Vector2i, world: Node) -> bool:
	# Delegate to GridActor if available; otherwise fall back to legacy tween.
	if moving:
		return false
	var from: Vector2i = grid.world_to_cell(actor.position)
	var to: Vector2i = from + dir
	if not grid.in_bounds(to):
		return false
	if grid_actor != null and grid_actor.has_method("move_to"):
		# GridActor handles reservation + tween + occupancy on finish.
		var started: bool = grid_actor.move_to(to, world)
		print("[Pushable] ", actor.name, " push to:", to, " started:", started)
		if started:
			moving = true
			# Mirror moving flag back to false when the grid move completes (deferred, one-shot).
			(grid_actor as Object).connect(
				"move_finished",
				func(_to: Vector2i) -> void: moving = false,
				Object.CONNECT_DEFERRED | Object.CONNECT_ONE_SHOT
			)
		return started
	# Legacy fallback (should not be used with reservations) - keep for safety.
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
