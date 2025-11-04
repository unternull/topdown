class_name Patrolling
extends Node
## Timed, grid-aware patrolling for the owner actor.
## Moves cell-by-cell along axis-aligned segments defined by PatrollingPoint nodes.

@export var points: Array[NodePath] = []
@export var step_interval_s: float = 0.35
@export var is_active: bool = true

var _cells: Array[Vector2i] = []
var _is_loop: bool = false
var _segment_index: int = 0
var _dir_forward: bool = true
var _on_route: bool = false
var _retry_timer_running: bool = false

@onready var grid: Node = get_node("/root/Grid")
@onready var actor: Node2D = get_parent() as Node2D
@onready var grid_actor: Node = get_parent().get_node_or_null("GridActor")
@onready var pushing: Node = get_parent().get_node_or_null("Pushing")


func _ready() -> void:
	assert(actor != null, "Patrolling must be a child of a Node2D actor")
	assert(grid_actor != null, "Patrolling requires a GridActor sibling on the owner")
	if grid_actor != null and grid_actor.has_method("set"):
		# Ensure one cell move takes step_interval_s
		var speed: float = float(grid.CELL_SIZE) / max(0.01, step_interval_s)
		(grid_actor as Object).set("move_speed", speed)

	_rebuild_cells()
	_validate_route_rules()
	_relocate_to_route()

	# React to completed moves (including being pushed by others)
	if grid_actor != null and grid_actor.has_signal("move_finished"):
		(grid_actor as Object).connect("move_finished", _on_move_finished)

	_attempt_step_deferred()


func _rebuild_cells() -> void:
	_cells.clear()
	for p in points:
		var n := get_node_or_null(p)
		assert(n != null, "Patrolling point path is invalid")
		var n2d := n as Node2D
		assert(n2d != null, "PatrollingPoint must be a Node2D")
		_cells.append(grid.world_to_cell(n2d.global_position))
	_is_loop = _cells.size() >= 2 and _cells[0] == _cells[_cells.size() - 1]


func _validate_route_rules() -> void:
	# 1) Points count
	assert(_cells.size() >= 2, "Patrolling requires at least 2 points")
	# 2) Duplicates (except possible last==first)
	var seen := {}
	for i in range(_cells.size()):
		var c: Vector2i = _cells[i]
		if i == _cells.size() - 1 and _is_loop and c == _cells[0]:
			continue
		assert(not seen.has(c), "Patrolling points contain duplicates (only last==first allowed)")
		seen[c] = true
	# 3) Axis-aligned sequential pairs
	var last_idx := _cells.size() - 1
	for j in range(last_idx):
		var a: Vector2i = _cells[j]
		var b: Vector2i = _cells[j + 1]
		assert(a.x == b.x or a.y == b.y, "Sequential patrolling points must share row or column")


func _relocate_to_route() -> void:
	_on_route = false
	if actor == null:
		return
	var cur: Vector2i = grid.world_to_cell(actor.position)
	# Find which segment the actor lies on (inclusive A..B range)
	var seg_found := -1
	for i in range(_cells.size() - 1):
		var a: Vector2i = _cells[i]
		var b: Vector2i = _cells[i + 1]
		if a.x == b.x:
			if cur.x == a.x and ((cur.y >= min(a.y, b.y)) and (cur.y <= max(a.y, b.y))):
				seg_found = i
				break
		elif a.y == b.y:
			if cur.y == a.y and ((cur.x >= min(a.x, b.x)) and (cur.x <= max(a.x, b.x))):
				seg_found = i
				break
	if seg_found >= 0:
		_segment_index = seg_found
		_on_route = true


func _attempt_step_deferred() -> void:
	call_deferred("_attempt_step")


func _attempt_step() -> void:
	if not is_active or grid_actor == null:
		return
	# Do not start a new step while owner is moving
	var mv = (grid_actor as Object).get("moving")
	if typeof(mv) == TYPE_BOOL and mv:
		return
	# Keep route info fresh
	if not _on_route:
		_relocate_to_route()
	# Yield to player responsiveness
	if _is_player_moving():
		_schedule_retry()
		return
	# Must be on a valid route segment
	if not _on_route:
		_schedule_retry()
		return

	var cur_cell: Vector2i = grid.world_to_cell(actor.position)
	var next_cell := _next_cell_towards_segment_end(cur_cell)
	var world := actor.get_parent()
	if next_cell == cur_cell or world == null:
		if next_cell == cur_cell:
			# At segment end, advance and try again
			_advance_segment_bounds()
		_schedule_retry()
		return

	var dir: Vector2i = Vector2i(sign(next_cell.x - cur_cell.x), sign(next_cell.y - cur_cell.y))
	# If blocked and we can push, try
	var occupied: bool = false
	if world.has_method("get_actor_at"):
		occupied = world.get_actor_at(next_cell) != null
	if occupied and pushing != null and pushing.has_method("try_push") and pushing.try_push(dir):
		return

	# Try reserve-and-move via GridActor
	if grid_actor.has_method("move_to"):
		var started: bool = grid_actor.move_to(next_cell, world)
		if not started:
			_schedule_retry()


func _on_move_finished(_to: Vector2i) -> void:
	# Update route state and continue
	if not _on_route:
		_relocate_to_route()
	else:
		var cur_cell: Vector2i = grid.world_to_cell(actor.position)
		var a: Vector2i = _cells[_segment_index]
		var b: Vector2i = _cells[_segment_index + 1]
		if cur_cell == b:
			_advance_segment_bounds()
	_attempt_step_deferred()


func _advance_segment_bounds() -> void:
	# Move to next segment according to loop or ping-pong
	if _is_loop:
		_segment_index = (_segment_index + 1) % (_cells.size() - 1)
	else:
		if _dir_forward:
			_segment_index += 1
			if _segment_index >= _cells.size() - 1:
				_dir_forward = false
				_segment_index = _cells.size() - 2
		else:
			_segment_index -= 1
			if _segment_index < 0:
				_dir_forward = true
				_segment_index = 0


func _next_cell_towards_segment_end(cur: Vector2i) -> Vector2i:
	var a: Vector2i = _cells[_segment_index]
	var b: Vector2i = _cells[_segment_index + 1]
	if a == b:
		return cur
	if a.x == b.x:
		var step_y := 1 if b.y > a.y else -1
		if cur == b:
			return cur
		return Vector2i(a.x, cur.y + step_y * sign(b.y - cur.y))
	# horizontal
	var step_x := 1 if b.x > a.x else -1
	if cur == b:
		return cur
	return Vector2i(cur.x + step_x * sign(b.x - cur.x), a.y)


func _is_player_moving() -> bool:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	var p := players[0]
	var pga := (p as Node).get_node_or_null("GridActor")
	if pga == null:
		return false
	var mv = (pga as Object).get("moving")
	return typeof(mv) == TYPE_BOOL and mv


func _schedule_retry() -> void:
	if _retry_timer_running:
		return
	_retry_timer_running = true
	get_tree().create_timer(0.1).timeout.connect(
		func() -> void:
			_retry_timer_running = false
			_attempt_step_deferred(),
		Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED
	)
