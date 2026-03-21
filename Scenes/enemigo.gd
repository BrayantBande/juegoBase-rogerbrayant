extends CharacterBody3D

# Variables de velocidad que usarán los estados
@export var velocidad_caminar: float = 1.5
@export var velocidad_correr: float = 3.5
# Sonidos
@export var audios_ambiente: Array[AudioStream]
@export var audios_ataque: Array[AudioStream]

var ultima_posicion_conocida: Vector3
var gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")

# Referencias a sus herramientas para que los estados puedan usarlas
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_raycast: RayCast3D = $Vision
@onready var anim: AnimationPlayer = $IdleEnemigo/AnimationPlayer
@onready var grito_audio = $GritoAudio
@onready var pasos_audio = $PasosAudio
@onready var ambiente_audio = $AmbienteAudio

var temporizador_pasos: float = 0.0

func _ready():
	# Configuración de físicas para subir escaleras igual que el jugador
	floor_constant_speed = false
	floor_block_on_wall = false
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.2
	safe_margin = 0.08

	# --- CARGAR ANIMACIONES NUEVAS DE GABRIEL ---
	var current_global = anim.get_animation_library("")
	var new_global = AnimationLibrary.new()
	
	if current_global:
		for anim_name in current_global.get_animation_list():
			var a = current_global.get_animation(anim_name)
			new_global.add_animation(anim_name, a)
			if "Idle" in anim_name or "idle" in anim_name:
				if not new_global.has_animation("idle_anim"):
					new_global.add_animation("idle_anim", a)

	# Función lambda auxiliar para extraer la animación del archivo .res
	# (ya que el archivo podría exportarse como Animation o como AnimationLibrary entero)
	var load_anim_res = func(res_path: String, target_name: String):
		var res = load(res_path)
		var anim: Animation = null
		
		if res is AnimationLibrary:
			var anims = res.get_animation_list()
			if anims.size() > 0:
				anim = res.get_animation(anims[0])
		elif res is Animation:
			anim = res
			
		if anim != null:
			# --- ELIMINAR ROOT MOTION (MOVIMIENTO FANTASMA/LIBRE) ---
			# Si las animaciones se programaron para desplazarse por el espacio
			# bloqueamos sus ejes X y Z para que se mantenga "En el Sitio"
			for t in range(anim.get_track_count()):
				var path = String(anim.track_get_path(t))
				if path.ends_with(":position"):
					# Detectamos huesos principales
					if "Hips" in path or "Root" in path or "Pelvis" in path or "mixamorig" in path or path.get_file() == "position":
						for k in range(anim.track_get_key_count(t)):
							var val = anim.track_get_key_value(t, k)
							if typeof(val) == TYPE_VECTOR3:
								val.x = 0
								val.z = 0 # Anula el avance de arrastre
								anim.track_set_key_value(t, k, val)
								
			new_global.add_animation(target_name, anim)

	load_anim_res.call("res://Enemigo/Gabriel/AttackAnim.res", "attack_anim")
	load_anim_res.call("res://Enemigo/Gabriel/crawlAnim.res", "crawl_anim")
	load_anim_res.call("res://Enemigo/Gabriel/runAnim.res", "run_anim")
	load_anim_res.call("res://Enemigo/Gabriel/runCrawlAnim.res", "run_crawl_anim")
	load_anim_res.call("res://Enemigo/Gabriel/walkAnim.res", "walk_anim")
	
	# --- FORZAR LOOPING ---
	# Por si las animaciones de Gabriel no se exportaron marcadas con "Bucle" / "Loop"
	for n in ["walk_anim", "run_anim", "crawl_anim", "run_crawl_anim", "idle_anim"]:
		if new_global.has_animation(n):
			new_global.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			
	if current_global:
		anim.remove_animation_library("")
	anim.add_animation_library("", new_global)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta
		
	# --- SISTEMA DE EMERGENCIA: SI BORRARON EL NAVMESH, EL ENEMIGO NO SE MUEVE ---
	var mapa_nav = get_world_3d().get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(mapa_nav) == 0:
		velocity.x = move_toward(velocity.x, 0, delta * 15.0)
		velocity.z = move_toward(velocity.z, 0, delta * 15.0)
		
		# Forzamos relajación
		if is_on_floor() and anim.current_animation != "idle_anim":
			anim.play("idle_anim", 0.3)
			
		move_and_slide()
		return
	# -----------------------------------------------------------------------------
		
	# Si el monstruo se está moviendo lo suficiente...
	var flat_velocity = Vector2(velocity.x, velocity.z)
	if flat_velocity.length() > 0.2:
		# Calculamos el ángulo hacia el que se dirige en base al Vector2D plano
		var angulo_objetivo = atan2(flat_velocity.x, flat_velocity.y)
		
		# Lo rotamos suavemente hacia ese ángulo (el "4.0" es la velocidad de giro más natural)
		rotation.y = lerp_angle(rotation.y, angulo_objetivo, delta * 4.0)
		
		# --- SISTEMA DE PASOS DINÁMICOS ---
		# Calculamos qué tan rápido va (de 0.0 a 4.0 normalmente)
		var rapidez_actual = flat_velocity.length()
		
		# Solo suenan pasos si de verdad avanza (evitamos pasos mientras tiembla quieto)
		if rapidez_actual > 0.5:
			temporizador_pasos -= delta
			
			if temporizador_pasos <= 0.0:
				# Si corre (S4, rapidez por encima de 2.0), el tono es más rápido y suena antes. Si camina, más natural.
				if rapidez_actual > 2.0:
					pasos_audio.pitch_scale = randf_range(1.15, 1.35)
					temporizador_pasos = 0.28 # MÁS RÁPIDO: Casi 3 pasos por segundo al correr
				else:
					pasos_audio.pitch_scale = randf_range(0.95, 1.1)
					temporizador_pasos = 0.55 # Ajustado para la animación de caminar normal
					
				pasos_audio.play()
