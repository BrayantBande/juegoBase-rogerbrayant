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
	enemigo.grito_audio.pitch_scale = 1.0 # Tono normal al verte
	if not enemigo.grito_audio.playing:
		enemigo.grito_audio.play()
		
	# ¡NUEVO! Iniciamos la cuenta regresiva para el siguiente gruñido
	temporizador_grunido = randf_range(1.5, 3.0)

func actualizar_fisica(delta):
	if not jugador: return
	
	# --- SISTEMA DE RECUPERACIÓN (Darle chance a Vance) ---
	if tiempo_recuperacion > 0.0:
		tiempo_recuperacion -= delta
		enemigo.velocity = Vector3.ZERO 
		enemigo.move_and_slide()
		return 
	# --------------------------------------------------------------
	
	if enemigo.anim.current_animation != "run_anim" and tiempo_recuperacion <= 0.0:
		enemigo.anim.play("run_anim")
	
	# --- SISTEMA DE ATAQUE ---
	var distancia_al_jugador = enemigo.global_position.distance_to(jugador.global_position)
	
	if distancia_al_jugador <= distancia_ataque:
		print("¡ZAS! El monstruo te atacó. ¡CORRE!")
		enemigo.anim.play("attack_anim")
		if jugador.has_method("recibir_dano"):
			jugador.recibir_dano(34.0) 
			
		tiempo_recuperacion = 1.5
		enemigo.velocity = Vector3.ZERO
		enemigo.move_and_slide()
		return 
	# -------------------------
	
	# 1. ¿Te sigo viendo?
	if revisar_vision_s4():
		tiempo_perdido = 0.0
		enemigo.ultima_posicion_conocida = jugador.global_position
		enemigo.nav_agent.target_position = enemigo.ultima_posicion_conocida
	else:
		tiempo_perdido += delta
		if tiempo_perdido >= tiempo_para_perder:
			print("Te perdí de vista... pasando a S3 para investigar.")
			transicion_solicitada.emit(self, "S3_Investigando")
			return 
			
	# 2. Correr hacia ti
	var siguiente_posicion = enemigo.nav_agent.get_next_path_position()
	var direccion = enemigo.global_position.direction_to(siguiente_posicion)
	direccion.y = 0
	direccion = direccion.normalized()
	
	enemigo.velocity.x = direccion.x * enemigo.velocidad_correr
	enemigo.velocity.z = direccion.z * enemigo.velocidad_correr
	enemigo.move_and_slide()
	
	# --- ¡AQUÍ ESTÁ LA MAGIA DEL AUDIO QUE FALTABA! ---
	if not enemigo.grito_audio.playing:
		temporizador_grunido -= delta # El tiempo va bajando en cada frame
		
		# Si el cronómetro llega a cero, suelta otro rugido aleatorio
		if temporizador_grunido <= 0.0:
			enemigo.grito_audio.pitch_scale = randf_range(0.7, 1.1) 
			enemigo.grito_audio.play()
			
			# Reinicia el cronómetro para esperar entre 2 y 5 segundos más
			temporizador_grunido = randf_range(2.0, 5.0)
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
