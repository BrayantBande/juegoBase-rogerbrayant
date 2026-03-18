extends CharacterBody3D # [cite: 59]


signal stamina_changed(actual, maxima)
signal health_changed(salud_actual, salud_maxima)
signal interaction_detected(texto)
signal interaction_cleared()
signal toggle_inventory()
signal toggle_pause()
signal battery_changed(actual, maxima)
signal toggle_mod_menu()


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
var sensitivity_x: float = 0.003
var sensitivity_y: float = 0.003
# --- CONFIGURACIÓN ESTILO TJOC ---
const BOB_FREQ = 6.5 
const BOB_AMP = 0.12 
const TILT_AMP = 0.001 
var t_bob = 0.0

# ¡NUEVO! Variables para agacharse
var esta_agachado: bool = false
var altura_normal: float = 2.40 # La altura física del jugador
var altura_agachado: float = 1.20 # A la mitad
var altura_camara_normal: float = 2.25 # Los ojos un poco debajo del tope de la cabeza
var altura_camara_agachada: float = 1.05 # Ojos al estar agachado

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- NODOS ---
@onready var sonido_linterna = $Cabeza/Camera3D/Linterna/"ENCENDER-APAGAR"
@onready var anim = $PlayerT/AnimationPlayer
@onready var camara = $Cabeza/Camera3D 
@onready var linterna = $Cabeza/Camera3D/Linterna 
@onready var rayo_interaccion = $Cabeza/Camera3D/RayoInteraccion
@onready var sonido_recoger = $SonidoRecoger
@onready var modelo_linterna = $Cabeza/Camera3D/Sketchfab_Scene

# ¡NUEVO! Nodos para las físicas de agacharse
@onready var colision = $CollisionShape3D
@onready var detector_techo = $DetectorTecho # Lo crearemos en la escena

# --- SISTEMA DE AUDIO (PASOS Y RESPIRACIÓN) ---
@export_category("Audios Player")
@export var sonidos_pasos_default: Array[AudioStream]
@export var sonidos_pasos_madera: Array[AudioStream]
@export var sonidos_pasos_metal: Array[AudioStream]
@export var sonido_respiracion_agitada: AudioStream

@onready var raycast_piso = $RayCastPiso
@onready var audio_pasos = $PasosPlayer
@onready var audio_respiracion = $RespiracionPlayer

var tiempo_ultimo_paso = 0.0
var esta_respirando_agitado = false

