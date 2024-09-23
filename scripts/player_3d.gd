class_name Player3D extends CharacterBody3D

@export var current_state: STATE = STATE.WALKING: set = _set_current_state

func _set_current_state(new_state: STATE):
	if current_state != new_state:
		print("entering state: " + STATE.keys()[new_state])
		current_state = new_state

enum STATE {
	WALKING,
	JUMPING,
	FALLING,
	AIMING,
}

@export_range(1, 50.0, 0.1) var camera_zoom_speed := 40.0
## Controls how quickly the player accelerates and turns on the ground.
@export_range(1.0, 50.0, 0.1) var steering_factor := 20.0

@export_group("STATE WALKING")
## The maximum speed the player can move at in meters per second.
@export_range(3.0, 12.0, 0.1) var max_speed := 6.0
@export_range(1, 179, 1) var camera_fov:= 38
@export var camera_position := Vector3(0, 4.59, -10)
@export var camera_rotation := Vector3(deg_to_rad(-20), deg_to_rad(180), deg_to_rad(0))

@export_group("STATE JUMPING")
@export_range(3.0, 12.0, 0.1) var max_air_control_speed := 6.0
@export_range(1.0, 30.0, 0.1) var jump_velocity := 10.0

@export_group("STATE AIMING")
## The maximum speed the player can move at while aiming in meters per second.
@export_range(3.0, 12.0, 0.1) var max_speed_aiming := 3.0
@export_range(1, 179, 1) var camera_fov_aiming:= 18
@export var camera_position_aiming := Vector3(-0.995, 1.635, -10)

@onready var skin: SophiaSkin3D = %SophiaSkin
@onready var camera_anchor: Node3D = %CameraAnchor
@onready var camera_3D: Camera3D = %Camera3D
@onready var starting_camera_position = camera_3D.transform

func _physics_process(delta: float) -> void:
	# Handle State change ---
	if Input.is_action_pressed("aim"):
		current_state = STATE.AIMING
	elif Input.is_action_just_pressed("jump"):
		current_state = STATE.JUMPING
		velocity.y = jump_velocity
	elif is_on_floor():
		current_state = STATE.WALKING

	# Handle State processing ---
	match current_state:
		STATE.WALKING:
			_process_platforming(delta)
		STATE.AIMING:
			_process_aiming(delta)
		STATE.JUMPING:
			_process_jumping(delta)


func _process_platforming(delta:float) -> void:
	# Handle movement ---
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# inverse to account for positive player axes and rotate relative to camera forward
	var direction := Vector3(-input_vector.x, 0.0, -input_vector.y).rotated(Vector3(0, 1, 0), camera_anchor.rotation.y)
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

	# Handle camera ---
	camera_3D.position = camera_3D.position.lerp(camera_position, camera_zoom_speed * delta)
	camera_3D.fov = lerpf(camera_3D.fov, camera_fov, camera_zoom_speed * delta)

func _process_jumping(delta:float) -> void:
	# Handle movement ---
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# inverse to account for positive player axes and rotate relative to camera forward
	var direction := Vector3(-input_vector.x, 0.0, -input_vector.y).rotated(Vector3(0, 1, 0), camera_anchor.rotation.y)
	var desired_ground_velocity := max_air_control_speed * direction
	var steering_vector := desired_ground_velocity - velocity
	steering_vector.y = 0.0
	# We limit the steering amount to ensure the velocity can never overshoots the desired velocity.
	var steering_amount: float = min(steering_factor * delta, 1.0)
	velocity += steering_vector * steering_amount

	const GRAVITY := 40.0 * Vector3.DOWN
	velocity += GRAVITY * delta
	move_and_slide()

	print("velocity: " + str(velocity))

	# TODO: Extract movement into it's own function to be reused
	# TODO: Adjust look_at such that we always face relative to the ground (eventually gravity when platforms can angle)

	# Handle skin animation ---
	skin.jump()

func _process_aiming(delta: float) -> void:
	# Handle movement ---
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# inverse to account for positive player axes and rotate relative to camera forward
	var direction := Vector3(-input_vector.x, 0.0, -input_vector.y).rotated(Vector3(0, 1, 0), camera_anchor.rotation.y)
	var desired_ground_velocity := max_speed_aiming * direction
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

	var look_at_direction = Vector3(0, 0, -1).rotated(Vector3(0, 1, 0), camera_anchor.rotation.y) + global_position
	if not (look_at_direction - global_position).is_zero_approx():
		skin.look_at(look_at_direction)

	# follow player movement vector, not skin's
	%DebugLookAtPoint.global_position = Vector3(0, 0, 1).rotated(Vector3(0, 1, 0), camera_anchor.rotation.y) + global_position

	# Handle Camera ---
	camera_3D.position = camera_3D.position.lerp(camera_position_aiming, camera_zoom_speed * delta)
	camera_3D.fov = lerpf(camera_3D.fov, camera_fov_aiming, camera_zoom_speed * delta)
