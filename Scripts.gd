extends Label

func _process(_delta):
	# Esto obtiene los cuadros por segundo actuales
	text = "FPS: " + str(Engine.get_frames_per_second()) 
