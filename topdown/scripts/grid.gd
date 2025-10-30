extends Node

# Single source of truth for grid settings and helpers

const CELL_SIZE := 144

var origin: Vector2 = Vector2.ZERO
var grid_size: Vector2i = Vector2i(8, 5)

func world_to_cell(p: Vector2) -> Vector2i:
	var local := p - origin
	return Vector2i(floor(local.x / CELL_SIZE), floor(local.y / CELL_SIZE))

func cell_to_world_center(c: Vector2i) -> Vector2:
	return origin + Vector2((c.x + 0.5) * CELL_SIZE, (c.y + 0.5) * CELL_SIZE)

func snap_to_cell(p: Vector2) -> Vector2:
	return cell_to_world_center(world_to_cell(p))

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid_size.x and c.y < grid_size.y
