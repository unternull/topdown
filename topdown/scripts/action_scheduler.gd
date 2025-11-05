extends Node
## Deterministic single-queue action scheduler.
## Arbitrates Push before Move, and Player > Pusher > Mover with FIFO tie-breaks.

enum ActionKind {
	PUSH,
	MOVE,
}

const ACTION_PRIORITY := {
	ActionKind.PUSH: 2,
	ActionKind.MOVE: 1,
}

const ACTOR_PRIORITY_PLAYER := 3
const ACTOR_PRIORITY_PUSHER := 2
const ACTOR_PRIORITY_MOVER := 1


class Action:
	var id: int
	var kind: int
	var actor: Node2D
	var payload: Dictionary
	var actor_pri: int
	var seq: int
	var created_tick: int


var _seq: int = 0
var _tick: int = 0
var _queue: Array = []
var _push_in_flight: int = 0
var _push_locks := {}  # target(Node) -> action id


func _ready() -> void:
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_tick += 1
	_process_queue()


func enqueue_push(actor: Node2D, dir: Vector2i, target: Node2D) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return
	var a := Action.new()
	a.id = _seq
	_seq += 1
	a.kind = ActionKind.PUSH
	a.actor = actor
	a.payload = {"dir": dir, "target": target}
	a.actor_pri = _actor_priority(actor)
	a.seq = a.id
	a.created_tick = _tick
	_queue.append(a)


func enqueue_move(actor: Node2D, to_cell: Vector2i) -> void:
	if not is_instance_valid(actor):
		return
	var a := Action.new()
	a.id = _seq
	_seq += 1
	a.kind = ActionKind.MOVE
	a.actor = actor
	var from_cell := Vector2i.ZERO
	var grid := get_node("/root/Grid")
	if grid != null:
		from_cell = (grid as Object).call("world_to_cell", actor.position)
	a.payload = {"to": to_cell, "from": from_cell}
	a.actor_pri = _actor_priority(actor)
	a.seq = a.id
	a.created_tick = _tick
	_queue.append(a)


func _actor_priority(actor: Node) -> int:
	if actor.is_in_group("player"):
		return ACTOR_PRIORITY_PLAYER
	if actor.get_node_or_null("Pushing") != null:
		return ACTOR_PRIORITY_PUSHER
	if actor.get_node_or_null("GridActor") != null:
		return ACTOR_PRIORITY_MOVER
	return 0


func _compare_actions(a: Action, b: Action) -> bool:
	var ap: int = ACTION_PRIORITY.get(a.kind, 0)
	var bp: int = ACTION_PRIORITY.get(b.kind, 0)
	if ap != bp:
		return ap > bp
	if a.actor_pri != b.actor_pri:
		return a.actor_pri > b.actor_pri
	return a.seq < b.seq


func _process_queue() -> void:
	if _queue.is_empty():
		return
	_queue.sort_custom(Callable(self, "_compare_actions"))
	var has_push := false
	for a in _queue:
		if (a as Action).kind == ActionKind.PUSH:
			has_push = true
			break
	if has_push or _push_in_flight > 0:
		_execute_only(ActionKind.PUSH)
	else:
		_execute_only(ActionKind.MOVE)


func _execute_only(kind: int) -> void:
	var next: Array = []
	for item in _queue:
		var a := item as Action
		if a.kind != kind:
			next.append(a)
			continue
		if not _is_action_valid(a):
			# Drop invalid/stale actions
			continue
		var started := false
		match kind:
			ActionKind.PUSH:
				started = _start_push(a)
			ActionKind.MOVE:
				started = _start_move(a)
		if not started:
			# Keep action in the queue to retry later
			next.append(a)
	_queue = next


