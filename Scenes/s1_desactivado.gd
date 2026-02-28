extends Estado

func entrar():
	print("S1: Enemigo DESACTIVADO. Ignorando al jugador.")
	enemigo.velocity = Vector3.ZERO # Se queda quieto
	enemigo.anim.play("idle_anim")
	# Opcional: podrías poner enemigo.visible = false si quieres que desaparezca

func actualizar_fisica(_delta):
	# ¡No hacemos nada! Ni visión, ni oído, ni caminar. Está "apagado".
	pass