# --- VARIABLES DE ESTADO ---
var estaba_agachado = false # Para detectar transiciones
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
	_cargar_preferencias()
	
	# Forzamos los valores del script por encima de los de la escena de Godot
	colision.shape.height = altura_normal
	colision.position.y = altura_normal / 2.0
	camara.position.y = altura_camara_normal
	
	# --- MEJORAS DE FÍSICAS PARA ESCALERAS ---
	floor_snap_length = 0.5 # Fuerza al personaje a "pegarse" al suelo al bajar escalones
	floor_constant_speed = false # Evita que se atore la velocidad al chocar con escalones subiendo
	floor_block_on_wall = false # Permite que el control de físicas resbale suavemente si golpea los bordes
	floor_max_angle = deg_to_rad(60.0) # Aumentado a 60 grados para evitar que se considere pared
	floor_stop_on_slope = true # Ayudará a no resbalar hacia abajo
	# -----------------------------------------
	
	health_changed.emit(salud_actual, salud_maxima)
	stamina_changed.emit(estamina_actual, estamina_maxima)
	battery_changed.emit(bateria_actual, bateria_maxima)
	linterna.visible = false
	
	# Escuchamos cambios en el inventario para mostrar/ocultar el modelo
	InventoryManager.inventory_updated.connect(_actualizar_visibilidad_modelo)
	_actualizar_visibilidad_modelo()
	
	# Desactivamos la sombra que proyecta el modelo 3D de la linterna
	_desactivar_sombras_hijos(modelo_linterna)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensitivity_x
		camara.rotation.x -= event.relative.y * sensitivity_y
		camara.rotation.x = clamp(camara.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _input(event):
	if event.is_action_pressed("pausa"):
		toggle_pause.emit() 
		
	if event.is_action_pressed("linterna") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Solo permitimos encender si tiene alguna de las dos linternas
		if InventoryManager.tiene_item("LINTERNA") or InventoryManager.tiene_item("UV_FLASHLIGHT"):
			sonido_linterna.play()
			if linterna.visible:
				linterna.visible = false
				linterna_encendida = false
			elif bateria_actual > 0:
				linterna.visible = true
				linterna_encendida = true
		else:
			# Opcional: Podrías poner un sonido de "error" o un mensaje corto
			print("No tienes una linterna en el inventario.")

func _physics_process(delta):
	#func _physics_process(delta):
	# 1. Referencias fundamentales
	var collision = $CollisionShape3D 
	var hay_techo = $DetectorTecho.is_colliding() # Asegúrate que el nombre sea exacto

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# --- ¡NUEVO! LÓGICA DE AGACHARSE Y ALTURA ---
	if Input.is_action_pressed("agacharse"):
		esta_agachado = true
	else:
		# Solo se levanta si no hay un techo (ej. una mesa) bloqueándolo
		if not detector_techo.is_colliding():
			esta_agachado = false
			
	var target_altura_cam = altura_camara_normal
	var target_altura_col = altura_normal
	
	if esta_agachado:
		target_altura_cam = altura_camara_agachada
		target_altura_col = altura_agachado

	# 2. Lógica de Head Bob TJoC
	t_bob += delta * velocity.length() * float(is_on_floor())
	var target_vars = _head_bob(t_bob)

	# Transición suave (Lerp) de la colisión
	colision.shape.height = lerp(colision.shape.height, target_altura_col, delta * 8.0)
	colision.position.y = lerp(colision.position.y, target_altura_col / 2.0, delta * 8.0)
	
	# Transición suave de la cámara combinada con el Head Bob
	camara.transform.origin.y = lerp(camara.transform.origin.y, target_altura_cam + target_vars.y, delta * 8.0)
	camara.transform.origin.x = lerp(camara.transform.origin.x, target_vars.x, delta * 8.0)
	
	# El lerp_angle hace que el balanceo de la cámara sea fluido
	camara.rotation.z = lerp_angle(camara.rotation.z, target_vars.z, delta * 5.0)
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
	# Primero verificamos transiciones forzosas de la postura
	if is_on_floor():
		if esta_agachado and not estaba_agachado:
			anim.play("Crouching/Agachandose")
		elif not esta_agachado and estaba_agachado:
			anim.play("Crouching/Parandose")
	
	var en_transicion = anim.current_animation in ["Crouching/Agachandose", "Crouching/Parandose"]

	if direction:
		velocity.x = direction.x * velocidad_actual
		velocity.z = direction.z * velocidad_actual

		if is_on_floor() and not en_transicion:
			# Lógica de animación según la velocidad
			if velocidad_actual == VELOCIDAD_CORRER:
				if anim.current_animation != "Run/Run":
					anim.play("Run/Run")
			elif velocidad_actual == VELOCIDAD_AGACHADO:
				if anim.current_animation != "Crouching/Caminando_Agachado": 
					anim.play("Crouching/Caminando_Agachado")
			elif velocidad_actual == VELOCIDAD_CAMINAR:
				if anim.current_animation != "Walking/Walking":
					anim.play("Walking/Walking")
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad_actual)
		velocity.z = move_toward(velocity.z, 0, velocidad_actual)
		
		if is_on_floor() and not en_transicion:
			if esta_agachado:
				if anim.current_animation != "Crouching/AgachadoQuieto":
					anim.play("Crouching/AgachadoQuieto")
			else:
				if anim.current_animation != "Idle/Idle":
					anim.play("Idle/Idle")
					
	# Guardar memoria para el próximo ciclo
	estaba_agachado = esta_agachado

	move_and_slide() # [cite: 60]
	
	# --- SISTEMA DE PASOS ---
	if is_on_floor() and direction != Vector3.ZERO:
		tiempo_ultimo_paso += delta
		var intervalo_actual = 0.6
		var volumen_paso = 0.0
		var pitch_paso = 0.75 # ORIGINAL ERA 1.0 (Bajamos el Pitch para que suene más pesado y masculino)
		
		if velocidad_actual == VELOCIDAD_CORRER:
			intervalo_actual = 0.35
			volumen_paso = 5.0
			pitch_paso = 0.9 # ORIGINAL ERA 1.2
		elif velocidad_actual == VELOCIDAD_AGACHADO:
			intervalo_actual = 0.8
			volumen_paso = -6.0 # Subido de -15.0 para que se escuche algo, pero suave
			pitch_paso = 0.6 # ORIGINAL ERA 0.8
			
		if tiempo_ultimo_paso >= intervalo_actual:
			_reproducir_sonido_paso(volumen_paso, pitch_paso)
			tiempo_ultimo_paso = 0.0
	else:
		tiempo_ultimo_paso = 0.0
		
	# --- SISTEMA DE RESPIRACIÓN (ESTAMINA) ---
	# Empieza a respirar agitado al terminar de correr si la estamina bajó de un cierto límite (ej. se gastó mucho)
	if not Input.is_action_pressed("correr") and estamina_actual < (estamina_maxima * 0.2) and not esta_respirando_agitado:
		esta_respirando_agitado = true
		if audio_respiracion and sonido_respiracion_agitada:
			audio_respiracion.stream = sonido_respiracion_agitada
			audio_respiracion.play()
	# Se le quita la respiración agitada cuando recupera el 60% de la estamina para que empiece a calmarse
	elif estamina_actual >= estamina_maxima * 0.6 and esta_respirando_agitado:
		esta_respirando_agitado = false
		
