extends CharacterBody3D

# Variables de velocidad que usarán los estados
@export var velocidad_caminar: float = 1.5
@export var velocidad_correr: float = 4
var ultima_posicion_conocida: Vector3
var gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")

# Referencias a sus herramientas para que los estados puedan usarlas
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_raycast: RayCast3D = $Vision
@onready var anim = $EnemigoModel/AnimationPlayer
@onready var grito_audio = $GritoAudio

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta
	# Si el monstruo se está moviendo...
	if velocity.length() > 0.1:
		# Calculamos el ángulo hacia el que se dirige (ignorando la altura Y)
		var angulo_objetivo = atan2(velocity.x, velocity.z)
		
		# Lo rotamos suavemente hacia ese ángulo (el "10.0" es la velocidad de giro)
		rotation.y = lerp_angle(rotation.y, angulo_objetivo, delta * 10.0)
