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


func _setup_actor_with_power(node: Node, push_power: int, req_power: int) -> void:
	var pushing: Node = node.get_node_or_null("Pushing")
	if pushing != null:
		(pushing as Object).set("pushing_power", push_power)
	var pushable: Node = node.get_node_or_null("Pushable")
	if pushable != null:
		(pushable as Object).set("required_pushing_power", req_power)


func test_push_power_success() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node = world.get_node("Player")
	_setup_actor_with_power(player, 2, 1)
	# Place a box in front that requires lower power
	var dir := Vector2i(1, 0)
	var start: Vector2i = player.get("target_cell")
	var front: Vector2i = start + dir
	var box := BOX_SCENE.instantiate()
	_setup_actor_with_power(box, 0, 1)
	box.position = Grid.cell_to_world_center(front)
	world.add_child(box)
	world._build_occupancy()
	player._try_step(dir)
	var box_ga: Node = box.get_node_or_null("GridActor")
	if box_ga != null:
		await _await_move_or_timeout(box_ga)
	var pushed_to: Vector2i = front + dir
	assert_true(world.get_actor_at(pushed_to) == box)


func test_push_power_stalemate() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node = world.get_node("Player")
	_setup_actor_with_power(player, 1, 1)
	var dir := Vector2i(1, 0)
	var start: Vector2i = player.get("target_cell")
	var front: Vector2i = start + dir
	var box := BOX_SCENE.instantiate()
	_setup_actor_with_power(box, 1, 1)
	box.position = Grid.cell_to_world_center(front)
	world.add_child(box)
	world._build_occupancy()
	player._try_step(dir)
	# Ensure box did not move
	await get_tree().process_frame
	assert_true(world.get_actor_at(front) == box)


func test_push_power_failure() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node = world.get_node("Player")
	_setup_actor_with_power(player, 1, 1)
	var dir := Vector2i(1, 0)
	var start: Vector2i = player.get("target_cell")
	var front: Vector2i = start + dir
	var box := BOX_SCENE.instantiate()
	_setup_actor_with_power(box, 0, 2)
	box.position = Grid.cell_to_world_center(front)
	world.add_child(box)
	world._build_occupancy()
	player._try_step(dir)
	await get_tree().process_frame
	assert_true(world.get_actor_at(front) == box)
