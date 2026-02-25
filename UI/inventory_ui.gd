extends ColorRect

@onready var cuadricula = $ContenedorPrincipal/LadoIzquierdo/CuadriculaItems
@onready var lbl_nombre = $ContenedorPrincipal/PanelDetalles/NombreItem
@onready var lbl_descripcion = $ContenedorPrincipal/PanelDetalles/DescripcionItem

@onready var btn_claves = $ContenedorPrincipal/LadoIzquierdo/Pestañas/BtnClaves
@onready var btn_consumibles = $ContenedorPrincipal/LadoIzquierdo/Pestañas/BtnConsumibles
@onready var btn_notas = $ContenedorPrincipal/LadoIzquierdo/Pestañas/BtnNotas

# Referencia a la casilla visual que acabamos de crear
var slot_scene = preload("res://UI/InventorySlot.tscn") # <-- ASEGÚRATE DE QUE ESTA RUTA SEA CORRECTA

var pestana_actual: int = 1 # Empezamos viendo los Consumibles (1)

func _ready():
	# Conectamos las pestañas (0=Clave, 1=Consumible, 2=Nota)
	btn_claves.pressed.connect(_cambiar_pestana.bind(0))
	btn_consumibles.pressed.connect(_cambiar_pestana.bind(1))
	btn_notas.pressed.connect(_cambiar_pestana.bind(2))
	
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

func _mostrar_detalles(data: ItemData):
	lbl_nombre.text = data.nombre_item
	lbl_descripcion.text = data.descripcion
