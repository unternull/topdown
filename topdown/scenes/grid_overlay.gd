extends Node2D

var line_color := Color(1, 1, 1, 0.2)

@onready var grid: Node = get_node("/root/Grid")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("show_grid"):
		visible = not visible
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var grid_dimensions: Vector2i = grid.grid_size
	var cell_size: int = grid.CELL_SIZE
	for x in range(grid_dimensions.x + 1):
		var grid_line_x: float = grid.origin.x + float(x * cell_size)
		draw_line(
			Vector2(grid_line_x, grid.origin.y),
			Vector2(grid_line_x, grid.origin.y + float(grid_dimensions.y * cell_size)),
			line_color,
			1.0
		)
	for y in range(grid_dimensions.y + 1):
		var grid_line_y: float = grid.origin.y + float(y * cell_size)
		draw_line(
			Vector2(grid.origin.x, grid_line_y),
			Vector2(grid.origin.x + float(grid_dimensions.x * cell_size), grid_line_y),
			line_color,
			1.0
		)
