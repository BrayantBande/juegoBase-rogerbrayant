extends Button

@onready var icono_rect = $Icono
@onready var label_cantidad = $Cantidad

var item_id: String = ""
var item_data: ItemData = null

signal slot_clicked(data)

func _ready():
	pressed.connect(_on_pressed)

func configurar_slot(data: ItemData, cantidad: int):
	item_data = data
	item_id = data.id_item
	
	if data.icono != null:
		icono_rect.texture = data.icono
		
	if cantidad > 1:
		label_cantidad.text = "x" + str(cantidad)
		label_cantidad.show()
	else:
		label_cantidad.hide()

func _on_pressed():
	slot_clicked.emit(item_data)
