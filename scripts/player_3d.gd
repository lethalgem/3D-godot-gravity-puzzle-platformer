class_name Player3D extends CharacterBody3D

signal targeting_csg_movable(csg_movable: CSGMovable)

@export var current_state: State = State.WALKING: set = _set_current_state

func _set_current_state(new_state: State):
	if current_state != new_state:
		print("entering state: " + State.keys()[new_state])
		current_state = new_state

		# TODO: Change state machine to have enter and exit
		if current_state != State.AIMING:
			targeting_csg_movable.emit(null)

enum State {
	WALKING,
	JUMPING,
	FALLING,
	AIMING,
}

@export_range(1, 50.0, 0.1) var camera_zoom_speed := 40.0
## Controls how quickly the player accelerates and turns on the ground.
@export_range(1.0, 50.0, 0.1) var steering_factor := 20.0

@export_group("State WALKING")
## The maximum speed the player can move at in meters per second.
@export_range(3.0, 12.0, 0.1) var max_speed := 6.0
@export_range(1, 179, 1) var camera_fov:= 45
@export var camera_position := Vector3(0, 4.59, -10)
@export var camera_rotation := Vector3(deg_to_rad(-20), deg_to_rad(180), deg_to_rad(0))

@export_group("State JUMPING")
@export_range(3.0, 12.0, 0.1) var max_air_control_speed := 6.0
@export_range(1.0, 30.0, 0.1) var jump_velocity := 10.0

@export_group("State AIMING")
## The maximum speed the player can move at while aiming in meters per second.
@export_range(3.0, 12.0, 0.1) var max_speed_aiming := 3.0
@export_range(1, 179, 1) var camera_fov_aiming:= 18
@export var camera_position_aiming := Vector3(-0.995, 4.16, -10)

@onready var skin: SophiaSkin3D = %SophiaSkin
@onready var camera_anchor: Node3D = %CameraAnchor
@onready var camera_3D: Camera3D = %Camera3D
@onready var starting_camera_position = camera_3D.transform
@onready var debug_state_label = %DebugStateLabel3D
@onready var debug_look_at_point = %DebugLookAtPoint
@onready var debug_aim_raycast_begin_point = %DebugAimRaycastBeginPoint
@onready var debug_aim_raycast_end_point = %DebugAimRaycastEndPoint

func _ready() -> void:
	var state_machine := Player.StateMachine.new()
	add_child(state_machine)

	var idle := Player.StateIdle.new(self)
	var walk := Player.StateWalk.new(self)
	var jump := Player.StateJump.new(self)
	var fall := Player.StateFall.new(self)
	var aim := Player.StateAim.new(self)

	state_machine.transitions = {
		idle: {
			Player.Events.PLAYER_STARTED_MOVING: walk,
			Player.Events.PLAYER_JUMPED: jump,
			Player.Events.PLAYER_STARTED_AIMING: aim,
		},
		walk: {
			Player.Events.PLAYER_STOPPED_MOVING: idle,
			Player.Events.PLAYER_JUMPED: jump,
			Player.Events.PLAYER_STARTED_AIMING: aim,
		},
		jump: {
			Player.Events.PLAYER_STARTED_FALLING: fall,
		},
		fall: {
			Player.Events.PLAYER_LANDED: idle,
		},
		aim: {
			Player.Events.PLAYER_STOPPED_AIMING: idle,
		}
	}

	state_machine.activate(idle)
	state_machine.is_debugging = true

func _handle_movement(delta: float) -> Vector3:
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
	#move_and_slide()

	return direction

func _physics_process(delta: float) -> void:

	pass

	# TODO: will have to make slightly more complex to handle transitions
	# Ex. need to handle exiting the aiming state

	## Handle State change ---
	#if Input.is_action_pressed("aim"):
		#current_state = State.AIMING
	#elif Input.is_action_just_pressed("jump") and is_on_floor():
		#current_state = State.JUMPING
		#velocity.y = jump_velocity
	#elif is_on_floor():
		#current_state = State.WALKING
#
	## Handle State processing ---
	#match current_state:
		#State.WALKING:
			#_process_platforming(delta)
		#State.AIMING:
			#_process_aiming(delta)
		#State.JUMPING:
			#_process_jumping(delta)


func _process_platforming(delta:float) -> void:
	var direction = _handle_movement(delta)

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
	var _direction = _handle_movement(delta)

	# TODO: Adjust look_at such that we always face relative to the ground (eventually gravity when platforms can angle)

	# Handle skin animation ---
	if not is_on_floor() and velocity.y >= 0:
		skin.jump()
	elif not is_on_floor() and velocity.y < 0:
		skin.fall()

	# multiply by inverse x and y to account for skin's local axes. Ignore y velocity so the skin stays up right
	# Add position to make everything relative to where the player is
	var look_at_direction = (velocity * Vector3(-1, 0, -1)).normalized() + global_position
	if not (look_at_direction - global_position).is_zero_approx():
		skin.look_at(look_at_direction)

	# follow player movement vector, not skin's
	%DebugLookAtPoint.global_position = Vector3(0, 0, 1).rotated(Vector3(0, 1, 0), camera_anchor.rotation.y) + global_position

	# TODO: When state machine handles transitions, smooth increase fov for jumping to make platforming easier
	#camera_3D.fov = lerpf(camera_3D.fov, 45, camera_zoom_speed * delta)

func _process_aiming(delta: float) -> void:
	var direction = _handle_movement(delta)

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

	# Handle highlighting ---
	# Cast a ray from the camera to a set length. If we hit something, check to make sure it's a platform we can move
	# and highlight it by changing its state
	var space_state := get_world_3d().direct_space_state
	# Adjust the origin to be the same distance from the camera as the player is
	var origin: Vector3 = camera_3D.global_position + (camera_3D.project_ray_normal(camera_3D.get_viewport().size / 2.0) * abs(camera_3D.position.z))
	var collision_detection_length := 100 # meters
	var end := origin + (camera_3D.project_ray_normal(camera_3D.get_viewport().size / 2.0) * collision_detection_length)
	%RayCastBeginDebugPoint.global_position = origin
	%RayCastEndDebugPoint.global_position = end

	var collision := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end))
	if not collision.is_empty():
		print(collision)
		%RayCastEndDebugPoint.global_position = collision.position
		if collision.collider is CSGMovable:
			targeting_csg_movable.emit(collision.collider)
		else:
			targeting_csg_movable.emit(null)
	else:
		targeting_csg_movable.emit(null)
