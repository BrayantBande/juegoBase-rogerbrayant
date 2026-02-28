extends CharacterBody3D

# --- SEÑALES (Comunicación con la UI y otros sistemas) ---
# El jugador grita "¡Cambió mi estamina!" y la UI lo escucha para mover la barra.
signal stamina_changed(actual, maxima)
signal health_changed(salud_actual, salud_maxima)
signal interaction_detected(texto)
signal interaction_cleared()
signal toggle_inventory()
signal toggle_pause()
signal battery_changed(actual, maxima) # La señal para la UI

# --- ESTADÍSTICAS LINTERNA ---
var bateria_maxima = 100.0
var bateria_actual = 100.0
var consumo_bateria = 3.0 # Cuánta energía gasta por segundo
var linterna_encendida: bool = false

# --- ESTADÍSTICAS DEL PACIENTE 018 ---
var salud_maxima: float = 100.0
var salud_actual: float = 100.0

var estamina_maxima = 100.0
var estamina_actual = 100.0
var consumo_estamina = 20.0  
var recarga_estamina = 14.28 

var tiempo_sin_correr = 0.0 
var espera_recarga = 3.0   
var esta_a_salvo: bool = false # Le dirá al monstruo que nos ignore 

# --- MOVIMIENTO ---
const VELOCIDAD_CAMINAR = 2.5
const VELOCIDAD_CORRER = 4.5
var nivel_ruido = 0.0 # Qué tan grande es la burbuja de ruido que hace Vance
var velocidad_actual = VELOCIDAD_CAMINAR 
const SENSITIVITY = 0.003 

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- NODOS ---
@onready var anim = $PlayerT/AnimationPlayer
@onready var camara = $Camera3D 
@onready var linterna = $Camera3D/Linterna 
@onready var rayo_interaccion = $Camera3D/RayoInteraccion
@onready var sonido_recoger = $SonidoRecoger

# --- VARIABLES DE ESTADO ---
var mirando_item = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	rayo_interaccion.add_exception(self)
	
	# Al inicio, le avisamos a la UI cómo están nuestras barras
	health_changed.emit(salud_actual, salud_maxima)
	stamina_changed.emit(estamina_actual, estamina_maxima)
	battery_changed.emit(bateria_actual, bateria_maxima)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * SENSITIVITY
		camara.rotation.x -= event.relative.y * SENSITIVITY
		camara.rotation.x = clamp(camara.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _input(event):
	if event.is_action_pressed("pausa"):
		toggle_pause.emit() # Le avisa al menú de pausa que debe abrirse
		
	if event.is_action_pressed("linterna") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Si ya está prendida, siempre te dejo apagarla
		if linterna.visible:
			linterna.visible = false
			linterna_encendida = false # <--- ¡AÑADIMOS ESTO!
		# Pero para prenderla, revisamos si tiene energía
		elif bateria_actual > 0:
			linterna.visible = true
			linterna_encendida = true # <--- ¡AÑADIMOS ESTO!
		
	if event.is_action_pressed("inventario"):
		toggle_inventory.emit() # Le avisa al inventario que debe abrirse

func _physics_process(delta):
	# 1. Aplicar la gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Obtener la dirección de entrada
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# --- 3. SISTEMA DE ESTAMINA Y SPRINT ---
	# Solo corremos si apretamos el botón, estamos en el piso, NOS ESTAMOS MOVIENDO y tenemos estamina
	if Input.is_action_pressed("correr") and is_on_floor() and direction != Vector3.ZERO and estamina_actual > 0:
		velocidad_actual = VELOCIDAD_CORRER
		nivel_ruido = 15.0 # ¡Vance hace mucho ruido al correr!
		estamina_actual -= consumo_estamina * delta
		tiempo_sin_correr = 0.0 
		stamina_changed.emit(estamina_actual, estamina_maxima) 
	else:
		velocidad_actual = VELOCIDAD_CAMINAR
		# Si se mueve hace un poco de ruido, si está quieto es silencioso
		if direction != Vector3.ZERO:
			nivel_ruido = 3.0 
		else:
			nivel_ruido = 0.0
		
		# Sistema de recarga de estamina (solo recarga si no estamos corriendo)
		if estamina_actual < estamina_maxima:
			tiempo_sin_correr += delta # Contamos cuánto tiempo llevamos sin correr
			
			# Si ya pasó el tiempo de espera (ej. 3 segundos), empezamos a recargar
			if tiempo_sin_correr >= espera_recarga:
				estamina_actual += recarga_estamina * delta
				if estamina_actual > estamina_maxima:
					estamina_actual = estamina_maxima
				stamina_changed.emit(estamina_actual, estamina_maxima) # Avisamos a la UI
	# ----------------------------------------------

	# 4. Movimiento y Animaciones de Caminar/Correr/Quieto
	if direction:
		velocity.x = direction.x * velocidad_actual
		velocity.z = direction.z * velocidad_actual
		
		# Solo cambiamos animación si estamos tocando el piso
		if is_on_floor():
			if velocidad_actual == VELOCIDAD_CORRER:
				if anim.current_animation != "Run/Run":
					anim.play("Run/Run")
			else:
				if anim.current_animation != "Walking/Walking":
					anim.play("Walking/Walking")
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad_actual)
		velocity.z = move_toward(velocity.z, 0, velocidad_actual)
		
		# Si no nos movemos y estamos en el piso, reproducir Idle
		if is_on_floor() and anim.current_animation != "Idle/Idle":
			anim.play("Idle/Idle")

	# 5. Aplicar todo el movimiento
	move_and_slide()
	
