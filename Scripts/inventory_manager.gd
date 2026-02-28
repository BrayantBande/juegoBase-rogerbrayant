extends Node

signal inventory_updated()

var inventario_cantidades = {}
var inventario_datos = {}

func agregar_item(item_data, cantidad: int = 1):
	var id = item_data.id_item
	if inventario_cantidades.has(id):
		inventario_cantidades[id] += cantidad
	else:
		inventario_cantidades[id] = cantidad
		inventario_datos[id] = item_data
	
	inventory_updated.emit() # Avisa a la UI que se redibuje

func consumir_item(id_item: String) -> bool:
	if inventario_cantidades.has(id_item) and inventario_cantidades[id_item] > 0:
		inventario_cantidades[id_item] -= 1
		# Si la cantidad llega a 0 o menos, borramos el objeto de los diccionarios
		if inventario_cantidades[id_item] <= 0:
			inventario_cantidades.erase(id_item)
			inventario_datos.erase(id_item)
		
		inventory_updated.emit() # Avisa a la UI que actualice la cuadrícula
		return true
	return false

# Función para filtrar por pestañas (Dark Souls style)
func obtener_items_por_categoria(categoria_buscada: int) -> Array:
	var items_filtrados = []
	for id in inventario_datos.keys():
		var data = inventario_datos[id]
		if data.tipo == categoria_buscada:
			items_filtrados.append({
				"id": id,
				"data": data,
				"cantidad": inventario_cantidades[id]
			})
	return items_filtrados
