extends Node
## Grid-authoritative movement helper. Keeps the parent actor logically at its
## starting cell during tween and updates occupancy only when the tween finishes.

signal move_started(from: Vector2i, to: Vector2i)
signal move_finished(to: Vector2i)

@export var move_speed: float = 480.0

var grid_cell: Vector2i = Vector2i.ZERO
var moving: bool = false
var _tween: Tween
var _visual: CanvasItem = null

@onready var grid: Node = get_node("/root/Grid")
@onready var actor: Node2D = get_parent() as Node2D


func _ready() -> void:
	if actor == null:
		return
	# Initialize logical cell; World will snap positions after it sets Grid.origin.
	grid_cell = grid.world_to_cell(actor.position)
	_visual = _find_visual()
	if _visual != null:
		_visual.position = Vector2.ZERO


func move_to(to_cell: Vector2i, world: Node) -> bool:
	if moving:
		return false
	if not grid.in_bounds(to_cell):
		return false
	if world == null or not world.has_method("reserve_cell"):
		return false
	# Attempt to reserve the destination cell before starting animation.
	if not world.reserve_cell(actor, to_cell):
		return false

	moving = true
	# Sync current cell from actual position in case Grid.origin changed.
	var from_cell: Vector2i = grid.world_to_cell(actor.position)
	grid_cell = from_cell
	move_started.emit(from_cell, to_cell)

	var from_pos: Vector2 = actor.position
	var to_pos: Vector2 = grid.cell_to_world_center(to_cell)
	var delta: Vector2 = to_pos - from_pos
	var dur: float = max(0.01, delta.length() / move_speed)

	if _tween and _tween.is_valid():
		_tween.kill()
	# Tween the visual presentation while the parent stays at the starting cell.
	var tween_target: Object = _visual if _visual != null else actor
	var tween_delta: Vector2 = delta
	if tween_target != actor:
		# Convert world-space delta to the actor's local space to avoid scale/rotation magnification.
		tween_delta = actor.to_local(to_pos) - actor.to_local(from_pos)
	_tween = actor.create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(tween_target, "position", tween_delta, dur)
	_tween.finished.connect(
		func() -> void:
			# Finalize logical move: update occupancy and snap to the new cell.
			var from: Vector2i = grid.world_to_cell(actor.position)
			if world.has_method("move_actor"):
				world.move_actor(from, to_cell, actor)
			grid_cell = to_cell
			actor.position = to_pos
			if _visual != null:
				_visual.position = Vector2.ZERO
			moving = false
			if world.has_method("release_reservation"):
				world.release_reservation(actor)
			move_finished.emit(grid_cell)
	)

	return true


func _find_visual() -> CanvasItem:
	# Prefer a dedicated child named "Visual" (Node2D), then AnimatedSprite2D, then Sprite2D
	var v := actor.get_node_or_null("Visual")
	if v != null and v is Node2D:
		return v as Node2D
	for n in actor.get_children():
		if n is AnimatedSprite2D:
			return n as AnimatedSprite2D
	for n2 in actor.get_children():
		if n2 is Sprite2D:
			return n2 as Sprite2D
	return null
