extends StaticBody3D

@export var item_recurso: ItemData # Aquí arrastrarás tu item_bateria.tres

func recoger():
	if item_recurso:
		# Añade el item al inventario global
		InventoryManager.agregar_item(item_recurso, 1)
		# Hace que el objeto desaparezca del mundo
		queue_free()
