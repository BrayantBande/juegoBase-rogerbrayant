extends Control

func _ready() -> void:
	# Make sure mouse is visible in the menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_iniciar_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/mundo.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()
