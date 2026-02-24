extends CanvasLayer

func _on_continuar_pressed() -> void:
	# 1. Quitamos la pausa del motor
	get_tree().paused = false
	
	# 2. Ocultamos este menú
	self.visible = false
	
	# 3. Le decimos al "padre" (el Jugador) que devuelva la mira y el ratón
	var jugador = get_parent()
	jugador.capa_mira.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_salir_del_juego_pressed() -> void:
	# Cierra el juego
	get_tree().quit()