func _process(_delta):
	# --- FADE OUT DE RESPIRACIÓN MUY GRADUAL ---
	if audio_respiracion:
		if esta_respirando_agitado:
			# Si está agitado, el volumen sube suavemente hasta 0 dB (volumen normal)
			audio_respiracion.volume_db = lerp(audio_respiracion.volume_db, 0.0, _delta * 2.0)
		else:
			# Si se está calmando, baja muuuuy lentamente hasta -40dB (silencio casi total)
			audio_respiracion.volume_db = lerp(audio_respiracion.volume_db, -40.0, _delta * 0.5)
			
			# Si ya casi no se escucha, apagamos el motor del audio
			if audio_respiracion.volume_db <= -38.0 and audio_respiracion.playing:
				audio_respiracion.stop()
				audio_respiracion.volume_db = 0.0 # Reseteo para la próxima carrera
				
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

func _actualizar_visibilidad_modelo():
	if InventoryManager.tiene_item("LINTERNA") or InventoryManager.tiene_item("UV_FLASHLIGHT"):
		modelo_linterna.visible = true
	else:
		modelo_linterna.visible = false

func teleport(nueva_pos: Vector3):
	global_position = nueva_pos
	velocity = Vector3.ZERO # Resetear inercia
	print("Teletransportado a: ", nueva_pos)

func _reproducir_sonido_paso(vol_db, pitch):
	if not audio_pasos or sonidos_pasos_default.is_empty():
		return
		
	var array_sonidos = sonidos_pasos_default
	var tipo_suelo = "Default"
	
	if raycast_piso and raycast_piso.is_colliding():
		var colisionador = raycast_piso.get_collider()
		if colisionador:
			if colisionador.is_in_group("superficie_madera") and not sonidos_pasos_madera.is_empty():
				array_sonidos = sonidos_pasos_madera
				tipo_suelo = "Madera"
			elif colisionador.is_in_group("superficie_metal") and not sonidos_pasos_metal.is_empty():
				array_sonidos = sonidos_pasos_metal
				tipo_suelo = "Metal"
				
	var sonido_azar = array_sonidos[randi() % array_sonidos.size()]
	audio_pasos.stream = sonido_azar
	audio_pasos.volume_db = vol_db
	audio_pasos.pitch_scale = pitch + randf_range(-0.1, 0.1) # Variación
	audio_pasos.play()
	
	if audio_pasos.stream and audio_pasos.stream.resource_path != "":
		print("Paso [", tipo_suelo, "]: ", audio_pasos.stream.resource_path.get_file())
	else:
		print("Paso [", tipo_suelo, "] reproducido.")

func _desactivar_sombras_hijos(nodo: Node):
	if nodo is GeometryInstance3D:
		nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for hijo in nodo.get_children():
		_desactivar_sombras_hijos(hijo)

func aplicar_sensibilidad(x: float, y: float):
	sensitivity_x = x
	sensitivity_y = y

func _cargar_preferencias():
	var file_path = "user://game_settings.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var dict = JSON.parse_string(file.get_as_text())
		file.close()
		if dict != null and typeof(dict) == TYPE_DICTIONARY:
			if dict.has("sensibilidad_ui_x"): sensitivity_x = float(dict["sensibilidad_ui_x"]) * 0.00075
			if dict.has("sensibilidad_ui_y"): sensitivity_y = float(dict["sensibilidad_ui_y"]) * 0.00075
