class_name Player extends RefCounted

enum Events {
	NONE,
	FINISHED,
	PLAYER_STARTED_MOVING,
	PLAYER_STOPPED_MOVING,
	PLAYER_JUMPED,
	PLAYER_LANDED,
	PLAYER_STARTED_AIMING,
	PLAYER_STOPPED_AIMING,
}


class Blackboard extends RefCounted:
	# shared static vars go here
	# ex. static var camera_anchor: Camera3D = null
	pass


class State extends RefCounted:

	## Emitted when the state completes and the state machine should transition to the next state.
	## Use this for time-based states or moves that have a fixed duration.
	signal finished

	## Display name of the state, for debugging purposes.
	var name := "State"
	## Reference to the player that the state controls.
	var player: Player3D = null


	func _init(init_name: String, init_player: Player3D) -> void:
		name = init_name
		player = init_player


	## Called by the state machine on the engine's physics update tick.
	## Returns an event that the state machine can use to transition to the next state.
	## If there is no event, return [constant AI.Events.None]
	func update(_delta: float) -> Events:
		return Events.NONE


	## Called by the state machine upon changing the active state. The `data` parameter
	## is a dictionary with arbitrary data the state can use to initialize itself.
	func enter() -> void:
		pass


	## Called by the state machine before changing the active state. Use this function
	## to clean up the state.
	func exit() -> void:
		pass


class StateMachine extends Node:

	var transitions := {}: set = set_transitions
	var current_state: State
	var is_debugging := false: set = set_is_debugging

	func _init() -> void:
		set_physics_process(false)

	func set_transitions(new_transitions: Dictionary) -> void:
		transitions = new_transitions
		if OS.is_debug_build():
			for state: State in transitions:
				assert(
					state is State,
					"Invalid state in the transitions dictionary. " +
					"Expected a State object, but got " + str(state)
				)
				for event: Events in transitions[state]:
					assert(
						event is Events,
						"Invalid event in the transitions dictionary. " +
						"Expected an Events object, but got " + str(event)
					)
					assert(
						transitions[state][event] is State,
						"Invalid state in the transitions dictionary. " +
						"Expected a State object, but got " +
						str(transitions[state][event])
					)

	func set_is_debugging(new_value: bool) -> void:
		is_debugging = new_value
		if (
			current_state != null and
			current_state.player != null and
			current_state.player.debug_state_label != null
		):
			current_state.player.debug_state_label.text = current_state.name
			current_state.player.debug_state_label.visible = is_debugging
			current_state.player.debug_look_at_point.visible = is_debugging
			current_state.player.debug_aim_raycast_begin_point.visible = is_debugging
			current_state.player.debug_aim_raycast_end_point.visible = is_debugging

	func activate(initial_state: State = null) -> void:
		if initial_state != null:
			current_state = initial_state
		assert(
			current_state != null,
			"Activated the state machine but the state variable is null. " +
			"Please assign a starting state to the state machine."
		)
		current_state.finished.connect(_on_state_finished.bind(current_state))
		current_state.enter()
		set_physics_process(true)

	func _physics_process(delta: float) -> void:
		var event := current_state.update(delta)
		if event == Events.NONE:
			return
		trigger_event(event)

	func trigger_event(event: Events) -> void:
		assert(
			transitions[current_state],
			"Current state doesn't exist in the transitions dictionary."
		)
		if not transitions[current_state].has(event):
			print_debug(
				"Trying to trigger event " + Events.keys()[event] +
				" from state " + current_state.name +
				" but the transition does not exist."
			)
			return
		var next_state =  transitions[current_state][event]
		_transition(next_state)

	func _transition(new_state: State) -> void:
		current_state.exit()
		current_state.finished.disconnect(_on_state_finished)
		current_state = new_state
		current_state.finished.connect(_on_state_finished.bind(current_state))
		current_state.enter()
		if is_debugging and current_state.player.debug_state_label != null:
			current_state.player.debug_state_label.text = current_state.name

	func _on_state_finished(finished_state: State) -> void:
		assert(
			Events.FINISHED in transitions[current_state],
			"Received a state that does not have a transition for the FINISHED event, " + current_state.name + ". " +
			"Add a transition for this event in the transitions dictionary."
		)
		_transition(transitions[finished_state][Events.FINISHED])


