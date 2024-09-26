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

@export_range(0.001, 1, 0.01) var camera_zoom_time := 0.05
## Controls how quickly the player accelerates and turns on the ground.
@export_range(1.0, 50.0, 0.1) var steering_factor := 20.0

@export_group("State WALKING")
## The maximum speed the player can move at in meters per second.
@export_range(3.0, 12.0, 0.1) var max_speed := 6.0

@export_group("State JUMPING")
@export_range(3.0, 12.0, 0.1) var max_air_control_speed := 6.0
@export_range(1.0, 30.0, 0.1) var jump_velocity := 15.0

@export_group("State AIMING")
## The maximum speed the player can move at while aiming in meters per second.
@export_range(3.0, 12.0, 0.1) var max_speed_aiming := 3.0
@export_range(1, 179, 1) var camera_fov_aiming:= 18
@export var camera_position_aiming := Vector3(-0.995, 4.16, -10)

@onready var skin: SophiaSkin3D = %SophiaSkin
@onready var camera_anchor: Node3D = %CameraAnchor
@onready var camera_3D: Camera3D = %Camera3D
@onready var debug_state_label = %DebugStateLabel3D
@onready var debug_look_at_point = %DebugLookAtPoint
@onready var debug_aim_raycast_begin_point = %DebugAimRaycastBeginPoint
@onready var debug_aim_raycast_end_point = %DebugAimRaycastEndPoint

func _ready() -> void:
	var state_machine := Player.StateMachine.new()
	add_child(state_machine)

	var idle := Player.StateIdle.new(self)

	var walk := Player.StateWalk.new(self)
	walk.max_speed = max_speed

	var jump := Player.StateJump.new(self)
	jump.max_speed = max_air_control_speed
	jump.jump_velocity = jump_velocity

	var fall := Player.StateFall.new(self)
	fall.max_speed = max_air_control_speed

	var aim := Player.StateAim.new(self)
	aim.camera_zoom_time = camera_zoom_time
	aim.max_speed = max_speed_aiming
	aim.camera_fov = camera_fov_aiming

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
