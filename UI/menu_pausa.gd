extends CanvasLayer

func _ready():
	hide() # Nos aseguramos de que el menú nazca oculto
	
	# Nos conectamos a la señal de pausa del jugador
	var player = get_parent()
	if player and player.name == "Player":
		player.toggle_pause.connect(_on_toggle_pause)

func _on_toggle_pause():
	var esta_pausado = not get_tree().paused
	get_tree().paused = esta_pausado
	visible = esta_pausado
	
	# Ocultar o mostrar el HUD central para que no se mezcle con la pausa
	var hud = get_parent().get_node_or_null("interfaz")
	if hud:
		hud.visible = not esta_pausado

	# Liberar o atrapar el ratón
	if esta_pausado:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Estas funciones ya estaban conectadas a tus botones en el editor
func _on_continuar_pressed():
	_on_toggle_pause() # Reutilizamos la lógica de arriba

func _on_salir_del_juego_pressed():
	get_tree().quit()
