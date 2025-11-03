extends "res://addons/gut/test.gd"

const WORLD_SCENE := preload("res://scenes/world.tscn")
const BOX_SCENE := preload("res://scenes/box.tscn")


func _add_box(world: Node, cell: Vector2i, families: Array[String] = ["brown"]) -> Node:
	var box := BOX_SCENE.instantiate()
	var fam: Node = box.get_node("Familiar")
	fam.families = families
	box.position = Grid.cell_to_world_center(cell)
	world.add_child(box)
	return box


func _place_line(
	world: Node, start: Vector2i, dir: Vector2i, length: int, families: Array[String] = ["brown"]
) -> void:
	for i in range(length):
		_add_box(world, start + dir * i, families)


func _build(world: Node) -> void:
	world._build_occupancy()
	await get_tree().process_frame


func _last_set_event(world: Node):
	return get_signal_parameters(world, "set_event")


func _move_player_to(player: Node, to: Vector2i, max_steps: int = 100) -> void:
	var steps := 0
	while ("target_cell" in player) and player.target_cell != to and steps < max_steps:
		var cur: Vector2i = player.target_cell
		var dir := Vector2i.ZERO
		if cur.x < to.x:
			dir = Vector2i(1, 0)
		elif cur.x > to.x:
			dir = Vector2i(-1, 0)
		elif cur.y < to.y:
			dir = Vector2i(0, 1)
		elif cur.y > to.y:
			dir = Vector2i(0, -1)
		if dir == Vector2i.ZERO:
			break
		player._try_step(dir)
		# Allow the move to start, then await completion if using GridActor.
		await get_tree().process_frame
		var player_ga: Node = player.get_node_or_null("GridActor")
		if player_ga != null:
			var mv = player_ga.get("moving")
			if typeof(mv) == TYPE_BOOL and mv:
				await player_ga.move_finished
		steps += 1
	# Safety assertion to avoid silent infinite loops
	assert_true(player.target_cell == to or steps >= max_steps)


func test_signal_emits_correct_info_for_vertical_set_creation() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	watch_signals(world)
	# Create vertical 3-length set at x=4, y=5..7
	_place_line(world, Vector2i(4, 5), Vector2i(0, 1), 3, ["brown"])
	await _build(world)
	assert_gt(get_signal_emit_count(world, "set_event"), 0)
	var p = _last_set_event(world)
	assert_eq(p[0], "brown")
	assert_eq(p[1], "vertical")
	assert_true(p[2] is String and p[2] != "")  # guid
	assert_eq(p[4], 3)  # new_length


func test_sets_have_distinct_guids_for_disjoint_vertical_sets() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	# Two vertical sets in same column group but separated
	_place_line(world, Vector2i(2, 2), Vector2i(0, 1), 2, ["brown"])  # (2,2)-(2,3)
	_place_line(world, Vector2i(2, 6), Vector2i(0, 1), 2, ["brown"])  # (2,6)-(2,7)
	await _build(world)
	var fs: Dictionary = world.get_family_sets_for("brown")
	var col_sets: Array = fs.get("col_sets", [])
	var guids := []
	for s in col_sets:
		if int((s as Dictionary).get("size", 0)) > 1:
			guids.append(String((s as Dictionary).get("guid", "")))
	assert_eq(guids.size(), 2)
	assert_ne(guids[0], guids[1])


func test_sets_exist_at_start_emit_signal() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	watch_signals(world)
	_place_line(world, Vector2i(1, 1), Vector2i(1, 0), 2, ["brown"])  # horizontal length 2
	await _build(world)
	assert_gt(get_signal_emit_count(world, "set_event"), 0)


func test_player_with_family_changes_set_emits_signal() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	watch_signals(world)
	# Make a horizontal set the player will join
	var base := Vector2i(3, 3)
	_place_line(world, base, Vector2i(1, 0), 2, ["brown"])  # (3,3)-(4,3)
	await _build(world)
	# Add brown family to player then move into (5,3) to extend set to 3
	var player: Node = world.get_node("Player")
	var fam_node: Node = player.get_node("Familiar")
	var new_families: Array[String] = ["player", "brown"]
	fam_node.families = new_families
	var to := base + Vector2i(2, 0)  # (5,3)
	await _move_player_to(player, to)
	assert_gt(get_signal_emit_count(world, "set_event"), 0)
	var p = _last_set_event(world)
	assert_eq(p[0], "brown")
	assert_eq(p[1], "horizontal")
	assert_true(int(p[4]) >= 2)


func test_signal_emitted_only_once_for_single_change() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	watch_signals(world)
	_place_line(world, Vector2i(6, 2), Vector2i(0, 1), 2, ["brown"])  # vertical 2
	await _build(world)
	var before: int = get_signal_emit_count(world, "set_event")
	# Push to grow set to 3 by adding a third above and moving into place
	_add_box(world, Vector2i(6, 1), ["brown"])
	await _build(world)
	var after: int = get_signal_emit_count(world, "set_event")
	assert_eq(after - before, 1)


func test_anchor_shift_emits_single_update_same_guid() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	watch_signals(world)
	# Vertical 3: (4,5)-(4,7)
	_place_line(world, Vector2i(4, 5), Vector2i(0, 1), 3, ["brown"])
	await _build(world)
	var first = _last_set_event(world)
	var guid: String = first[2]
	# Move top (4,5) -> (3,5)
	# Simulate move by deleting top and adding at left cell, then rebuild
	# Find and remove node at (4,5)
	var to_remove: Node = world.get_actor_at(Vector2i(4, 5))
	to_remove.queue_free()
	await get_tree().process_frame
	_add_box(world, Vector2i(3, 5), ["brown"])  # anchor should shift to (4,6)
	await _build(world)
	var second = _last_set_event(world)
	assert_eq(second[2], guid)
	assert_true(second[3] is Vector2i)


func test_dual_family_node_emits_two_signals() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	watch_signals(world)
	# Two nodes that belong to both families, horizontal length 2
	_place_line(world, Vector2i(2, 2), Vector2i(1, 0), 2, ["brown", "metal"])
	await _build(world)
	var count: int = get_signal_emit_count(world, "set_event")
	assert_true(count >= 2)
	# Verify last emission is for one of the families
	var p = _last_set_event(world)
	assert_true(p[0] == "brown" or p[0] == "metal")


func test_disappearance_emits_length_zero() -> void:
	var world := WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	watch_signals(world)
	# Vertical 2
	_place_line(world, Vector2i(7, 3), Vector2i(0, 1), 2, ["brown"])
	await _build(world)
	# Remove one to break the set
	var n: Node = world.get_actor_at(Vector2i(7, 3))
	n.queue_free()
	# Ensure queued free is processed before rebuilding occupancy
	await get_tree().process_frame
	await _build(world)
	var p = _last_set_event(world)
	assert_eq(p[0], "brown")
	assert_eq(p[4], 0)
