extends Node

@export var estado_inicial: Node # Arrastraremos el estado S2 aquí en el Inspector

var estado_actual: Estado
var estados: Dictionary = {}

func _ready():
	# Buscar todos los estados hijos (S0, S1, S2, etc.)
	for hijo in get_children():
		if hijo is Estado:
			estados[hijo.name.to_lower()] = hijo
			hijo.transicion_solicitada.connect(_on_transicion_solicitada)
			
			# CAMBIO 1: Usar get_parent() es más seguro que 'owner'
			hijo.enemigo = get_parent() 
	
	# CAMBIO 2: ¡LA LÍNEA MÁGICA! 
	# Esperamos a que el padre (Enemigo) termine de cargar sus variables @onready
	await get_parent().ready 
	
	# Ahora sí, arrancamos la máquina
	if estado_inicial:
		estado_inicial.entrar()
		estado_actual = estado_inicial

func _process(delta):
	if estado_actual:
		estado_actual.actualizar(delta)

func _physics_process(delta):
	if estado_actual:
		estado_actual.actualizar_fisica(delta)

# Cambiar de un estado a otro
func _on_transicion_solicitada(estado_llamador, nuevo_estado_nombre: String):
	if estado_llamador != estado_actual:
		return # Por seguridad, ignorar si un estado inactivo pide cambio
		
	var nombre_minuscula = nuevo_estado_nombre.to_lower()
	if not estados.has(nombre_minuscula):
		push_warning("Intento de transición a un estado que no existe: ", nuevo_estado_nombre)
		return
		
	if estado_actual:
		estado_actual.salir()
		
	estado_actual = estados[nombre_minuscula]
	estado_actual.entrar()

# Función para que el Nivel/Mapa pueda forzar un cambio de estado
func forzar_estado(nuevo_estado_nombre: String):
	var nombre_minuscula = nuevo_estado_nombre.to_lower()
	if not estados.has(nombre_minuscula):
		return
		
	if estado_actual:
		estado_actual.salir()
		
	estado_actual = estados[nombre_minuscula]
	estado_actual.entrar()
