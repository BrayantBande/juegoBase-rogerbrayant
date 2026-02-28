extends Estado

var tiempo_viaje: float = 3.0 # Tarda 3 segundos en viajar por el techo
var tiempo_actual: float = 0.0
var conducto_salida: Marker3D

func entrar():
	print("S6: Viajando por los conductos...")
	tiempo_actual = 0.0
	enemigo.velocity = Vector3.ZERO # Lo frenamos por completo
	
	# 1. Hacerlo invisible y quitarle la colisión ("Modo Fantasma")
	enemigo.visible = false
	enemigo.get_node("CollisionShape3D").set_deferred("disabled", true)
	
	# 2. Elegir por dónde va a salir (buscamos un conducto que NO sea en el que está)
	var todos_los_conductos = get_tree().get_nodes_in_group("conductos")
	var conductos_validos = []
	
	for conducto in todos_los_conductos:
		# Si el conducto está a más de 2 metros, significa que es OTRO conducto
		if enemigo.global_position.distance_to(conducto.global_position) > 2.0:
			conductos_validos.append(conducto)
			
	if conductos_validos.size() > 0:
		# Elige uno al azar de los que están lejos
		conducto_salida = conductos_validos.pick_random()
	else:
		# Por si acaso solo pusiste 1 conducto en el mapa
		conducto_salida = todos_los_conductos[0]

func actualizar_fisica(delta):
	# El cronómetro avanza mientras viaja
	tiempo_actual += delta
	
	if tiempo_actual >= tiempo_viaje:
		terminar_viaje()

func terminar_viaje():
	print("S6: ¡Saliendo por otro conducto!")
	
	# 1. Teletransportar al enemigo al nuevo conducto
	enemigo.global_position = conducto_salida.global_position
	
	# 2. Hacerlo visible y sólido de nuevo
	enemigo.visible = true
	enemigo.get_node("CollisionShape3D").set_deferred("disabled", false)
	
	# 3. Mandarlo de vuelta a patrullar por esta nueva zona
	transicion_solicitada.emit(self, "S2_Deambulando")
