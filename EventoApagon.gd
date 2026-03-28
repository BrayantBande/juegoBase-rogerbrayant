extends Area3D

@export var luces_del_pasillo: Array[Node3D]

@export_category("Ritmo de Terror")
@export var tiempo_inicial: float = 1.0 # 1 segundo entero de pausa y suspenso brutal para asimilar el ambiente
@export var aceleracion: float = 0.85 # Al subir este número (0.85), evitas que enloquezcan. (Poner 1.0 quitará la aceleración por completo).

@export_category("Sonido Brutal")
@export var sonido_grito_inicial: AudioStream # Tu grito de monstruo de 3 segundos
@export var sonido_puerta_final: AudioStream # === NUEVO: Puertazo al quedar a oscuras ===
@export var tiempo_espera_antes_de_apagon: float = 3.0 # Cooldown genial: segundos que pasan desde el grito hasta el primer apagón

@export_category("Retorno a la Normalidad")
@export var restaurar_luces_al_final: bool = true # ¿Volver a encenderlas al final del susto?
@export var tiempo_a_oscuras: float = 5.0 # Mantiene todo el pasillo en oscuridad mortal por 5 segundos
@export var velocidad_de_encendido: float = 0.25 # Segundos que tarda en ir encendiendo secuencialmente cada luz

@export_category("Sonido Brutal")
@export var sonido_apagon: AudioStream # El .wav de los chispazos
@export var volumen_extra: float = 24.0

var evento_disparado = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if evento_disparado or body.name != "Player":
		return
		
	evento_disparado = true

	# === LA MAGIA DEL GRITO (EN 3D AL FINAL DEL PASILLO) ===
	if sonido_grito_inicial != null and luces_del_pasillo.size() > 0:
		var luz_fondo = luces_del_pasillo.back() # Ubicamos la luz más lejana
		
		if is_instance_valid(luz_fondo):
			var grito = AudioStreamPlayer3D.new() # Ahora es 3D para que suene lejos pero realista
			grito.stream = sonido_grito_inicial
			grito.volume_db = 24.0 # Fuerte porque viene de lejos
			grito.max_distance = 600.0
			grito.unit_size = 35.0 # Para que la atenuación no le robe toda la fuerza
			
			luz_fondo.add_child(grito)
			grito.play()
			grito.finished.connect(grito.queue_free)
			
		# ¡COOLDOWN DE TERROR! Silencio mortal mientras asimila lo que escuchó a lo lejos.
		await get_tree().create_timer(tiempo_espera_antes_de_apagon).timeout
	# ==========================================================

	var tiempo_de_espera = tiempo_inicial
	
	for luz in luces_del_pasillo:
		if is_instance_valid(luz):
			
			# AUDIO SÚPER POTENTE
			if sonido_apagon != null:
				var parlante_3d = AudioStreamPlayer3D.new()
				parlante_3d.stream = sonido_apagon
				parlante_3d.volume_db = volumen_extra # Aplicar tu volumen infernal
				parlante_3d.max_distance = 80.0 
				
				luz.add_child(parlante_3d) 
				parlante_3d.play()
				parlante_3d.finished.connect(parlante_3d.queue_free)
			
			# MATAR LA LUZ
			if luz.has_method("set_lights_energy"):
				luz.set_lights_energy(0.0)
				luz.flickering_enabled = false
				luz.set_process(false) 
			else:
				luz.visible = false
				
		# Esperar antes de apagar la que sigue
		await get_tree().create_timer(tiempo_de_espera).timeout
		
		# LA ACELERACIÓN
		# Multiplica el tiempo, logrando un ritmo descontrolado al final (baja hasta un mínimo de 0.08 segundos)
		tiempo_de_espera = max(0.08, tiempo_de_espera * aceleracion)
		
	# === FINAL DEL EVENTO: ¿VUELVE LA LUZ? ===
	if restaurar_luces_al_final:
		# Todo queda en completa oscuridad y silencio sepulcral durante X segundos
		await get_tree().create_timer(tiempo_a_oscuras).timeout
		
		# La luz vuelve progresivamente a todo el pasillo (como una ola)
		for luz in luces_del_pasillo:
			if is_instance_valid(luz):
				if luz.has_method("set_lights_energy"):
					# Recobran la vida
					luz.set_process(true)
					luz.flickering_enabled = true
					luz.set_lights_energy(1.0)
				else:
					luz.visible = true
			
			# Retraso para que no enciendan todas de golpe
			await get_tree().create_timer(velocidad_de_encendido).timeout
	# ========================================
