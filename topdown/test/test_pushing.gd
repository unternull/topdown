extends "res://addons/gut/test.gd"

const WORLD_SCENE := preload("res://scenes/world.tscn")
const BOX_SCENE := preload("res://scenes/box.tscn")


func _await_move_or_timeout(ga: Node, timeout_s: float = 5.0) -> void:
	if ga == null:
		return
	# Allow scheduler to start actions
	await get_tree().process_frame
	var deadline: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	var seen_moving := false
	while true:
		var mv = ga.get("moving")
		if typeof(mv) == TYPE_BOOL:
			if mv:
				seen_moving = true
			elif seen_moving:
				return
		if Time.get_ticks_msec() >= deadline:
			assert_true(false, "Movement did not finish before timeout")
			return
		await get_tree().process_frame


func _await_move_signals_or_timeout(ga: Node, timeout_s: float = 5.0) -> void:
	if ga == null:
		return
	# Allow scheduler to enqueue actions
	await get_tree().process_frame
	var started_seen := false
	var finished_seen := false
	if ga.has_signal("move_started"):
		ga.connect(
			"move_started",
			func(_from: Vector2i, _to: Vector2i) -> void: started_seen = true,
			Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED
		)
	else:
		started_seen = true
	if ga.has_signal("move_finished"):
		ga.connect(
			"move_finished",
			func(_to: Vector2i) -> void: finished_seen = true,
			Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED
		)
	var deadline: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while true:
		var mv = ga.get("moving")
		if typeof(mv) == TYPE_BOOL:
			if mv:
				started_seen = true
			elif started_seen:
				finished_seen = true
		if started_seen and finished_seen:
			return
		if Time.get_ticks_msec() >= deadline:
			assert_true(false, "Movement did not finish before timeout")
			return
		await get_tree().process_frame


func _find_clear_dir(world: Node, player: Node) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var grid: Node = Grid
	var from: Vector2i = (
		player.target_cell if ("target_cell" in player) else grid.world_to_cell(player.position)
	)
	for d in dirs:
		var a := from + d
		var b := a + d
		if not grid.in_bounds(a) or not grid.in_bounds(b):
			continue
		if ("is_cell_free" in world) and world.is_cell_free(a) and world.is_cell_free(b):
			return d
	return Vector2i.ZERO


func test_pushing_pushes_pushable() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node = world.get_node("Player")
	var dir: Vector2i = _find_clear_dir(world, player)
	assert_ne(dir, Vector2i.ZERO, "Need a clear direction to test push")
	var start: Vector2i = player.target_cell
	var front: Vector2i = start + dir
	var box := BOX_SCENE.instantiate()
	box.position = Grid.cell_to_world_center(front)
	world.add_child(box)
	# Rebuild occupancy to include the newly added box
	world._build_occupancy()

	player._try_step(dir)
	# Await movements to complete (box first, then player)
	var box_ga: Node = box.get_node_or_null("GridActor")
	if box_ga != null:
		await _await_move_signals_or_timeout(box_ga, 5.0)
	var player_ga: Node = player.get_node_or_null("GridActor")
	if player_ga != null:
		await _await_move_signals_or_timeout(player_ga, 5.0)

	var pushed_to: Vector2i = front + dir
	var actor_at_pushed: Node = world.get_actor_at(pushed_to)
	assert_true(actor_at_pushed == box, "Box should be pushed one cell forward")
	assert_eq(player.target_cell, front, "Player should step into the box's previous cell")


func test_pushing_cannot_push_non_pushable() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node = world.get_node("Player")
	var dir: Vector2i = _find_clear_dir(world, player)
	assert_ne(dir, Vector2i.ZERO, "Need a clear direction to test blocking")
	var start: Vector2i = player.target_cell
	var front: Vector2i = start + dir

	var blocker := StaticBody2D.new()
	blocker.add_to_group("grid_actor")
	blocker.position = Grid.cell_to_world_center(front)
	world.add_child(blocker)
	world._build_occupancy()

	player._try_step(dir)

	assert_eq(player.target_cell, start, "Player should not move when object is not Pushable")
	var actor_at_front: Node = world.get_actor_at(front)
	assert_true(actor_at_front == blocker, "Blocker should remain in place")
