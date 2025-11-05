extends CharacterBody2D

enum PlayerState {
	WALKING_DOWN,
	WALKING_UP,
	WALKING_RIGHT,
	WALKING_LEFT,
	IDLE_FRONT,
	IDLE_BACK,
}

const WALK_SPEED := 480.0

@export var has_shadow := false

var last_direction := Vector2.ZERO
var stays_back := false

var moving := false
var target_cell := Vector2i.ZERO
var held_dir := Vector2i.ZERO
var pushing_animation_active := false
@onready var grid_actor: Node = get_node_or_null("GridActor")
@onready var player_body: AnimatedSprite2D = get_node("Visual/PlayerBody") as AnimatedSprite2D

@onready var grid: Node = get_node("/root/Grid")


func _ready() -> void:
	add_to_group("grid_actor")
	add_to_group("player")
	position = grid.snap_to_cell(position)
	target_cell = grid.world_to_cell(position)
	# Hook into GridActor lifecycle to reflect actual move state/direction
	if grid_actor != null:
		if grid_actor.has_signal("move_started"):
			(grid_actor as Object).connect("move_started", _on_grid_move_started)
		if grid_actor.has_signal("move_finished"):
			(grid_actor as Object).connect("move_finished", _on_grid_move_finished)
	# Listen to pushing state to drive animation while pushing a box
	var p: Node = get_node_or_null("Pushing")
	if p != null:
		if p.has_signal("push_started"):
			p.connect("push_started", _on_push_started)
		if p.has_signal("push_animation_release"):
			p.connect("push_animation_release", _on_push_release)


func _physics_process(_delta: float) -> void:
	held_dir = _input_dir_to_cardinal()
	if held_dir == Vector2i(0, -1):
		stays_back = true
	if held_dir == Vector2i(0, 1):
		stays_back = false

	# Allow reversing mid-move for responsiveness
	if grid_actor != null:
		var mv = (grid_actor as Object).get("moving")
		if typeof(mv) == TYPE_BOOL and mv and held_dir != Vector2i.ZERO:
			# If opposite direction is held, reverse back to origin immediately
			var cur_dir := Vector2i(sign(last_direction.x), sign(last_direction.y))
			if held_dir == -cur_dir:
				var world := get_parent()
				if world != null and (grid_actor as Object).has_method("reverse_to_origin"):
					(grid_actor as Object).call("reverse_to_origin", world)
				last_direction = Vector2(held_dir.x, held_dir.y)

	if not moving and held_dir != Vector2i.ZERO:
		_try_step(held_dir)

	# Update facing from input only when not moving; during a tween we preserve move direction
	if not moving:
		last_direction = Vector2(held_dir.x, held_dir.y)


func _process(_delta: float) -> void:
	var is_actually_moving := moving or pushing_animation_active
	if not is_actually_moving and grid_actor != null:
		var mv = (grid_actor as Object).get("moving")
		if typeof(mv) == TYPE_BOOL and mv:
			is_actually_moving = true
	var player_state = direction_to_player_state(last_direction)
	if is_actually_moving:
		match player_state:
			PlayerState.WALKING_UP:
				if player_body.animation != "WalkingUp":
					player_body.animation = "WalkingUp"
			PlayerState.WALKING_DOWN:
				if player_body.animation != "WalkingDown":
					player_body.animation = "WalkingDown"
			PlayerState.WALKING_LEFT:
				if player_body.animation != "WalkingSide":
					player_body.animation = "WalkingSide"
				# Always update flip to ensure correct facing even when animation name doesn't change
				player_body.flip_h = true
			PlayerState.WALKING_RIGHT:
				if player_body.animation != "WalkingSide":
					player_body.animation = "WalkingSide"
				# Always update flip to ensure correct facing even when animation name doesn't change
				player_body.flip_h = false
	else:
		if stays_back:
			if player_body.animation != "IdleBack":
				player_body.animation = "IdleBack"
		else:
			if player_body.animation != "IdleFront":
				player_body.animation = "IdleFront"


func _on_grid_move_started(from: Vector2i, to: Vector2i) -> void:
	pushing_animation_active = false
	moving = true
	var d := to - from
	if d != Vector2i.ZERO:
		last_direction = Vector2(sign(d.x), sign(d.y))


func _on_push_started(dir: Vector2i) -> void:
	pushing_animation_active = true
	if dir != Vector2i.ZERO:
		last_direction = Vector2(sign(dir.x), sign(dir.y))


func _on_push_release() -> void:
	pushing_animation_active = false


func _input_dir_to_cardinal() -> Vector2i:
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if abs(raw.x) > abs(raw.y):
		return Vector2i(sign(raw.x), 0)
	if abs(raw.y) > 0.0:
		return Vector2i(0, sign(raw.y))
	return Vector2i.ZERO


func _try_step(dir: Vector2i) -> void:
	var world := get_parent()
	var from := target_cell
	var to := from + dir
	if not grid.in_bounds(to):
		return

	# Delegate pushing logic to Pushing node if present
	var pushing: Node = get_node_or_null("Pushing")
	if pushing and pushing.has_method("try_push") and pushing.try_push(dir):
		# When pushing succeeds, wait for the path to clear; we'll try again on next tick.
		return
	if not (world != null and world.has_method("is_cell_free") and world.is_cell_free(to)):
		return
	# Grid-authoritative move via GridActor: reserve, tween visuals, update occupancy on finish
	if grid_actor != null and grid_actor.has_method("move_to"):
		var started: bool = grid_actor.move_to(to, world)
		if started:
			moving = true


func _on_grid_move_finished(to: Vector2i) -> void:
	moving = false
	target_cell = to
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
