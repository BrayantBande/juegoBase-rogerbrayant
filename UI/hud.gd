extends CanvasLayer

# --- NODOS DE LA UI ---
@onready var barra_estamina = $FondoEstamina/BarraEstamina
@onready var ancho_max_estamina = barra_estamina.size.x
@onready var barra_salud = $FondoSalud/BarraSalud
@onready var ancho_max_salud = barra_salud.size.x
@onready var texto_interaccion = $TextoInteraccion
@onready var panel_inventario = $PanelInventario
@onready var barra_bateria = $FondoBateria/BarraBateria
@onready var ancho_max_bateria = barra_bateria.size.x
@onready var mod_menu = $ModMenu
@onready var flash_image = $FlashImage
@onready var flash_audio = $FlashAudio

# Variables internas para animar (interpolar) las barras suavemente
var estamina_objetivo = 100.0
var estamina_max = 100.0
var salud_objetivo = 100.0
var salud_max = 100.0
var bateria_objetivo = 100.0
var bateria_max = 100.0

func _ready():
	# 1. Ocultar textos y menús al inicio
	panel_inventario.hide()
	mod_menu.hide()
	texto_interaccion.hide()
	
	# 2. Conectarse a las señales del Jugador automáticamente
	var player = get_parent()
	if player and player.name == "Player":
		player.stamina_changed.connect(_on_stamina_changed)
		player.health_changed.connect(_on_health_changed)
		player.battery_changed.connect(_on_battery_changed)
		player.interaction_detected.connect(_on_interaction_detected)
		player.interaction_cleared.connect(_on_interaction_cleared)
		player.toggle_inventory.connect(_on_toggle_inventory)
		player.toggle_mod_menu.connect(_on_toggle_mod_menu)
		mod_menu.closed.connect(_on_toggle_mod_menu)
		mod_menu.event_triggered.connect(_on_event_triggered)
		mod_menu.teleport_requested.connect(_on_teleport_requested)
		mod_menu.save_position_requested.connect(_on_save_position_requested)

func _on_save_position_requested(custom_name: String):
	var player = get_parent()
	if player:
		mod_menu.add_teleport_button(player.global_position, custom_name)

func _on_teleport_requested(pos: Vector3):
	var player = get_parent()
	if player and player.has_method("teleport"):
		player.teleport(pos)
		_on_toggle_mod_menu() # Cerrar el menú después de teletransportarse

func _input(event):
	if event.is_action_pressed("inventario"):
		_on_toggle_inventory()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		_on_toggle_mod_menu()

func _process(delta):
	# --- ANIMACIÓN SUAVE DE BARRAS ---
	var porcentaje_estamina = estamina_objetivo / estamina_max
	var ancho_est = porcentaje_estamina * ancho_max_estamina
	barra_estamina.size.x = lerp(barra_estamina.size.x, ancho_est, 15.0 * delta)
	
	var porcentaje_salud = salud_objetivo / salud_max
	var ancho_sal = porcentaje_salud * ancho_max_salud
	barra_salud.size.x = lerp(barra_salud.size.x, ancho_sal, 15.0 * delta)
	
	var porcentaje_bateria = bateria_objetivo / bateria_max
	var ancho_bat = porcentaje_bateria * ancho_max_bateria
	barra_bateria.size.x = lerp(barra_bateria.size.x, ancho_bat, 15.0 * delta)
	
	# Opcional: Que cambie de color si le queda poca
	if porcentaje_bateria <= 0.25:
		barra_bateria.color = Color.RED
	elif porcentaje_bateria <= 0.50:
		barra_bateria.color = Color.YELLOW
	else:
		barra_bateria.color = Color.LIGHT_YELLOW
	
	if porcentaje_salud <= 0.25:
		barra_salud.color = Color.RED
	elif porcentaje_salud <= 0.50:
		barra_salud.color = Color.ORANGE
	else:
		barra_salud.color = Color.GREEN

# --- FUNCIONES RECEPTORAS DE SEÑALES ---

func _on_stamina_changed(actual, maxima):
	estamina_objetivo = actual
	estamina_max = maxima

func _on_health_changed(actual, maxima):
	salud_objetivo = actual
	salud_max = maxima

func _on_battery_changed(actual, maxima):
	bateria_objetivo = actual
	bateria_max = maxima

func _on_interaction_detected(texto):
	texto_interaccion.text = texto
	texto_interaccion.show()

func _on_interaction_cleared():
	texto_interaccion.hide()

func _on_toggle_inventory():
	panel_inventario.visible = not panel_inventario.visible
	_actualizar_mouse_mode()

func _on_toggle_mod_menu():
	mod_menu.visible = not mod_menu.visible
	_actualizar_mouse_mode()

func _on_event_triggered(event_name: String):
	if event_name == "evento_1":
		_ejecutar_evento_1()
	elif event_name == "toggle_night_vision":
		_toggle_night_vision()

var nv_light: DirectionalLight3D = null

func _toggle_night_vision():
	var player = get_parent()
	if not player: return
	
	if nv_light == null:
		nv_light = DirectionalLight3D.new()
		nv_light.light_color = Color(1.0, 1.0, 1.0) # Luz blanca normal para ver todo claro
		nv_light.light_energy = 0.5
		nv_light.shadow_enabled = false
		player.add_child(nv_light)
	else:
		nv_light.visible = not nv_light.visible
		
	# Sonido opcional para el mod menu
	if flash_audio.stream == null:
		pass # Podríamos poner un sonido de click
	
	_on_toggle_mod_menu() # Cerrar menu al activar

func _ejecutar_evento_1():
	# 1. Cerrar el menú y resumir el juego
	_on_toggle_mod_menu()
	
	# 2. Esperar 2 segundos
	await get_tree().create_timer(2.0).timeout
	
	# 3. Iniciar audio
	if flash_audio.stream == null:
		flash_audio.stream = load("res://EVENTOS/EVENTO_1/AUDIO_FLASH.mp3")
	
	if flash_audio.stream:
		flash_audio.play()
	
	# 4. Parpadeo rápido durante 5 segundos
	var tiempo_total = 5.0
	var intervalo = 0.05
	var pasadas = int(tiempo_total / intervalo)
	
	for i in range(pasadas):
		flash_image.visible = not flash_image.visible
		await get_tree().create_timer(intervalo).timeout
	
	# 5. Asegurar que quede oculto al final
	flash_image.hide()

func _actualizar_mouse_mode():
	if panel_inventario.visible or mod_menu.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true # Opcional: Pausar el juego si el menú está abierto
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_tree().paused = false
