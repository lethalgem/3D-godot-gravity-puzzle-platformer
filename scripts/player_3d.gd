class_name Player3D extends CharacterBody3D

@onready var skin: SophiaSkin3D = %SophiaSkin

## The maximum speed the player can move at in meters per second.
@export_range(3.0, 12.0, 0.1) var max_speed := 6.0
## Controls how quickly the player accelerates and turns on the ground.
@export_range(1.0, 50.0, 0.1) var steering_factor := 20.0

func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var desired_ground_velocity := max_speed * direction
	var steering_vector := desired_ground_velocity - velocity
	steering_vector.y = 0.0
	# We limit the steering amount to ensure the velocity can never overshoots the
	# desired velocity.
	var steering_amount: float = min(steering_factor * delta, 1.0)
	velocity += steering_vector * steering_amount

	const GRAVITY := 40.0 * Vector3.DOWN
	velocity += GRAVITY * delta
	move_and_slide()

	if is_on_floor() and not direction.is_zero_approx():
		skin.move()
	else:
		skin.idle()

	# multiply by inverse x and y to account for skin's local axes.
	# Add position to make everything relative to where the player is
	var look_at_direction = (velocity * Vector3(-1, 1 , -1)).normalized() + global_position
	skin.look_at(look_at_direction)

	# multiply by inverse x and y to account for skin's axes
	%DebugLookAtPoint.global_position = look_at_direction # TODO: Put this in front of the character. Currently moves behind and is a good opportunity to make sure I understand simple vector math
