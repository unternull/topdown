extends "res://addons/gut/test.gd"

const WORLD_SCENE := preload("res://scenes/world.tscn")
const BOX_SCENE := preload("res://scenes/box.tscn")


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
