extends ColorRect

@onready var cuadricula = $ContenedorPrincipal/LadoIzquierdo/CuadriculaItems
@onready var lbl_nombre = $ContenedorPrincipal/PanelDetalles/NombreItem
@onready var lbl_descripcion = $ContenedorPrincipal/PanelDetalles/DescripcionItem

@onready var btn_claves = $ContenedorPrincipal/LadoIzquierdo/Pestañas/BtnClaves
@onready var btn_consumibles = $ContenedorPrincipal/LadoIzquierdo/Pestañas/BtnConsumibles
@onready var btn_notas = $ContenedorPrincipal/LadoIzquierdo/Pestañas/BtnNotas
@onready var btn_usar = $ContenedorPrincipal/PanelDetalles/BtnUsar
var item_seleccionado_actual = null # Para saber qué objeto queremos usar

# Referencia a la casilla visual que acabamos de crear
var slot_scene = preload("res://UI/InventorySlot.tscn") # <-- ASEGÚRATE DE QUE ESTA RUTA SEA CORRECTA

var pestana_actual: int = 1 # Empezamos viendo los Consumibles (1)

func _ready():
	# Conectamos las pestañas (0=Clave, 1=Consumible, 2=Nota)
	btn_claves.pressed.connect(_cambiar_pestana.bind(0))
	btn_consumibles.pressed.connect(_cambiar_pestana.bind(1))
	btn_notas.pressed.connect(_cambiar_pestana.bind(2))
	btn_usar.hide() # Lo escondemos hasta que selecciones algo
	btn_usar.pressed.connect(_on_btn_usar_pressed)
	
	# Escuchamos al cerebro del inventario
	InventoryManager.inventory_updated.connect(actualizar_ui)
	
	lbl_nombre.text = ""
	lbl_descripcion.text = "Selecciona un objeto..."

func _cambiar_pestana(nueva_pestana: int):
	pestana_actual = nueva_pestana
	lbl_nombre.text = ""
	lbl_descripcion.text = "Selecciona un objeto..."
	
	# --- NUEVO: Feedback Visual ---
	# Color Cian Reanimación para el activo: #40e0d0
	# Color Blanco Fantasmal para los inactivos: #555555
	btn_claves.modulate = Color("5c1e16ff") if nueva_pestana == 0 else Color("#555555")
	btn_consumibles.modulate = Color("5c1e16ff") if nueva_pestana == 1 else Color("#555555")
	btn_notas.modulate = Color("5c1e16ff") if nueva_pestana == 2 else Color("#555555")
	# ------------------------------
	
	actualizar_ui()

func actualizar_ui():
	# Limpiamos los slots viejos
	for child in cuadricula.get_children():
		child.queue_free()
		
	# Traemos los items de la pestaña que estamos mirando
	var items = InventoryManager.obtener_items_por_categoria(pestana_actual)
	
	for item in items:
		var nuevo_slot = slot_scene.instantiate()
		cuadricula.add_child(nuevo_slot)
		nuevo_slot.configurar_slot(item["data"], item["cantidad"])
		nuevo_slot.slot_clicked.connect(_mostrar_detalles)

func _mostrar_detalles(data):
	lbl_nombre.text = data.nombre_item
	lbl_descripcion.text = data.descripcion
	item_seleccionado_actual = data
	
	# Solo mostramos el botón "Usar" si estamos en la pestaña de Consumibles (1)
	if pestana_actual == 1:
		btn_usar.show()
	else:
		btn_usar.hide()

func _on_btn_usar_pressed():
	if item_seleccionado_actual == null: return
	
	# Verificamos si es la batería usando la lista de nombres válidos
	if item_seleccionado_actual.nombre_item in ["Bateria", "Batería", "bateria", "Bateria de Linterna"]:
		
		var player = get_tree().get_first_node_in_group("jugador")
		
		if player and player.has_method("recargar_linterna"):
			# 1. Recargamos la linterna de Vance
			player.recargar_linterna(100.0) 
			
			# 2. Restamos/eliminamos la batería del inventario
			InventoryManager.consumir_item(item_seleccionado_actual.id_item) 
			
			# 3. Limpiamos los textos y ocultamos el botón
			item_seleccionado_actual = null
			lbl_nombre.text = ""
			lbl_descripcion.text = "¡Linterna recargada!"
			btn_usar.hide()
