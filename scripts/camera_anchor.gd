extends Node3D

@export var camera_sensitivity := 100.0

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / camera_sensitivity
		rotation.x -= event.relative.y / camera_sensitivity
		rotation.x = clamp(rotation.x, deg_to_rad(-45), deg_to_rad(90))
