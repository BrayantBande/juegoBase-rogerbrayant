extends CharacterBody3D

# --- ESTADÍSTICAS DEL SUPERVIVIENTE ---
var salud_maxima = 100.0
var salud_actual = 100.0

var estamina_maxima = 100.0
var estamina_actual = 100.0
var consumo_estamina = 20.0  # Gasta 100 puntos en exactamente 5 segundos
var recarga_estamina = 14.28 # Recupera 100 puntos en exactamente 7 segundos

# --- INVENTARIO LÓGICO (Temporal, lo cambiaremos pronto) ---
var gasolina = 0
var max_gasolina = 2
var madera = 0
var max_madera = 5 

# --- NUEVAS VARIABLES DE TIEMPO ---
var tiempo_sin_correr = 0.0 # Nuestro cronómetro oculto
var espera_recarga = 3.0    # Segundos de penalización antes de regenerar

# --- MOVIMIENTO ---
const VELOCIDAD_CAMINAR = 3.5
const VELOCIDAD_CORRER = 7.0
var velocidad_actual = VELOCIDAD_CAMINAR 
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003 # <--- Reduje un poco la sensibilidad para mayor precisión FPS

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- NODOS (¡Rutas Actualizadas para FPS!) ---
@onready var modelo = $mannequiny 
@onready var anim = $mannequiny/AnimationPlayer 

# LA CÁMARA AHORA ES DIRECTA (Adiós SpringArm3D)
@onready var camara = $Camera3D 
@onready var linterna = $Camera3D/Linterna 
@onready var rayo_interaccion = $Camera3D/RayoInteraccion

@onready var menu_pausa = $MenuPausa 
@onready var capa_mira = $interfaz
@onready var barra_estamina = $interfaz/FondoEstamina/BarraEstamina
@onready var ancho_max_estamina = barra_estamina.size.x
@onready var barra_salud = $interfaz/FondoSalud/BarraSalud
@onready var ancho_max_salud = barra_salud.size.x
@onready var texto_interaccion = $interfaz/TextoInteraccion
@onready var panel_inventario = $interfaz/PanelInventario
@onready var texto_inventario = $interfaz/PanelInventario/TextoInventario
@onready var sonido_recoger = $SonidoRecoger

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	menu_pausa.hide()
	panel_inventario.hide()
	# Le decimos al láser que ignore el cuerpo del jugador
	rayo_interaccion.add_exception(self)

func _unhandled_input(event):
	# Solo rotamos la cámara si estamos jugando (ratón oculto)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		
		# 1. Rotación horizontal: Gira TODO el cuerpo del jugador
		rotation.y -= event.relative.x * SENSITIVITY
		
		# 2. Rotación vertical: Gira SOLO la cabeza (la cámara)
		camara.rotation.x -= event.relative.y * SENSITIVITY
		
		# 3. El candado del cuello (evita dar vueltas de 360 grados)
		camara.rotation.x = clamp(camara.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _input(event):
	if event.is_action_pressed("pausa"):
		var esta_pausado = not get_tree().paused
		get_tree().paused = esta_pausado
		menu_pausa.visible = esta_pausado
		capa_mira.visible = not esta_pausado
		if esta_pausado:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
	if event.is_action_pressed("linterna") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		linterna.visible = not linterna.visible
		
	# Abrir/Cerrar Inventario y liberar el ratón
	if event.is_action_pressed("inventario"):
		panel_inventario.visible = not panel_inventario.visible		
		if panel_inventario.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _physics_process(delta):
	# --- 1. SISTEMA AVANZADO DE ESTAMINA ---
	if Input.is_action_pressed("correr") and velocity.length() > 0 and estamina_actual > 0:
		velocidad_actual = VELOCIDAD_CORRER
		estamina_actual -= consumo_estamina * delta 
		tiempo_sin_correr = 0.0 
	else:
		velocidad_actual = VELOCIDAD_CAMINAR
		if estamina_actual < estamina_maxima:
			tiempo_sin_correr += delta 
			if tiempo_sin_correr >= espera_recarga:
				estamina_actual += recarga_estamina * delta 
				
	estamina_actual = clamp(estamina_actual, 0.0, estamina_maxima)

	# --- 2. FÍSICAS BÁSICAS Y ANIMACIÓN ---
	if not is_on_floor():
		velocity.y -= gravity * delta
		if anim.assigned_animation != "air_jump":
			anim.speed_scale = 1.0 
			anim.play("air_jump")

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * velocidad_actual
		velocity.z = direction.z * velocidad_actual
		
		if is_on_floor():
			if anim.assigned_animation != "run":
				anim.play("run")
				
			if velocidad_actual == VELOCIDAD_CORRER:
				anim.speed_scale = 1.0 
			else:
				anim.speed_scale = 0.55 
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad_actual)
		velocity.z = move_toward(velocity.z, 0, velocidad_actual)
		
		if is_on_floor() and anim.assigned_animation != "idle":
			anim.speed_scale = 1.0 
			anim.play("idle")

	move_and_slide()
	
func _process(delta):
	# --- BARRAS DE ESTADO ---
	var porcentaje_estamina = estamina_actual / estamina_maxima
	var ancho_objetivo = porcentaje_estamina * ancho_max_estamina
	barra_estamina.size.x = lerp(barra_estamina.size.x, ancho_objetivo, 15.0 * delta)
	
	var porcentaje_salud = salud_actual / salud_maxima
	var ancho_objetivo_salud = porcentaje_salud * ancho_max_salud
	barra_salud.size.x = lerp(barra_salud.size.x, ancho_objetivo_salud, 15.0 * delta)
	
	if porcentaje_salud <= 0.25:
		barra_salud.color = Color.RED      
	elif porcentaje_salud <= 0.50:
		barra_salud.color = Color.ORANGE   
	else:
		barra_salud.color = Color.GREEN    

	# --- SISTEMA DE INTERACCIÓN ---
	var mirando_item = false 
	
	if rayo_interaccion.is_colliding():
		var objeto_mirado = rayo_interaccion.get_collider()
		
		if is_instance_valid(objeto_mirado):
			var es_gasolina = "Gasolina" in objeto_mirado.name
			var es_madera = "Madera" in objeto_mirado.name
			
			if es_gasolina or es_madera:
				mirando_item = true 
				
				var esta_lleno = false
				if es_gasolina and gasolina >= max_gasolina:
					esta_lleno = true
				elif es_madera and madera >= max_madera:
					esta_lleno = true
					
				if esta_lleno:
					texto_interaccion.text = "Inventario Lleno"
					texto_interaccion.modulate = Color.RED 
				else:
					texto_interaccion.text = "[E] Recoger " + objeto_mirado.name
					texto_interaccion.modulate = Color.WHITE
					
					if Input.is_action_just_pressed("interactuar"):
						if es_gasolina:
							gasolina += 1
						elif es_madera:
							madera += 1
							
						if sonido_recoger.stream != null:
							sonido_recoger.play()
							
						actualizar_inventario()
						objeto_mirado.queue_free()
						mirando_item = false 
						
	if mirando_item:
		texto_interaccion.show()
	else:
		texto_interaccion.hide()

func actualizar_inventario():
	texto_inventario.text = "Gasolina: " + str(gasolina) + "\nMadera: " + str(madera)
