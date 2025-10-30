extends CharacterBody2D

const WALK_SPEED := 480.0

enum PlayerState {
	WALKING_DOWN,
	WALKING_UP,
	WALKING_RIGHT,
	WALKING_LEFT,
	IDLE_FRONT,
	IDLE_BACK,
}

@export var has_shadow := true

var last_direction := Vector2.ZERO
var stays_back := false

var moving := false
var target_cell := Vector2i.ZERO
var held_dir := Vector2i.ZERO
var tween: Tween

@onready var grid: Node = get_node("/root/Grid")


func _ready() -> void:
	add_to_group("grid_actor")
	add_to_group("player")
	position = grid.snap_to_cell(position)
	target_cell = grid.world_to_cell(position)


func _physics_process(_delta: float) -> void:
	held_dir = _input_dir_to_cardinal()
	if held_dir == Vector2i(0, -1):
		stays_back = true
	if held_dir == Vector2i(0, 1):
		stays_back = false

	if not moving and held_dir != Vector2i.ZERO:
		_try_step(held_dir)

	last_direction = Vector2(held_dir.x, held_dir.y)


func _process(_delta: float) -> void:
	var player_state = direction_to_player_state(last_direction)
	match player_state:
		PlayerState.WALKING_UP:
			if $PlayerBody.animation != "WalkingUp":
				$PlayerBody.animation = "WalkingUp"
		PlayerState.WALKING_DOWN:
			if $PlayerBody.animation != "WalkingDown":
				$PlayerBody.animation = "WalkingDown"
		PlayerState.WALKING_LEFT:
			if $PlayerBody.animation != "WalkingSide":
				$PlayerBody.animation = "WalkingSide"
				$PlayerBody.flip_h = true
		PlayerState.WALKING_RIGHT:
			if $PlayerBody.animation != "WalkingSide":
				$PlayerBody.animation = "WalkingSide"
				$PlayerBody.flip_h = false
		PlayerState.IDLE_FRONT:
			if $PlayerBody.animation != "IdleFront":
				$PlayerBody.animation = "IdleFront"
		PlayerState.IDLE_BACK:
			if $PlayerBody.animation != "IdleBack":
				$PlayerBody.animation = "IdleBack"


func _input_dir_to_cardinal() -> Vector2i:
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if abs(raw.x) > abs(raw.y):
		return Vector2i(sign(raw.x), 0)
	if abs(raw.y) > 0.0:
		return Vector2i(0, sign(raw.y))
	return Vector2i.ZERO


func _try_step(dir: Vector2i) -> void:
	var world := get_tree().current_scene
	var from := target_cell
	var to := from + dir
	if not grid.in_bounds(to):
		return

	# If a box is in front
	var box: Node = null
	if "get_box_at" in world:
		box = world.get_box_at(to)
	if box:
		var box_to := to + dir
		if not (("is_cell_free" in world) and world.is_cell_free(box_to)):
			return
		_start_move(from, to)
		if "move_to_cell" in box:
			box.move_to_cell(box_to, world)
	else:
		if not (("is_cell_free" in world) and world.is_cell_free(to)):
			return
		_start_move(from, to)


func _start_move(from: Vector2i, to: Vector2i) -> void:
	var world := get_tree().current_scene
	if "move_actor" in world:
		world.move_actor(from, to, self)
	target_cell = to
	moving = true
	var dst: Vector2 = grid.cell_to_world_center(to)
	if tween and tween.is_valid():
		tween.kill()
	var dist := position.distance_to(dst)
	var dur := dist / WALK_SPEED
	tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", dst, max(0.01, dur))
	tween.finished.connect(_on_step_finished)


func _on_step_finished() -> void:
	moving = false
	if held_dir != Vector2i.ZERO:
		_try_step(held_dir)


func direction_to_player_state(dir: Vector2) -> PlayerState:
	if dir.y > 0:
		return PlayerState.WALKING_DOWN
	if dir.y < 0:
		return PlayerState.WALKING_UP
	if dir.x > 0:
		return PlayerState.WALKING_RIGHT
	if dir.x < 0:
		return PlayerState.WALKING_LEFT
	if stays_back:
		return PlayerState.IDLE_BACK
	return PlayerState.IDLE_FRONT
