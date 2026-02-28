extends Area3D

func _on_body_entered(body):
	# Si el que entra es el jugador, activamos su escudo
	if body.is_in_group("jugador"):
		print("¡A SALVO! El jugador entró a la Zona Segura.")
		body.esta_a_salvo = true

func _on_body_exited(body):
	# Si sale, le quitamos el escudo
	if body.is_in_group("jugador"):
		print("¡PELIGRO! El jugador salió de la Zona Segura.")
		body.esta_a_salvo = false
