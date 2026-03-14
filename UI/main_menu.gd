extends Control

@onready var main_container = $CenterContainer

func _ready() -> void:
	# Make sure mouse is visible in the menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_iniciar_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/mundo.tscn")

func _on_opciones_pressed() -> void:
	main_container.hide()
	var opciones_scene = load("res://UI/OptionsMenu.tscn").instantiate()
	add_child(opciones_scene)
	opciones_scene.connect("cerrar_opciones", _on_cerrar_opciones.bind(opciones_scene))
	
func _on_cerrar_opciones(nodo_opciones: Node) -> void:
	nodo_opciones.queue_free()
	main_container.show()

func _on_salir_pressed() -> void:
	get_tree().quit()