func _is_action_valid(a: Action) -> bool:
	if not is_instance_valid(a.actor):
		return false
	var valid := true
	var world := a.actor.get_parent()
	if world == null:
		valid = false
	# Disallow while moving
	var ga := a.actor.get_node_or_null("GridActor")
	if ga != null and (ga as Object).has_method("get"):
		var mv = (ga as Object).get("moving")
		if typeof(mv) == TYPE_BOOL and mv:
			valid = false
	if a.kind == ActionKind.PUSH:
		var target: Node2D = a.payload.get("target")
		if not is_instance_valid(target) or _push_locks.has(target):
			valid = false
		else:
			var pushable := target.get_node_or_null("Pushable")
			if pushable == null:
				valid = false
			else:
				# Do not treat target moving as invalid; we'll retry push later
				# Geometry: ensure target is exactly at actor_cell + dir
				if valid:
					var dir: Vector2i = a.payload.get("dir", Vector2i.ZERO)
					var grid := get_node("/root/Grid")
					if grid != null:
						var actor_cell: Vector2i = (grid as Object).call(
							"world_to_cell", a.actor.position
						)
						var expected: Vector2i = Vector2i(
							actor_cell.x + dir.x, actor_cell.y + dir.y
						)
						var target_cell: Vector2i = (grid as Object).call(
							"world_to_cell", target.position
						)
						if target_cell != expected:
							valid = false
	elif a.kind == ActionKind.MOVE:
		var grid2 := get_node("/root/Grid")
		if grid2 != null:
			var actor_cell2: Vector2i = (grid2 as Object).call("world_to_cell", a.actor.position)
			var from_payload: Vector2i = a.payload.get("from", actor_cell2)
			if actor_cell2 != from_payload:
				valid = false
	return valid


func _start_push(a: Action) -> bool:
	var actor := a.actor
	var dir: Vector2i = a.payload.get("dir", Vector2i.ZERO)
	var target: Node2D = a.payload.get("target")
	var pusher := actor.get_node_or_null("Pushing")
	if pusher == null:
		return false
	# If target is currently moving, snap it to origin immediately and proceed
	var target_ga := target.get_node_or_null("GridActor")
	if target_ga != null and (target_ga as Object).has_method("get"):
		var tmov = (target_ga as Object).get("moving")
		if typeof(tmov) == TYPE_BOOL and tmov:
			var world2 := actor.get_parent()
			if world2 != null and (target_ga as Object).has_method("cancel_to_origin_immediate"):
				(target_ga as Object).call("cancel_to_origin_immediate", world2)
			# Now movement is cancelled; continue to start the push in this tick
	# Lock target to avoid double-push while starting
	_push_locks[target] = a.id
	var started: bool = (pusher as Object).call("try_push", dir)
	if not started:
		_push_locks.erase(target)
		return false
	_push_in_flight += 1
	# When target finishes, unlock and enqueue the pusher's step into vacated cell.
	var tga := target.get_node_or_null("GridActor")
	if tga != null and (tga as Object).has_signal("move_finished"):
		(tga as Object).connect(
			"move_finished",
			Callable(self, "_on_target_push_finished").bind(actor, target, dir, a.id),
			Object.CONNECT_DEFERRED | Object.CONNECT_ONE_SHOT
		)
	return true


func _on_target_push_finished(
	to_cell: Vector2i, actor: Node2D, target: Node2D, dir: Vector2i, action_id: int
) -> void:
	_push_in_flight = max(0, _push_in_flight - 1)
	if _push_locks.get(target) == action_id:
		_push_locks.erase(target)
	# Vacated cell is the original target cell, which equals pushed-to minus dir
	var vacated: Vector2i = Vector2i(to_cell.x - dir.x, to_cell.y - dir.y)
	# Connect to pusher's move start to release pushing animation
	var pga := actor.get_node_or_null("GridActor")
	var pushing := actor.get_node_or_null("Pushing")
	var can_hook := false
	if pga != null and pushing != null:
		var has_ms := (pga as Object).has_signal("move_started")
		var has_pr := (pushing as Object).has_signal("push_animation_release")
		can_hook = has_ms and has_pr
	if can_hook:
		(pga as Object).connect(
			"move_started",
			Callable(self, "_emit_push_release").bind(pushing),
			Object.CONNECT_DEFERRED | Object.CONNECT_ONE_SHOT
		)
	# Enqueue follow-up move for the pusher
	enqueue_move(actor, vacated)


func _emit_push_release(_from: Vector2i, _to: Vector2i, pushing: Node) -> void:
	if is_instance_valid(pushing):
		(pushing as Object).emit_signal("push_animation_release")


func _start_move(a: Action) -> bool:
	var ga := a.actor.get_node_or_null("GridActor")
	var world := a.actor.get_parent()
	if ga == null or world == null:
		return false
	var to_cell: Vector2i = a.payload.get("to", Vector2i.ZERO)
	var ok: bool = (ga as Object).call("move_to", to_cell, world)
	return ok
