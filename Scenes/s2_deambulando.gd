extends Estado

var rango_patrulla: float = 10.0 
var jugador: CharacterBody3D

func entrar():
	print("El monstruo está en S2: Deambulando...")
	jugador = get_tree().get_first_node_in_group("jugador")
	buscar_nuevo_punto()
	# ¡LE DAMOS PLAY A CAMINAR!
	enemigo.anim.play("walk_anim")

func actualizar_fisica(_delta):
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

	# 3. Movimiento de patrulla normal
	if enemigo.nav_agent.is_navigation_finished():
		buscar_nuevo_punto()
		return
		
	var siguiente_posicion = enemigo.nav_agent.get_next_path_position()
	var direccion = enemigo.global_position.direction_to(siguiente_posicion)
	
	enemigo.velocity.x = direccion.x * enemigo.velocidad_caminar
	enemigo.velocity.z = direccion.z * enemigo.velocidad_caminar
	enemigo.move_and_slide()

func buscar_nuevo_punto():
	# ¡NUEVO!: 25% de probabilidad de ir a un conducto
	if randf() < 0.25:
		transicion_solicitada.emit(self, "S5_EntrarConducto")
		return
		
	# Si no (75% de las veces), busca un punto aleatorio normal
	var offset_x = randf_range(-rango_patrulla, rango_patrulla)
	var offset_z = randf_range(-rango_patrulla, rango_patrulla)
	var punto_aleatorio = enemigo.global_position + Vector3(offset_x, 0, offset_z)
	enemigo.nav_agent.target_position = punto_aleatorio

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
