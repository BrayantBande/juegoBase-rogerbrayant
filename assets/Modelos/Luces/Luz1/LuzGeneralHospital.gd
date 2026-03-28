extends Node3D

@export var flickering_enabled: bool = true
@export var base_energy: float = 0.7  
@export var fill_energy: float = 0.15 # ¡El misterioso brillo ambiental del techo!
@export var tiempo_mimimo: float = 2.0 
@export var tiempo_maximo: float = 10.0 
@export var probabilidad_apagada: float = 0.35 

@onready var light: Light3D = get_node_or_null("SpotLight3D")
@onready var fill_light: Light3D = get_node_or_null("OmniFill")

var timer: float = 0.0

func set_lights_energy(mult: float):
	if light: light.light_energy = base_energy * mult
	if fill_light: fill_light.light_energy = fill_energy * mult

func _ready():
	randomize() 
	
	if not light and not fill_light:
		set_process(false)
		return
		
	if randf() < probabilidad_apagada:
		set_lights_energy(0.0) 
		flickering_enabled = false
		set_process(false) 
	else:
		set_lights_energy(1.0)
		timer = randf_range(tiempo_mimimo, tiempo_maximo)

func _process(delta):
	if not flickering_enabled:
		set_lights_energy(1.0)
		return
		
	timer -= delta
	if timer <= 0.0:
		timer = randf_range(tiempo_mimimo, tiempo_maximo)
		
		var chance = randf()
		if chance < 0.2:
			set_lights_energy(0.0) 
		else:
			set_lights_energy(0.3) 
	else:
		set_lights_energy(1.0 + randf_range(-0.02, 0.02))
