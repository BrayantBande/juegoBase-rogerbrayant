extends Estado

var jugador: CharacterBody3D
var tiempo_espera: float = 0.0
var tiempo_max_espera: float = 3.0 
var tiempo_caminando: float = 0.0 # NUEVO: Para evitar que se atasque

func entrar():
	print("S3: Iniciando investigación del lugar...")
	jugador = get_tree().get_first_node_in_group("jugador")
	tiempo_espera = 0.0
	tiempo_caminando = 0.0
	
	# Le decimos que vaya a la MEMORIA, no a tu ubicación actual secreta
	enemigo.nav_agent.target_position = enemigo.ultima_posicion_conocida
	enemigo.anim.play("walk_anim")

func actualizar_fisica(delta):
	if revisar_vision_s3():
		print("S3: ¡Te vi asomarte!")
		transicion_solicitada.emit(self, "S4_Persiguiendo")
		return
		
	# SISTEMA ANTI-ATASCOS (Por si se traba con un muro)
	tiempo_caminando += delta
	if tiempo_caminando > 7.0:
		print("S3: Llevo mucho tiempo buscando la ruta, me rindo.")
		transicion_solicitada.emit(self, "S2_Deambulando")
		return
		
	var pos_enem_plana = Vector2(enemigo.global_position.x, enemigo.global_position.z)
	var pos_dest_plana = Vector2(enemigo.nav_agent.target_position.x, enemigo.nav_agent.target_position.z)
	var distancia_al_destino = pos_enem_plana.distance_to(pos_dest_plana)
	
	if enemigo.nav_agent.is_navigation_finished() or distancia_al_destino < 1.5:
		enemigo.velocity = Vector3.ZERO
		tiempo_espera += delta
		
		# ¡LLEGÓ Y SE QUEDA QUIETO BUSCANDO!
		if enemigo.anim.current_animation != "idle_anim":
			enemigo.anim.play("idle_anim")
		
		print("S3: Buscando... ", snapped(tiempo_espera, 0.1), " seg")
		
		if tiempo_espera >= tiempo_max_espera:
			print("S3: Falsa alarma. Volviendo a patrullar (S2).")
			transicion_solicitada.emit(self, "S2_Deambulando")
			return 
	else:
		var siguiente_posicion = enemigo.nav_agent.get_next_path_position()
		var direccion = enemigo.global_position.direction_to(siguiente_posicion)
		direccion.y = 0 
		direccion = direccion.normalized()
		enemigo.velocity.x = direccion.x * (enemigo.velocidad_caminar*1.5)
		enemigo.velocity.z = direccion.z * (enemigo.velocidad_caminar*1.5)
		
	enemigo.move_and_slide()

# --- LA VISIÓN (Se mantiene igual) ---
func revisar_vision_s3() -> bool: # (Cambia el nombre a revisar_vision_s3 o s4 según el script)
	if not jugador: return false
	if jugador.esta_a_salvo: return false 
	
	# 1. Distancia base de visión (En la oscuridad)
	var rango_vision = 10.0 
	
	# 2. Si tu linterna está encendida, ¡te ve desde mucho más lejos!
	if "linterna_encendida" in jugador and jugador.linterna_encendida:
		rango_vision = 25.0 
	
	# 3. Medimos y lanzamos el rayo láser
	var distancia = enemigo.global_position.distance_to(jugador.global_position)
	
	if distancia < rango_vision:
		var punto_apuntado = jugador.global_position + Vector3(0, 1.0, 0)
		enemigo.vision_raycast.target_position = enemigo.vision_raycast.to_local(punto_apuntado)
		enemigo.vision_raycast.force_raycast_update()
		
		if enemigo.vision_raycast.is_colliding() and enemigo.vision_raycast.get_collider().is_in_group("jugador"):
			return true
			
	return false