class StateIdle extends State:

	func _init(init_player: Player3D) -> void:
		super("Idle", init_player)

	func enter() -> void:
		player.skin.idle()

	func update(_delta: float) -> Events:
		var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

		# multiply by inverse x and y to account for skin's local axes.
		# Add position to make everything relative to where the player is
		var look_at_direction := (player.velocity * Vector3(-1, 1 , -1)).normalized() + player.global_position
		if not (look_at_direction - player.global_position).is_zero_approx():
			player.skin.look_at(look_at_direction)

		# follow player movement vector, not skin's
		player.debug_look_at_point.global_position = player.velocity.normalized() + player.global_position

		if not input_vector.is_zero_approx():
			return Events.PLAYER_STARTED_MOVING
		elif Input.is_action_just_pressed("jump"):
			return Events.PLAYER_JUMPED
		elif Input.is_action_just_pressed("aim"):
			return Events.PLAYER_STARTED_AIMING
		return Events.NONE


class StateWalk extends State:

	var max_speed = 10.0
	var steering_factor = 20.0

	func _init(init_player: Player3D) -> void:
		super("Walk", init_player)

	func enter() -> void:
		player.skin.move()

	func update(_delta: float) -> Events:
		var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		# inverse to account for positive player axes and rotate relative to camera forward
		var direction := Vector3(-input_vector.x, 0.0, -input_vector.y).rotated(Vector3(0, 1, 0), player.camera_anchor.rotation.y)
		var desired_ground_velocity: Vector3 = max_speed * direction
		var steering_vector := desired_ground_velocity - player.velocity
		steering_vector.y = 0.0
		# We limit the steering amount to ensure the velocity can never overshoots the desired velocity.
		var steering_amount: float = min(steering_factor * _delta, 1.0)
		player.velocity += steering_vector * steering_amount

		const GRAVITY := 40.0 * Vector3.DOWN
		player.velocity += GRAVITY * _delta
		player.move_and_slide()

		# multiply by inverse x and y to account for skin's local axes.
		# Add position to make everything relative to where the player is
		var look_at_direction := (player.velocity * Vector3(-1, 1 , -1)).normalized() + player.global_position
		if not (look_at_direction - player.global_position).is_zero_approx():
			player.skin.look_at(look_at_direction)

		# follow player movement vector, not skin's
		player.debug_look_at_point.global_position = player.velocity.normalized() + player.global_position

		if direction.is_zero_approx():
			return Events.PLAYER_STOPPED_MOVING
		elif Input.is_action_just_pressed("jump"):
			return Events.PLAYER_JUMPED
		elif Input.is_action_just_pressed("aim"):
			return Events.PLAYER_STARTED_AIMING
		return Events.NONE


# TODO: Adjust look_at such that we always face relative to the ground (eventually gravity when platforms can angle)
class StateJump extends State:

	var jump_velocity := 15.0
	var max_speed := 10.0
	var steering_factor := 20.0
	var camera_fov := 45 # degrees
	var camera_zoom_time = 0.25 # seconds

	var _initial_camera_fov: int

	func _init(init_player: Player3D) -> void:
		super("Jump", init_player)

	func enter() -> void:
		player.skin.jump()
		player.velocity.y = jump_velocity

		_initial_camera_fov = player.camera_3D.fov

		var tween = player.create_tween()
		tween.parallel().tween_property(player.camera_3D, "fov", camera_fov, camera_zoom_time).set_ease(Tween.EASE_IN_OUT)

	func exit() -> void:
		var tween = player.create_tween()
		tween.parallel().tween_property(player.camera_3D, "fov", _initial_camera_fov, camera_zoom_time).set_ease(Tween.EASE_IN_OUT)

	func update(_delta: float) -> Events:
		var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		# inverse to account for positive player axes and rotate relative to camera forward
		var direction := Vector3(-input_vector.x, 0.0, -input_vector.y).rotated(Vector3(0, 1, 0), player.camera_anchor.rotation.y)
		var desired_ground_velocity: Vector3 = max_speed * direction
		var steering_vector := desired_ground_velocity - player.velocity
		steering_vector.y = 0.0
		# We limit the steering amount to ensure the velocity can never overshoots the desired velocity.
		var steering_amount: float = min(steering_factor * _delta, 1.0)
		player.velocity += steering_vector * steering_amount

		const GRAVITY := 40.0 * Vector3.DOWN
		player.velocity += GRAVITY * _delta
		player.move_and_slide()

		if player.velocity.y <= 0:
			player.skin.fall()

		# multiply by inverse x and y to account for skin's local axes. Ignore y velocity so the skin stays up right
		# Add position to make everything relative to where the player is
		var look_at_direction := (player.velocity * Vector3(-1, 0, -1)).normalized() + player.global_position
		if not (look_at_direction - player.global_position).is_zero_approx():
			player.skin.look_at(look_at_direction)

		# follow player movement vector, not skin's
		player.debug_look_at_point.global_position = Vector3(0, 0, 1).rotated(Vector3(0, 1, 0), player.camera_anchor.rotation.y) + player.global_position

		if player.is_on_floor():
			return Events.PLAYER_LANDED
		return Events.NONE

