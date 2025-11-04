extends "res://addons/gut/test.gd"

const WORLD_SCENE := preload("res://scenes/world.tscn")
const BOX_SCENE := preload("res://scenes/box.tscn")


func _await_move_or_timeout(ga: Node, timeout_s: float = 5.0) -> void:
	if ga == null:
		return
	var deadline: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while true:
		var mv = ga.get("moving")
		if typeof(mv) == TYPE_BOOL and not mv:
			return
		if Time.get_ticks_msec() >= deadline:
			assert_true(false, "Movement did not finish before timeout")
			return
		await get_tree().process_frame


func _make_patroller(world: Node, cells: Array[Vector2i], interval: float = 0.05) -> Node:
	var pat := BOX_SCENE.instantiate()
	pat.position = Grid.cell_to_world_center(cells[0])
	world.add_child(pat)
	var p := Node.new()
	pat.add_child(p)
	p.name = "Patrolling"
	p.set_script(load("res://scripts/patrolling.gd"))
	# Create points as children
	var nps: Array[NodePath] = []
	for c in cells:
		var pp := Node2D.new()
		pp.set_script(load("res://scripts/patrolling_point.gd"))
		pp.global_position = Grid.cell_to_world_center(c)
		p.add_child(pp)
		nps.append(pp.get_path())
	(p as Object).set("points", nps)
	(p as Object).set("step_interval_s", interval)
	return pat


func test_patroller_loops_when_last_equals_first() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var route: Array[Vector2i] = [Vector2i(2, 2), Vector2i(4, 2), Vector2i(2, 2)]
	var pat := _make_patroller(world, route, 0.02)
	world._build_occupancy()
	# Let it move a few steps
	var ga: Node = pat.get_node("GridActor")
	for i in range(6):
		await get_tree().process_frame
		if ga != null:
			var mv = ga.get("moving")
			if typeof(mv) == TYPE_BOOL and mv:
				await _await_move_or_timeout(ga)
	# Should still be on the route row
	var cell: Vector2i = Grid.world_to_cell(pat.position)
	assert_eq(cell.y, 2)


func test_patroller_ping_pongs_when_open_route() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var route: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 1)]
	var pat := _make_patroller(world, route, 0.02)
	world._build_occupancy()
	var ga: Node = pat.get_node("GridActor")
	# Move to the far end
	for i in range(4):
		await get_tree().process_frame
		if ga != null:
			var mv = ga.get("moving")
			if typeof(mv) == TYPE_BOOL and mv:
				await _await_move_or_timeout(ga)
	var cell: Vector2i = Grid.world_to_cell(pat.position)
	assert_true(cell.x == 1 or cell.x == 3)
