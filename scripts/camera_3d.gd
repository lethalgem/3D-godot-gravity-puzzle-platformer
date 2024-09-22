extends Camera3D

func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("zoom_in"):
		#fov -= 1
		#print("fov: " + str(fov))
		position.z -= 0.5
		print("position.z: " + str(position.z) + " m")
	elif Input.is_action_pressed("zoom_out"):
		#fov += 1
		position.z += 0.5
		print("position.z: " + str(position.z) + " m")