func _process(_delta):
	# --- SISTEMA DE LINTERNA ---
	if linterna.visible and bateria_actual > 0:
		bateria_actual -= consumo_bateria * _delta
		battery_changed.emit(bateria_actual, bateria_maxima)
		
		# Efecto de terror: La luz pierde fuerza si queda menos del 20%
		if bateria_actual < 20.0:
			linterna.light_energy = lerp(0.1, 1.0, bateria_actual / 20.0)
			
		# Si se apaga por completo
		if bateria_actual <= 0:
			bateria_actual = 0
			linterna.visible = false
			linterna_encendida = false # <--- ¡AÑADIMOS ESTO!
			linterna.light_energy = 1.0 # Reseteamos por si la recarga
		
	# --- 3. SISTEMA DE INTERACCIÓN LIMPIO ---
	if rayo_interaccion.is_colliding():
		var objeto_mirado = rayo_interaccion.get_collider()
		
		if is_instance_valid(objeto_mirado):
			# CAMBIO CLAVE: Ahora preguntamos si el objeto tiene la función "recoger"
			if objeto_mirado.has_method("recoger"):
				if not mirando_item:
					# Intentamos sacar el nombre real del objeto desde su recurso
					var nombre_mostrar = objeto_mirado.name
					if "item_recurso" in objeto_mirado and objeto_mirado.item_recurso:
						nombre_mostrar = objeto_mirado.item_recurso.nombre_item
					
					interaction_detected.emit("[E] Recoger " + nombre_mostrar)
					mirando_item = true
				
				if Input.is_action_just_pressed("interactuar"):
					if sonido_recoger.stream != null:
						sonido_recoger.play()
					
					# LLAMAMOS A LA FUNCIÓN DEL OBJETO (esto lo mete al inventario y lo borra)
					objeto_mirado.recoger() 
					
					interaction_cleared.emit()
					mirando_item = false
			else:
				# Si el rayo toca algo que NO se puede recoger, limpiamos el texto
				if mirando_item:
					interaction_cleared.emit()
					mirando_item = false
	else:
		# Si el rayo no toca nada, limpiamos el texto
		if mirando_item:
			interaction_cleared.emit()
			mirando_item = false
func recargar_linterna(cantidad):
	bateria_actual += cantidad
	if bateria_actual > bateria_maxima:
		bateria_actual = bateria_maxima
		
	# Reseteamos el brillo y avisamos a la UI
	linterna.light_energy = 1.0
	battery_changed.emit(bateria_actual, bateria_maxima)
	
func recibir_dano(cantidad: float):
	salud_actual -= cantidad
	health_changed.emit(salud_actual, salud_maxima)
	print("¡Ay! Recibí daño. Salud restante: ", salud_actual)
	
	if salud_actual <= 0:
		print("¡GAME OVER! El monstruo te atrapó.")
		# Reiniciamos la escena actual para volver a empezar
		get_tree().reload_current_scene()
