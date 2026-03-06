extends CharacterBody3D

# Variables de velocidad que usarán los estados
@export var velocidad_caminar: float = 1.5
# Sonidos
@export var audios_ambiente: Array[AudioStream]
@export var audios_ataque: Array[AudioStream]

var ultima_posicion_conocida: Vector3
var gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")

# Referencias a sus herramientas para que los estados puedan usarlas
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_raycast: RayCast3D = $Vision
@onready var anim = $EnemigoModel/AnimationPlayer
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

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta
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
					temporizador_pasos = 0.35 # Medio segundo entre pasos al correr
				else:
					pasos_audio.pitch_scale = randf_range(0.95, 1.1)
					temporizador_pasos = 0.65 # Casi un segundo entre pasos al caminar
					
				pasos_audio.play()
