extends Estado

var jugador: CharacterBody3D
var tiempo_perdido: float = 0.0
var tiempo_para_perder: float = 1.5 

# --- VARIABLES DE ATAQUE ---
var distancia_ataque: float = 1.5 
var tiempo_recuperacion: float = 0.0 # El tiempo que se queda quieto tras morder
var temporizador_grunido : float = 0.0


func entrar():
	print("¡TE VI! Entrando en S4: Persiguiendo...")
	jugador = get_tree().get_first_node_in_group("jugador")
	tiempo_perdido = 0.0
	tiempo_recuperacion = 0.0 # Reiniciamos por si acaso
	enemigo.anim.play("run_anim")
	
	# --- PRIMER GRITO ---
	if enemigo.audios_ataque.size() > 0:
		enemigo.grito_audio.stream = enemigo.audios_ataque.pick_random()
	elif enemigo.audios_ambiente.size() > 0:
		enemigo.grito_audio.stream = enemigo.audios_ambiente.pick_random()
	
	enemigo.grito_audio.pitch_scale = randf_range(0.9, 1.1)
	if not enemigo.grito_audio.playing:
		enemigo.grito_audio.play()
		
	# ¡NUEVO! Iniciamos la cuenta regresiva para el siguiente gruñido
	temporizador_grunido = randf_range(1.0, 2.5)

func actualizar_fisica(delta):
	if not jugador: return
	
	# --- SISTEMA DE RECUPERACIÓN (Darle chance a Vance) ---
	if tiempo_recuperacion > 0.0:
		tiempo_recuperacion -= delta
		enemigo.velocity.x = move_toward(enemigo.velocity.x, 0, delta * 20.0)
		enemigo.velocity.z = move_toward(enemigo.velocity.z, 0, delta * 20.0)
		enemigo.move_and_slide()
		return 
	# --------------------------------------------------------------
	
	if enemigo.anim.current_animation != "run_anim" and tiempo_recuperacion <= 0.0:
		enemigo.anim.play("run_anim", 0.15)
		enemigo.anim.speed_scale = 1.0 # Corre de forma más realista
	
	# --- SISTEMA DE ATAQUE ---
	var distancia_al_jugador = enemigo.global_position.distance_to(jugador.global_position)
	
	if distancia_al_jugador <= distancia_ataque:
		print("¡ZAS! El monstruo te atacó. ¡CORRE!")
		enemigo.anim.play("attack_anim", 0.15)
		
		# ¡NUEVO!: Grito único de ataque
		if enemigo.audios_ataque.size() > 0:
			enemigo.ambiente_audio.stream = enemigo.audios_ataque.pick_random()
			enemigo.ambiente_audio.pitch_scale = randf_range(0.8, 1.2)
			enemigo.ambiente_audio.play()
			
		if jugador.has_method("recibir_dano"):
			jugador.recibir_dano(34.0) 
			
		tiempo_recuperacion = 1.5
		enemigo.velocity.x = 0
		enemigo.velocity.z = 0
		enemigo.move_and_slide()
		return 
	# -------------------------
	
	# 1. ¿Te sigo viendo?
	if revisar_vision_s4():
		tiempo_perdido = 0.0
		enemigo.ultima_posicion_conocida = jugador.global_position
		
		# Evitar crasheos si el jugador sale del NavMesh encontrando el punto válido más cercano
		var mapa_nav = enemigo.get_world_3d().get_navigation_map()
		enemigo.nav_agent.target_position = NavigationServer3D.map_get_closest_point(mapa_nav, enemigo.ultima_posicion_conocida)
	else:
		tiempo_perdido += delta
		
		# ¡NUEVO!: También se pierde si te lograste meter en una zona segura
		if tiempo_perdido >= tiempo_para_perder or not enemigo.nav_agent.is_target_reachable() or (jugador.has_method("get") and jugador.get("esta_a_salvo")):
			print("Te perdí de vista o te metiste en un lugar seguro... pasando a S3 para investigar.")
			transicion_solicitada.emit(self, "S3_Investigando")
			return 
			
	# 2. Correr hacia ti (Solo si tiene ruta válida de navegación)
	if not enemigo.nav_agent.is_target_reachable() and not enemigo.nav_agent.is_navigation_finished():
		enemigo.velocity.x = move_toward(enemigo.velocity.x, 0, delta * 12.0)
		enemigo.velocity.z = move_toward(enemigo.velocity.z, 0, delta * 12.0)
		enemigo.move_and_slide()
		if enemigo.anim.current_animation != "idle_anim":
			enemigo.anim.play("idle_anim", 0.3)
	else:
		var siguiente_posicion = enemigo.nav_agent.get_next_path_position()
		var direccion = enemigo.global_position.direction_to(siguiente_posicion)
		direccion.y = 0
		direccion = direccion.normalized()
		
		# Seguimos corriendo solo si la lógica alcanzó aquí
		if enemigo.anim.current_animation != "run_anim":
			enemigo.anim.play("run_anim", 0.15)
			
		enemigo.velocity.x = move_toward(enemigo.velocity.x, direccion.x * enemigo.velocidad_correr, delta * 12.0)
		enemigo.velocity.z = move_toward(enemigo.velocity.z, direccion.z * enemigo.velocidad_correr, delta * 12.0)
		enemigo.move_and_slide()
	
	# --- ¡AQUÍ ESTÁ LA MAGIA DEL AUDIO QUE FALTABA! ---
	# --- ¡AQUÍ ESTÁ LA MAGIA DEL AUDIO QUE FALTABA! ---
	if not enemigo.grito_audio.playing:
		temporizador_grunido -= delta # El tiempo va bajando en cada frame
		
		# Si el cronómetro llega a cero, suelta otro rugido aleatorio
		if temporizador_grunido <= 0.0:
			if enemigo.audios_ataque.size() > 0:
				enemigo.grito_audio.stream = enemigo.audios_ataque.pick_random()
			elif enemigo.audios_ambiente.size() > 0:
				enemigo.grito_audio.stream = enemigo.audios_ambiente.pick_random()
				
			enemigo.grito_audio.pitch_scale = randf_range(0.7, 1.1) 
			enemigo.grito_audio.play()
			
			# Reinicia el cronómetro para esperar entre 1.5 y 3.5 segundos más (más frecuente)
			temporizador_grunido = randf_range(1.5, 3.5)
	# --------------------------------------------------

func revisar_vision_s4() -> bool:
	if not jugador: return false
	if "esta_a_salvo" in jugador and jugador.esta_a_salvo: return false 
	
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
