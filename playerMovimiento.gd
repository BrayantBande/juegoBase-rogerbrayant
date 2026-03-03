extends CharacterBody3D # [cite: 59]


signal stamina_changed(actual, maxima)
signal health_changed(salud_actual, salud_maxima)
signal interaction_detected(texto)
signal interaction_cleared()
signal toggle_inventory()
signal toggle_pause()
signal battery_changed(actual, maxima)


var bateria_maxima = 100.0
var bateria_actual = 100.0
var consumo_bateria = 3.0 
var linterna_encendida: bool = false


var salud_maxima: float = 100.0
var salud_actual: float = 100.0

var estamina_maxima = 100.0
var estamina_actual = 100.0
var consumo_estamina = 20.0  
var recarga_estamina = 14.28 

var tiempo_sin_correr = 0.0 
var espera_recarga = 3.0   
var esta_a_salvo: bool = false 


const VELOCIDAD_AGACHADO = 1.0
const VELOCIDAD_CAMINAR = 1.5
const VELOCIDAD_CORRER = 4.0
var nivel_ruido = 0.0 
var velocidad_actual = VELOCIDAD_CAMINAR 
const SENSITIVITY = 0.003 

# --- CONFIGURACIÓN ESTILO TJOC ---
const BOB_FREQ = 3.5 
const BOB_AMP = 0.12 
const TILT_AMP = 0.001 
var t_bob = 0.0

# ¡NUEVO! Variables para agacharse
var esta_agachado: bool = false
var altura_normal: float = 2.0
var altura_agachado: float = 1.0
var altura_camara_normal: float = 1.5
var altura_camara_agachada: float = 0.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- NODOS ---
@onready var sonido_linterna = $Cabeza/Camera3D/Linterna/"ENCENDER-APAGAR"
@onready var anim = $PlayerT/AnimationPlayer
@onready var camara = $Cabeza/Camera3D 
@onready var linterna = $Cabeza/Camera3D/Linterna 
@onready var rayo_interaccion = $Cabeza/Camera3D/RayoInteraccion
@onready var sonido_recoger = $SonidoRecoger

# ¡NUEVO! Nodos para las físicas de agacharse
@onready var colision = $CollisionShape3D
@onready var detector_techo = $DetectorTecho # Lo crearemos en la escena

# --- VARIABLES DE ESTADO ---
var mirando_item = false
func _head_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	# Movimiento vertical (Y)
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	# Movimiento horizontal (X)
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	# Inclinación lateral (Z) - El toque secreto de TJoC
	pos.z = sin(time * BOB_FREQ / 2) * TILT_AMP
	return pos
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	rayo_interaccion.add_exception(self)
	
	detector_techo.add_exception(self)
	# Guardamos la altura original de la cámara basándonos en tu escena
	altura_camara_normal = camara.position.y
	
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
		toggle_pause.emit() 
		
	if event.is_action_pressed("linterna") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		sonido_linterna.play()
		if linterna.visible:
			linterna.visible = false
			linterna_encendida = false
		elif bateria_actual > 0:
			linterna.visible = true
			linterna_encendida = true
		
	if event.is_action_pressed("inventario"):
		toggle_inventory.emit() 

