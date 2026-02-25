extends CharacterBody3D

# --- SEÑALES (Comunicación con la UI y otros sistemas) ---
# El jugador grita "¡Cambió mi estamina!" y la UI lo escucha para mover la barra.
signal stamina_changed(actual, maxima)
signal health_changed(actual, maxima)
signal interaction_detected(texto)
signal interaction_cleared()
signal toggle_inventory()
signal toggle_pause()

# --- ESTADÍSTICAS DEL PACIENTE 018 ---
var salud_maxima = 100.0
var salud_actual = 100.0

var estamina_maxima = 100.0
var estamina_actual = 100.0
var consumo_estamina = 20.0  
var recarga_estamina = 14.28 

var tiempo_sin_correr = 0.0 
var espera_recarga = 3.0    

# --- MOVIMIENTO ---
const VELOCIDAD_CAMINAR = 3.5
const VELOCIDAD_CORRER = 7.0
var velocidad_actual = VELOCIDAD_CAMINAR 
const JUMP_VELOCITY = 4.5
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

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * SENSITIVITY
		camara.rotation.x -= event.relative.y * SENSITIVITY
		camara.rotation.x = clamp(camara.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _input(event):
	if event.is_action_pressed("pausa"):
		toggle_pause.emit() # Le avisa al menú de pausa que debe abrirse
		
	if event.is_action_pressed("linterna") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		linterna.visible = not linterna.visible
		
	if event.is_action_pressed("inventario"):
		toggle_inventory.emit() # Le avisa al inventario que debe abrirse

func _physics_process(delta):
	# 1. Aplicar la gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Manejar el Salto
	# (Cambia "ui_accept" por el nombre de tu tecla de salto si usas otra, como "saltar")
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY # O la variable que uses para la fuerza del salto
		anim.play("Jump/Jump")
# (Cambia "correr" por el nombre de tu input en el mapa de controles, por ejemplo "sprint")
	if Input.is_action_pressed("correr") and is_on_floor():
		velocidad_actual = VELOCIDAD_CORRER
	else:
		velocidad_actual = 3.0 # PON AQUÍ TU VELOCIDAD DE CAMINAR (o tu variable VELOCIDAD_CAMINAR)
	# ----------------------------------------------

	# 3. Obtener la dirección de entrada
	# (Cambia los "ui_..." si tienes nombres personalizados como "mover_adelante")
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 4. Movimiento y Animaciones de Caminar/Correr/Quieto
	if direction:
		velocity.x = direction.x * velocidad_actual
		velocity.z = direction.z * velocidad_actual
		
		# Solo cambiamos animación de caminar/correr si estamos tocando el piso
		# (Para no interrumpir la animación de salto mientras estamos en el aire)
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
