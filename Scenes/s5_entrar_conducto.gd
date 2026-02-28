extends Estado

var conducto_destino: Marker3D

func entrar():
	print("S5: Decidí entrar a un conducto. Buscando el más cercano...")
	var todos_los_conductos = get_tree().get_nodes_in_group("conductos")
	
	if todos_los_conductos.size() == 0:
		print("Error: No hay conductos en el mapa. Volviendo a S2.")
		transicion_solicitada.emit(self, "S2_Deambulando")
		return
		
	# Lógica para encontrar el conducto más cercano
	var distancia_mas_corta = 9999.0
	for conducto in todos_los_conductos:
		var distancia = enemigo.global_position.distance_to(conducto.global_position)
		if distancia < distancia_mas_corta:
			distancia_mas_corta = distancia
			conducto_destino = conducto
			
	# Le decimos al GPS que vaya a ese conducto
	enemigo.nav_agent.target_position = conducto_destino.global_position
	enemigo.anim.play("walk_anim")
	
func actualizar_fisica(_delta):
	# --- ¡NUEVO! INTERRUPCIÓN POR VISIÓN BLINDADA ---
	if enemigo.vision_raycast.is_colliding():
		var objeto_visto = enemigo.vision_raycast.get_collider()
		
		if objeto_visto != null and objeto_visto.is_in_group("jugador"):
			# Verificamos si el jugador está a salvo usando tu variable exacta
			var a_salvo = false
			if "esta_a_salvo" in objeto_visto: 
				a_salvo = objeto_visto.esta_a_salvo
				
			# Si NO está a salvo, atacamos
			if not a_salvo:
				print("S5: ¡Vi al jugador! Dejo el conducto y voy a cazarlo.")
				transicion_solicitada.emit(self, "S4_Persiguiendo")
				return
	# ---------------------------------------------------------------

	# Si por alguna razón el conducto desapareció, vuelve a patrullar
	if not conducto_destino:
		transicion_solicitada.emit(self, "S2_Deambulando")
		return

	var distancia_al_destino = enemigo.global_position.distance_to(conducto_destino.global_position)

	# 1. ¿Ya llegamos al conducto?
	if enemigo.nav_agent.is_navigation_finished() or distancia_al_destino < 1.0:
		print("S5: Llegué al conducto. Entrando...")
		transicion_solicitada.emit(self, "S6_MoverConducto")
	
	# 2. Si no hemos llegado, nos movemos hacia allá
	else:
		var siguiente_posicion = enemigo.nav_agent.get_next_path_position()
		var direccion = enemigo.global_position.direction_to(siguiente_posicion)
		
		# Mantenemos la Y en 0 para que no intente volar
		direccion.y = 0 
		direccion = direccion.normalized()
		
		# --- SISTEMA DE ANIMACIÓN POR DISTANCIA ---
		if distancia_al_destino > 3.0:
			# Si está a más de 3 metros, camina normal
			if enemigo.anim.current_animation != "walk_anim":
				enemigo.anim.play("walk_anim")
			# Usamos X y Z para no romper la gravedad y que no flote
			enemigo.velocity.x = direccion.x * enemigo.velocidad_caminar
			enemigo.velocity.z = direccion.z * enemigo.velocidad_caminar
			
		else:
			# Si está a 3 metros o menos, ¡se tira a gatear!
			if enemigo.anim.current_animation != "crawl_anim":
				enemigo.anim.play("crawl_anim")
			# Va más lento al gatear (X y Z separados)
			enemigo.velocity.x = direccion.x * (enemigo.velocidad_caminar * 0.7)
			enemigo.velocity.z = direccion.z * (enemigo.velocidad_caminar * 0.7)
		# ------------------------------------------
		
		enemigo.move_and_slide()
