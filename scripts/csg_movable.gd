class_name CSGMovable extends CSGCombiner3D

enum STATE {
	STATIC,
	TARGETED,
	TRANSLATING,
	ROTATING,
}

@onready var current_state: = STATE.STATIC: set = set_current_state

func set_current_state(new_state: STATE) -> void:
	if current_state != new_state:
		current_state = new_state

		# Update color of CSG to reflect current state
		# TODO: Remove this and have an in world change (maybe on character?) to reflect state -- no HUD
		var state_color: Color
		match new_state:
			STATE.STATIC:
				state_color = Color.AZURE
			STATE.TARGETED:
				state_color = Color.BLUE
			STATE.TRANSLATING:
				state_color = Color.CHARTREUSE
			STATE.ROTATING:
				state_color = Color.DEEP_PINK
		for child in get_children():
			if child is CSGBox3D:
				child.material.albedo_color = state_color
