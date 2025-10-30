extends Node2D

@export var grid_size := Vector2i(8, 5)

var occupancy := {}  # Dictionary keyed by Vector2i -> Node

@onready var grid: Node = get_node("/root/Grid")


func _ready() -> void:
	# Defer initialization to ensure all children finished their _ready and groups are set
	call_deferred("_initialize_grid")


func _initialize_grid() -> void:
	grid.grid_size = grid_size
	grid.origin = position
	_snap_actors_to_grid()
	_center_player()
	_build_occupancy()
	_apply_camera_limits()


## Clamp the player camera to the playable area derived from grid
func _apply_camera_limits() -> void:
	var cam: Camera2D = get_node_or_null("Player/Camera2D")
	if cam == null:
		return
	var w: int = grid.grid_size.x * grid.CELL_SIZE
	var h: int = grid.grid_size.y * grid.CELL_SIZE
	cam.limit_left = int(grid.origin.x)
	cam.limit_top = int(grid.origin.y)
	cam.limit_right = int(grid.origin.x) + w
	cam.limit_bottom = int(grid.origin.y) + h
	cam.enabled = true


func _build_occupancy() -> void:
	occupancy.clear()
	for child in get_children():
		if child.is_in_group("grid_actor"):
			var cell: Vector2i = grid.world_to_cell(child.position)
			if grid.in_bounds(cell):
				occupancy[cell] = child


func _snap_actors_to_grid() -> void:
	for child in get_children():
		if child.is_in_group("grid_actor"):
			var cell: Vector2i = grid.world_to_cell(child.position)
			cell = _clamp_cell(cell)
			child.position = grid.cell_to_world_center(cell)


func _center_player() -> void:
	var player := get_node_or_null("Player")
	if player:
		var center_cell: Vector2i = Vector2i(grid.grid_size.x / 2, grid.grid_size.y / 2)
		player.position = grid.cell_to_world_center(center_cell)
		# Keep player's internal cell in sync
		if "target_cell" in player:
			player.target_cell = center_cell


func _clamp_cell(c: Vector2i) -> Vector2i:
	return Vector2i(clamp(c.x, 0, grid.grid_size.x - 1), clamp(c.y, 0, grid.grid_size.y - 1))


func is_cell_free(c: Vector2i) -> bool:
	return grid.in_bounds(c) and not occupancy.has(c)


func get_box_at(c: Vector2i) -> Node:
	var node: Node = occupancy.get(c) as Node
	if node and node.is_in_group("box"):
		return node
	return null


func move_actor(from: Vector2i, to: Vector2i, node: Node) -> void:
	if occupancy.has(from):
		occupancy.erase(from)
	occupancy[to] = node
