extends State

class_name LedgeGrabState

var stateName : String = "LedgeGrab"

var cR : CharacterBody3D
var ledgePosition : Vector3
var ledgeNormal : Vector3
var climbTimer : float = 0.0
var climbStartPosition : Vector3
var climbTargetPosition : Vector3
var climbDuration : float = 0.0
static var last_exit_time : float = 0.0

const LEDGE_GRAB_COOLDOWN: float = 1.0

func enter(charRef : CharacterBody3D):
	cR = charRef
	verifications()
	
func verifications():
	cR.velocity = Vector3.ZERO
	cR.floor_snap_length = 0.0
	climbTimer = 0.0
	
func physics_update(delta : float):
	applies(delta)
	# Only process inputs if the player is active
	if cR.is_active:
		inputManagement()
	# Don't call move() for inactive players
	# This is intentional - we want ledge-grabbing players to stay fixed
	
func applies(delta : float):
	# Lock player in position while hanging - for BOTH active and inactive players
	cR.velocity = Vector3.ZERO
	cR.ledgeHeightDetector.force_raycast_update()
	
	# Align player to ledge
	if ledgePosition != Vector3.ZERO:
		var targetPos = cR.ledgeHeightDetector.to_global(cR.ledgeHeightDetector.target_position)
		cR.global_position = cR.global_position.lerp(targetPos, cR.ledgePositionAdjustSpeed * delta)
		
	# Handle the climb timer if climbing
	if climbTimer > 0:
		# Calculate interpolation progress (0 to 1)
		var progress = 1.0 - (climbTimer / climbDuration)
		# Linearly interpolate position
		cR.global_position = climbStartPosition.lerp(climbTargetPosition, progress)
		# Decrement timer
		climbTimer -= delta

		if climbTimer <= 0:
			# Ensure final position is exact
			cR.global_position = climbTargetPosition
			transitioned.emit(self, "IdleState")
	
func inputManagement():
	# This function is ONLY called for active players now
	if Input.is_action_just_pressed(cR.jumpAction):
		# Jump away from ledge
		cR.velocity.y = cR.jumpVelocity * 0.8
		cR.velocity += -ledgeNormal * cR.ledgeJumpAwayForce
		exit()  # Explicitly call exit before transitioning
		transitioned.emit(self, "InairState")
	
	if Input.is_action_just_pressed(cR.moveForwardAction) and climbTimer <= 0:
		# Initialize climb parameters
		climbStartPosition = cR.global_position
		climbTargetPosition = cR.ledgeHeightDetector.to_global(cR.ledgeHeightDetector.target_position) + Vector3(0,1,0)
		climbDuration = cR.ledgeClimbDuration
		climbTimer = climbDuration  # Start the timer
	
	if Input.is_action_just_pressed(cR.crouchAction):
		# Let go of ledge
		transitioned.emit(self, "InairState")
	
func move(delta : float):
	# This function is no longer needed for LedgeGrabState
	# since we want players to be completely stationary
	pass
	
func exit():
	# Record the time when exiting the state
	last_exit_time = Time.get_ticks_msec() / 1000.0

static func can_grab_ledge() -> bool:
	return Time.get_ticks_msec() / 1000.0 - last_exit_time >= LEDGE_GRAB_COOLDOWN
