extends StaticBody2D


var isBeingPushed := false
var pushDirection := Vector2.ZERO
var pushSpeed := 0.0
@export var friction := 0

func _physics_process(delta):
	if isBeingPushed:
		var collision = move_and_collide(pushDirection * pushSpeed * delta)
		if collision:
			stopPushing()
	else:
		pushSpeed *= friction
		if pushSpeed > 0.1:
			move_and_collide(pushDirection * pushSpeed * delta)
		else:
			pushSpeed = 0.0

func startPushing(dir: Vector2, force: float):
	pushDirection = dir
	pushSpeed = force
	isBeingPushed = true

func stopPushing():
	isBeingPushed = false