class StateAim extends State:

	var max_speed = 10.0
	var steering_factor = 20.0
	var collision_detection_length := 100 # meters
	var camera_zoom_time := 0.05 # seconds
	var camera_fov := 18 # degrees
	var camera_position := Vector3(-0.995, 4.16, -10)

	var _initial_camera_position: Vector3
	var _initial_camera_fov: int

	func _init(init_player: Player3D) -> void:
		super("Aim", init_player)

	func enter() -> void:
		_initial_camera_position = player.camera_3D.position
		_initial_camera_fov = player.camera_3D.fov

		var tween = player.create_tween()
		tween.tween_property(player.camera_3D, "position", camera_position, camera_zoom_time).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(player.camera_3D, "fov", camera_fov, camera_zoom_time).set_ease(Tween.EASE_IN_OUT)

	func exit() -> void:
		player.targeting_csg_movable.emit(null)

		var tween = player.create_tween()
		tween.tween_property(player.camera_3D, "position", _initial_camera_position, camera_zoom_time).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(player.camera_3D, "fov", _initial_camera_fov, camera_zoom_time).set_ease(Tween.EASE_IN_OUT)

	func update(_delta: float) -> Events:
		var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		# inverse to account for positive player axes and rotate relative to camera forward
		var direction := Vector3(-input_vector.x, 0.0, -input_vector.y).rotated(Vector3(0, 1, 0), player.camera_anchor.rotation.y)
		var desired_ground_velocity: Vector3 = max_speed * direction
		var steering_vector := desired_ground_velocity - player.velocity
		steering_vector.y = 0.0
		# We limit the steering amount to ensure the velocity can never overshoots the desired velocity.
		var steering_amount: float = min(steering_factor * _delta, 1.0)
		player.velocity += steering_vector * steering_amount

		const GRAVITY := 40.0 * Vector3.DOWN
		player.velocity += GRAVITY * _delta
		player.move_and_slide()

		if direction.is_zero_approx():
			player.skin.idle()
		else:
			player.skin.move()

		var look_at_direction = Vector3(0, 0, -1).rotated(Vector3(0, 1, 0), player.camera_anchor.rotation.y) + player.global_position
		if not (look_at_direction - player.global_position).is_zero_approx():
			player.skin.look_at(look_at_direction)

		# follow player movement vector, not skin's
		player.debug_look_at_point.global_position = Vector3(0, 0, 1).rotated(Vector3(0, 1, 0), player.camera_anchor.rotation.y) + player.global_position

		# Handle highlighting ---
		# Cast a ray from the camera to a set length. If we hit something, check to make sure it's a platform we can move
		# and highlight it by changing its state
		var space_state := player.get_world_3d().direct_space_state
		# Adjust the aiming raycast to start next to the player, not the camera
		var origin: Vector3 = player.camera_3D.global_position + (player.camera_3D.project_ray_normal(player.camera_3D.get_viewport().size / 2.0) * abs(player.camera_3D.position.z))
		var end := origin + (player.camera_3D.project_ray_normal(player.camera_3D.get_viewport().size / 2.0) * collision_detection_length)
		player.debug_aim_raycast_begin_point.global_position = origin
		player.debug_aim_raycast_end_point.global_position = end

		var collision := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end))
		if not collision.is_empty():
			player.debug_aim_raycast_end_point.global_position = collision.position
			if collision.collider is CSGMovable:
				player.targeting_csg_movable.emit(collision.collider)
			else:
				player.targeting_csg_movable.emit(null)
		else:
			player.targeting_csg_movable.emit(null)

		if Input.is_action_just_released("aim"):
			return Events.PLAYER_STOPPED_AIMING
		return Events.NONE