func _physics_process(delta):
	#func _physics_process(delta):
	# 1. Referencias fundamentales
	var collision = $CollisionShape3D 
	var hay_techo = $DetectorTecho.is_colliding() # Asegúrate que el nombre sea exacto

	# 2. Lógica de Head Bob TJoC
	t_bob += delta * velocity.length() * float(is_on_floor())
	var target_vars = _head_bob(t_bob)
	
	var altura_base = 1.5 
	if collision.shape.height == altura_agachado:
		altura_base = 0.5 

	# Aplicamos posición (X, Y) y la rotación lateral (Z)
	camara.transform.origin.y = lerp(camara.transform.origin.y, altura_base + target_vars.y, delta * 8.0)
	camara.transform.origin.x = lerp(camara.transform.origin.x, target_vars.x, delta * 8.0)
	
	# El lerp_angle hace que el balanceo de la cámara sea fluido
	camara.rotation.z = lerp_angle(camara.rotation.z, target_vars.z, delta * 5.0)
	if not is_on_floor():
		velocity.y -= gravity * delta
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# --- ¡NUEVO! LÓGICA DE AGACHARSE ---
	if Input.is_action_pressed("agacharse"):
		esta_agachado = true
	else:
		# Solo se levanta si no hay un techo (ej. una mesa) bloqueándolo
		if not detector_techo.is_colliding():
			esta_agachado = false
			
	# Transición suave (Lerp) de la cámara y la colisión
	if esta_agachado:
		# Achicamos la colisión Y bajamos su centro para que los pies toquen el suelo
		colision.shape.height = lerp(colision.shape.height, altura_agachado, delta * 8.0)
		colision.position.y = lerp(colision.position.y, altura_agachado / 2.0, delta * 8.0)
		
		# Bajamos la cámara a una altura decente (ajusta este 0.8 si quieres estar más alto o bajo)
		camara.position.y = lerp(camara.position.y, 0.8, delta * 8.0)
	else:
		# Volvemos a la altura normal y subimos el centro de la colisión
		colision.shape.height = lerp(colision.shape.height, altura_normal, delta * 8.0)
		colision.position.y = lerp(colision.position.y, altura_normal / 2.0, delta * 8.0)
		
		# La cámara vuelve a su posición original
		camara.position.y = lerp(camara.position.y, altura_camara_normal, delta * 8.0)
	# ------------------------------------

	# --- 3. SISTEMA DE ESTAMINA, SPRINT Y SIGILO ---
	if esta_agachado:
		velocidad_actual = VELOCIDAD_AGACHADO
		if direction != Vector3.ZERO:
			nivel_ruido = 1.0 # ¡Es súper silencioso al gatear!
		else:
			nivel_ruido = 0.0
			
	elif Input.is_action_pressed("correr") and is_on_floor() and direction != Vector3.ZERO and estamina_actual > 0:
		velocidad_actual = VELOCIDAD_CORRER
		nivel_ruido = 15.0 
		estamina_actual -= consumo_estamina * delta
		tiempo_sin_correr = 0.0 
		stamina_changed.emit(estamina_actual, estamina_maxima) 
	else:
		velocidad_actual = VELOCIDAD_CAMINAR
		if direction != Vector3.ZERO:
			nivel_ruido = 3.0 
		else:
			nivel_ruido = 0.0
		
	# Sistema de recarga de estamina
	if not Input.is_action_pressed("correr") and estamina_actual < estamina_maxima:
		tiempo_sin_correr += delta 
		if tiempo_sin_correr >= espera_recarga:
			estamina_actual += recarga_estamina * delta
			if estamina_actual > estamina_maxima:
				estamina_actual = estamina_maxima
			stamina_changed.emit(estamina_actual, estamina_maxima) 
	# ----------------------------------------------

	# 4. Movimiento y Animaciones
	if direction:
		velocity.x = direction.x * velocidad_actual
		velocity.z = direction.z * velocidad_actual
		
		if is_on_floor():
			# (Si tienes una animación de agachado, la puedes poner aquí)
			if velocidad_actual == VELOCIDAD_CORRER:
				if anim.current_animation != "Run/Run":
					anim.play("Run/Run")
			elif velocidad_actual == VELOCIDAD_CAMINAR:
				if anim.current_animation != "Walking/Walking":
					anim.play("Walking/Walking")
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad_actual)
		velocity.z = move_toward(velocity.z, 0, velocidad_actual)
		
		if is_on_floor() and anim.current_animation != "Idle/Idle":
			anim.play("Idle/Idle")

	move_and_slide() # [cite: 60]
	
func _process(_delta):
	# --- SISTEMA DE LINTERNA ---
	if linterna.visible and bateria_actual > 0:
		bateria_actual -= consumo_bateria * _delta # [cite: 72]
		battery_changed.emit(bateria_actual, bateria_maxima)
		
		if bateria_actual < 20.0:
			linterna.light_energy = lerp(0.1, 1.0, bateria_actual / 20.0)
			
		if bateria_actual <= 0:
			bateria_actual = 0
			linterna.visible = false
			linterna_encendida = false 
			linterna.light_energy = 1.0 
		
	# --- SISTEMA DE INTERACCIÓN LIMPIO ---
	if rayo_interaccion.is_colliding():
		var objeto_mirado = rayo_interaccion.get_collider()
		
		if is_instance_valid(objeto_mirado):
			if objeto_mirado.has_method("recoger"):
				if not mirando_item:
					var nombre_mostrar = objeto_mirado.name
					if "item_recurso" in objeto_mirado and objeto_mirado.item_recurso:
						nombre_mostrar = objeto_mirado.item_recurso.nombre_item
					
					interaction_detected.emit("[E] Recoger " + nombre_mostrar)
					mirando_item = true
				
				if Input.is_action_just_pressed("interactuar"):
					if sonido_recoger.stream != null:
						sonido_recoger.play()
					
					objeto_mirado.recoger() 
					
					interaction_cleared.emit()
					mirando_item = false
			else:
				if mirando_item:
					interaction_cleared.emit()
					mirando_item = false
	else:
		if mirando_item:
			interaction_cleared.emit()
			mirando_item = false

func recargar_linterna(cantidad):
	bateria_actual += cantidad
	if bateria_actual > bateria_maxima:
		bateria_actual = bateria_maxima
		
	linterna.light_energy = 1.0
	battery_changed.emit(bateria_actual, bateria_maxima)
	
func recibir_dano(cantidad: float):
	salud_actual -= cantidad
	health_changed.emit(salud_actual, salud_maxima)
	print("¡Ay! Recibí daño. Salud restante: ", salud_actual)
	
func cambiar_color_linterna(color_nuevo: Color):
	linterna.light_color = color_nuevo
