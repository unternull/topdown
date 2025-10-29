extends CharacterBody2D

const SPEED = 300.0

@export var pushForce := 100.0

var lastDirection = Vector2.ZERO
var staysBack = false
var isPushing = false
var currentPushedItem: CollisionObject2D = null

enum PlayerState {
	WalkingDown,
	WalkingUp,
	WalkingRight,
	WalkingLeft,
	IdleFront,
	IdleBack,
}


func _physics_process(_delta: float) -> void:
	var inputDir = getInputDirection()
	if inputDir == Vector2.UP:
		staysBack = true
	if inputDir == Vector2.DOWN:
		staysBack = false
	
	var isDirectionChanged = lastDirection != inputDir
	
	lastDirection = inputDir
	
	velocity = inputDir * SPEED
	move_and_slide()
	
	if isDirectionChanged:
		stopPushingItems()

	if inputDir != Vector2.ZERO:
		checkAndPushItems(inputDir)
	else:
		stopPushingItems()


func checkAndPushItems(inputDir: Vector2):
	if isPushing:
		return

	$RayCast.target_position = inputDir * 30
	$RayCast.force_raycast_update()
	if $RayCast.is_colliding():
		var collider: CollisionObject2D = $RayCast.get_collider()
		if collider and collider.has_method("startPushing"):
			if not isPushing:
				collider.startPushing(inputDir, pushForce)
				isPushing = true
				currentPushedItem = collider

func stopPushingItems():
	if isPushing:
		if currentPushedItem and currentPushedItem.has_method("stopPushing"):
			currentPushedItem.stopPushing()
			isPushing = false

func _process(delta: float) -> void:
	var playerState = directionToPlayerState(lastDirection)

	match playerState:
		PlayerState.WalkingUp:
			if $PlayerBody.animation != 'WalkingUp':
				$PlayerBody.animation = 'WalkingUp'
		PlayerState.WalkingDown:
			if $PlayerBody.animation != 'WalkingDown':
				$PlayerBody.animation = 'WalkingDown'
		PlayerState.WalkingLeft:
			if $PlayerBody.animation != 'WalkingSide':
				$PlayerBody.animation = 'WalkingSide'
				$PlayerBody.flip_h = true
		PlayerState.WalkingRight:
			if $PlayerBody.animation != 'WalkingSide':
				$PlayerBody.animation = 'WalkingSide'
				$PlayerBody.flip_h = false
		PlayerState.IdleFront:
			if $PlayerBody.animation != 'IdleFront':
				$PlayerBody.animation = 'IdleFront'
		PlayerState.IdleBack:
			if $PlayerBody.animation != 'IdleBack':
				$PlayerBody.animation = 'IdleBack'


func getInputDirection() -> Vector2:
	var rawInput = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var inputDir = Vector2.ZERO
	if abs(rawInput.x) > abs(rawInput.y):
		inputDir.x = sign(rawInput.x)
	else:
		inputDir.y = sign(rawInput.y)
	return inputDir


func directionToPlayerState(dir: Vector2) -> PlayerState:
	if dir.y > 0:
		return PlayerState.WalkingDown
	if dir.y < 0:
		return PlayerState.WalkingUp
	if dir.x > 0:
		return PlayerState.WalkingRight
	if dir.x < 0:
		return PlayerState.WalkingLeft
	if staysBack:
		return PlayerState.IdleBack
		
	return PlayerState.IdleFront

	
