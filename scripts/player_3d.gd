class_name Player3D extends CharacterBody3D

@onready var skin: SophiaSkin3D = %SophiaSkin

## The maximum speed the player can move at in meters per second.
@export_range(3.0, 12.0, 0.1) var max_speed := 6.0
## The maximum speed the player can move at while aiming in meters per second.
@export_range(3.0, 12.0, 0.1) var max_speed_aiming := 3.0
## Controls how quickly the player accelerates and turns on the ground.
@export_range(1.0, 50.0, 0.1) var steering_factor := 20.0

@export var current_state: STATE = STATE.PLATFORMING: set = _set_current_state

func _set_current_state(new_state: STATE):
	if current_state != new_state:
		current_state = new_state

enum STATE {
	PLATFORMING,
	AIMING,
}

func _physics_process(delta: float) -> void:
	# Handle State change ---
	if Input.is_action_pressed("aim"):
		current_state = STATE.AIMING
	else:
		current_state = STATE.PLATFORMING

	# Handle State processing ---
	match current_state:
		STATE.PLATFORMING:
			_process_platforming(delta)
		STATE.AIMING:
			_process_aiming(delta)


func _process_platforming(delta:float) -> void:
	# Handle movement ---
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(-input_vector.x, 0.0, -input_vector.y) # inverse to account for positive player axes
	var desired_ground_velocity := max_speed * direction
	var steering_vector := desired_ground_velocity - velocity
	steering_vector.y = 0.0
	# We limit the steering amount to ensure the velocity can never overshoots the desired velocity.
	var steering_amount: float = min(steering_factor * delta, 1.0)
	velocity += steering_vector * steering_amount

	const GRAVITY := 40.0 * Vector3.DOWN
	velocity += GRAVITY * delta
	move_and_slide()

	# Handle skin animation ---
	if is_on_floor() and not direction.is_zero_approx():
		skin.move()
	else:
		skin.idle()

	# multiply by inverse x and y to account for skin's local axes.
	# Add position to make everything relative to where the player is
	var look_at_direction = (velocity * Vector3(-1, 1 , -1)).normalized() + global_position
	if not (look_at_direction - global_position).is_zero_approx():
		skin.look_at(look_at_direction)

	# follow player movement vector, not skin's
	%DebugLookAtPoint.global_position = velocity.normalized() + global_position

func _process_aiming(delta: float) -> void:
	# Handle aiming ---
	print("aiming")

	# Handle movement ---
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(-input_vector.x, 0.0, -input_vector.y) # inverse to account for positive player axes
	var desired_ground_velocity := max_speed_aiming * direction
	var steering_vector := desired_ground_velocity - velocity
	steering_vector.y = 0.0
	# We limit the steering amount to ensure the velocity can never overshoots the desired velocity.
	var steering_amount: float = min(steering_factor * delta, 1.0)
	velocity += steering_vector * steering_amount

	const GRAVITY := 40.0 * Vector3.DOWN
	velocity += GRAVITY * delta
	move_and_slide()

	var look_at_direction = Vector3(0, 0, -1) + global_position # TODO: when camera is tied to mouse, have this vector match forward for mouse
	if not (look_at_direction - global_position).is_zero_approx():
		skin.look_at(look_at_direction)

	# follow player movement vector, not skin's
	%DebugLookAtPoint.global_position = Vector3(0, 0, 1) + global_position
