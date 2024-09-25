class_name CSGMovable extends CSGCombiner3D

@export var player: Player3D

enum State {
	STATIC,
	TARGETED,
	TRANSLATING,
	ROTATING,
}

@onready var current_state: = State.STATIC: set = set_current_state

func set_current_state(new_state: State) -> void:
	if current_state != new_state:
		current_state = new_state

		# Update color of CSG to reflect current state
		# TODO: Remove this and have an in world change (maybe on character?) to reflect state -- no HUD
		var state_color: Color
		match new_state:
			State.STATIC:
				state_color = Color.AZURE
			State.TARGETED:
				state_color = Color.BLUE
			State.TRANSLATING:
				state_color = Color.CHARTREUSE
			State.ROTATING:
				state_color = Color.DEEP_PINK
		for child in get_children():
			if child is CSGBox3D:
				child.material.albedo_color = state_color

func _ready() -> void:
	player.targeting_csg_movable.connect(
		func (csg_movable: CSGMovable) -> void:
			if csg_movable == self:
				set_current_state(State.TARGETED)
			else:
				set_current_state(State.STATIC)
	)
