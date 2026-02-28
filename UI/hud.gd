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
	if panel_inventario.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
