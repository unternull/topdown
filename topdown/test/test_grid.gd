extends "res://addons/gut/test.gd"


func test_grid_roundtrip() -> void:
	Grid.origin = Vector2.ZERO
	var cell: Vector2i = Vector2i(2, 3)
	var world: Vector2 = Grid.cell_to_world_center(cell)
	var back: Vector2i = Grid.world_to_cell(world)
	assert_eq(back, cell)


func test_snap_to_cell_center() -> void:
	var p: Vector2 = Vector2(100.0, 200.0)
	var snapped: Vector2 = Grid.snap_to_cell(p)
	var cell: Vector2i = Grid.world_to_cell(p)
	assert_eq(snapped, Grid.cell_to_world_center(cell))
