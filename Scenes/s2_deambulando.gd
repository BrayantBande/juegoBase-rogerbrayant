extends Estado

var rango_patrulla: float = 45.0 
var jugador: CharacterBody3D
var tiempo_parado: float = 0.0
var debe_esperar: bool = false
var espera_maxima: float = 2.0
var apenas_arrancando: bool = false
var tiempo_ambiente: float = 0.0

func entrar():
	print("El monstruo está en S2: Deambulando...")
	jugador = get_tree().get_first_node_in_group("jugador")
	debe_esperar = false
	apenas_arrancando = true
	tiempo_ambiente = randf_range(5.0, 15.0) # Esperará entre 5 y 15 segundos para el primer gruñido
	buscar_nuevo_punto()
	# ¡LE DAMOS PLAY A CAMINAR!
	enemigo.anim.play("walk_anim")

func actualizar_fisica(delta):
	# 1. ¿Vemos al jugador? (Pasa a S4)
	if revisar_vision():
		transicion_solicitada.emit(self, "S4_Persiguiendo")
		return 
		
	# NUEVO: 2. ¿Escuchamos al jugador? (Pasa a S3)
	if revisar_oido():
		print("¡Escuché algo! Voy a investigar...")
		# GUARDAMOS LA MEMORIA AQUÍ:
		enemigo.ultima_posicion_conocida = jugador.global_position 
		transicion_solicitada.emit(self, "S3_Investigando")
		return

	# --- SISTEMA DE SONIDOS AMBIENTALES ---
	tiempo_ambiente -= delta
	if tiempo_ambiente <= 0.0:
		# Reinicia el temporizador para el próximo gruñido aleatorio (entre 8 a 20 segundos)
		tiempo_ambiente = randf_range(8.0, 20.0)
		
		# Si el usuario puso audios en el inspector, elige uno al azar y lo reproduce
		if enemigo.audios_ambiente.size() > 0:
			enemigo.ambiente_audio.stream = enemigo.audios_ambiente.pick_random()
			# Variamos un poco el tono para que el mismo gruñido suene distinto
			enemigo.ambiente_audio.pitch_scale = randf_range(0.9, 1.1)
			enemigo.ambiente_audio.play()

	# 3. Movimiento de patrulla normal
	if debe_esperar:
		tiempo_parado += delta
		enemigo.velocity.x = move_toward(enemigo.velocity.x, 0, delta * 15.0)
		enemigo.velocity.z = move_toward(enemigo.velocity.z, 0, delta * 15.0)
		enemigo.move_and_slide()
		
		# Animación de descanso
		if enemigo.anim.current_animation != "idle_anim":
			enemigo.anim.play("idle_anim")
			
		if tiempo_parado >= espera_maxima:
			debe_esperar = false
			apenas_arrancando = true
			buscar_nuevo_punto()
			enemigo.anim.play("walk_anim")
		return

	# Cortafuegos: Le damos a Godot 1 frame para procesar el path antes de preguntarle si terminó
	if apenas_arrancando:
		apenas_arrancando = false
		return

	if enemigo.nav_agent.is_navigation_finished() or not enemigo.nav_agent.is_target_reachable():
		debe_esperar = true
		tiempo_parado = 0.0
		espera_maxima = randf_range(0.5, 2.5) # Espera entre medio segundo y 2.5 segundos máximos para no ser lento
		return
		
	var siguiente_posicion = enemigo.nav_agent.get_next_path_position()
	var direccion = enemigo.global_position.direction_to(siguiente_posicion)
	direccion.y = 0 # Evita que intente volar o hundirse
	direccion = direccion.normalized()
	
	if enemigo.anim.current_animation != "walk_anim":
		enemigo.anim.play("walk_anim")
		
	enemigo.velocity.x = move_toward(enemigo.velocity.x, direccion.x * enemigo.velocidad_caminar, delta * 4.0)
	enemigo.velocity.z = move_toward(enemigo.velocity.z, direccion.z * enemigo.velocidad_caminar, delta * 4.0)
	enemigo.move_and_slide()

func buscar_nuevo_punto():
	# ¡NUEVO!: 8% de probabilidad de ir a un conducto (para que sea más raro y sorpresivo)
	if randf() < 0.08:
		transicion_solicitada.emit(self, "S5_EntrarConducto")
		return
		
	# Si no (92% de las veces), busca un punto aleatorio normal
	var mapa_nav = enemigo.get_world_3d().get_navigation_map()
	var iteraciones = 0
	var punto_valido = false
	
	# Intentar generar un punto válido hasta 15 veces
	while not punto_valido and iteraciones < 15:
		iteraciones += 1
		var offset_x = randf_range(-rango_patrulla, rango_patrulla)
		var offset_z = randf_range(-rango_patrulla, rango_patrulla)
		var punto_aleatorio = enemigo.global_position + Vector3(offset_x, 0, offset_z)
		
		# Mapear CLAVADO a la zona azul navegable (NavMesh) para evitar puntos muertos
		var punto_seguro = NavigationServer3D.map_get_closest_point(mapa_nav, punto_aleatorio)
		
		# Asegurar que sea lejos
		if enemigo.global_position.distance_to(punto_seguro) > 3.0:
			enemigo.nav_agent.target_position = punto_seguro
			punto_valido = true
			
	# Si de casualidad todo falla, frenar suave
	if not punto_valido:
		enemigo.velocity.x = move_toward(enemigo.velocity.x, 0, 0.1 * 12.0)
		enemigo.velocity.z = move_toward(enemigo.velocity.z, 0, 0.1 * 12.0)

# --- LA MAGIA DE LA VISIÓN ---
func revisar_vision() -> bool: 
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

func revisar_oido() -> bool:
	if not jugador: return false
	if jugador.esta_a_salvo: return false # ¡NUEVO! Si está a salvo, lo ignora
	
	# Calculamos a qué distancia está Vance
	var distancia = enemigo.global_position.distance_to(jugador.global_position)
	
	# Si Vance tiene la variable "nivel_ruido" y estamos dentro de su burbuja de ruido...
	if "nivel_ruido" in jugador and distancia < jugador.nivel_ruido:
		return true # ¡LO ESCUCHÓ!
		
	return false
